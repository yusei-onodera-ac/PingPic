import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAdminApp } from "../config/firebaseAdmin";
import { FUNCTIONS_REGION } from "../config/params";

/**
 * Accepting (or rejecting) a friend_requests doc — see the design note
 * on FriendRequest/Connection in packages/shared-types/src/index.ts.
 * Sending a request and unfriending are plain client writes (simple
 * enough for firestore.rules alone); accepting is NOT, since it has to
 * atomically both create the `connections` doc AND delete the request,
 * which a rules-only client write can't coordinate — that's what this
 * callable is for.
 */
export const respondToFriendRequest = onCall(
  { region: FUNCTIONS_REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "サインインが必要です");
    }

    const requestId = request.data?.requestId as string | undefined;
    const accept = request.data?.accept as boolean | undefined;
    // The accepter's own display name — passed explicitly rather than
    // read from request.auth.token.name, which is only populated when
    // the underlying Firebase Auth user has a displayName set (this app
    // never prompts for one; see the userDisplayName ?? email ?? '匿名
    // ユーザー' fallback used everywhere else, e.g. CameraRepositoryImpl).
    const myDisplayName = (request.data?.myDisplayName as string | undefined)?.trim();

    if (!requestId || typeof accept !== "boolean") {
      throw new HttpsError("invalid-argument", "requestId (string) and accept (boolean) are required");
    }

    const db = getFirestore(getAdminApp());
    const requestRef = db.collection("friend_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(requestRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "リクエストが見つかりません");
      }
      const data = snap.data()!;
      if (data.toUid !== uid) {
        throw new HttpsError("permission-denied", "このリクエストへの応答権限がありません");
      }
      if (data.status !== "pending") {
        throw new HttpsError("failed-precondition", "既に処理済みのリクエストです");
      }

      if (accept) {
        const fromUid = data.fromUid as string;
        const fromDisplayName = data.fromDisplayName as string;
        const [a, b] = [fromUid, uid].sort();
        const connectionRef = db.collection("connections").doc(`${a}_${b}`);
        tx.set(connectionRef, {
          uids: [a, b],
          displayNames: {
            [fromUid]: fromDisplayName,
            [uid]: myDisplayName || "匿名ユーザー",
          },
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      // Reject or accept, the request is resolved either way — no
      // lingering "rejected" status to track, consistent with how
      // prompt_suggestions is the only place in this app that keeps a
      // terminal status around (and that's for admin visibility, which
      // doesn't apply here).
      tx.delete(requestRef);
    });

    return { ok: true, accepted: accept };
  }
);
