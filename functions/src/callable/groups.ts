import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAdminApp } from "../config/firebaseAdmin";
import { FUNCTIONS_REGION } from "../config/params";

/**
 * Group create/join — a design decision not in the original spec (see the
 * doc comment on Group in packages/shared-types/src/index.ts). Both
 * mutations go through these callables rather than direct client writes
 * to `groups`, so invite-code uniqueness can be enforced with a
 * server-side transaction and firestore.rules can stay a flat
 * "members can read, nobody writes directly" rule.
 *
 * MVP simplification: one group per user. There's no explicit "leave
 * group" or multi-group support here — a user just is or isn't in
 * `memberIds` of whichever single group they joined.
 */

// Excludes visually-ambiguous characters (0/O, 1/I/L) since this is
// meant to be read aloud / typed by hand between friends.
const INVITE_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const INVITE_CODE_LENGTH = 6;

function randomInviteCode(): string {
  let code = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += INVITE_CODE_ALPHABET[Math.floor(Math.random() * INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

export const createGroup = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "サインインが必要です");
  }

  const name = (request.data?.name as string | undefined)?.trim();
  if (!name) {
    throw new HttpsError("invalid-argument", "グループ名を入力してください");
  }
  if (name.length > 50) {
    throw new HttpsError("invalid-argument", "グループ名は50文字以内にしてください");
  }

  const db = getFirestore(getAdminApp());

  // Retry on invite-code collision. At 6 chars from a 32-symbol alphabet
  // (32^6 ≈ 1.07B combinations) this is astronomically unlikely, but the
  // transaction below makes the check free to include anyway.
  const MAX_ATTEMPTS = 5;
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const inviteCode = randomInviteCode();
    const inviteRef = db.collection("invite_codes").doc(inviteCode);
    const groupRef = db.collection("groups").doc();

    try {
      await db.runTransaction(async (tx) => {
        const inviteSnap = await tx.get(inviteRef);
        if (inviteSnap.exists) {
          // Signals "retry with a new code" to the catch block below —
          // not a real client-facing error since we never let it escape
          // past the last attempt.
          throw new HttpsError("already-exists", "invite code collision, retrying");
        }
        tx.set(inviteRef, { groupId: groupRef.id });
        tx.set(groupRef, {
          name,
          memberIds: [uid],
          inviteCode,
          createdBy: uid,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return { groupId: groupRef.id, inviteCode };
    } catch (err) {
      if (attempt === MAX_ATTEMPTS - 1) throw err;
      // else: loop again with a freshly generated code
    }
  }

  // Unreachable (the loop above always either returns or throws), but
  // keeps the function's return type honest without a `!`.
  throw new HttpsError("internal", "招待コードの割り当てに失敗しました");
});

export const joinGroupByInviteCode = onCall({ region: FUNCTIONS_REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "サインインが必要です");
  }

  const inviteCode = (request.data?.inviteCode as string | undefined)?.trim().toUpperCase();
  if (!inviteCode) {
    throw new HttpsError("invalid-argument", "招待コードを入力してください");
  }

  const db = getFirestore(getAdminApp());
  const inviteSnap = await db.collection("invite_codes").doc(inviteCode).get();
  if (!inviteSnap.exists) {
    throw new HttpsError("not-found", "招待コードが見つかりません");
  }

  const groupId = inviteSnap.data()!.groupId as string;
  const groupRef = db.collection("groups").doc(groupId);
  await groupRef.update({ memberIds: FieldValue.arrayUnion(uid) });

  const groupSnap = await groupRef.get();
  return { groupId, name: groupSnap.data()?.name as string | undefined };
});
