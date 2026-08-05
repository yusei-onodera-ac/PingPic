import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAdminApp } from "../config/firebaseAdmin";
import { FUNCTIONS_REGION } from "../config/params";

/**
 * Maintains Post.likeCount server-side, reacting to
 * posts/{postId}/likes/{uid} create/delete rather than trusting a
 * client-writable counter. This is what lets firestore.rules keep
 * `posts`' own `allow update` admin-only even though "like" is now a
 * regular signed-in-user action on a doc that might be visible to anyone
 * (public posts) — the client only ever creates/deletes its OWN like
 * doc; it never touches likeCount directly.
 *
 * Two separate triggers (not one trigger watching both event types)
 * because onDocumentWritten's before/after diffing is more code for the
 * same two cases this already covers directly.
 */

export const onLikeCreated = onDocumentCreated(
  { document: "posts/{postId}/likes/{uid}", region: FUNCTIONS_REGION },
  async (event) => {
    const postId = event.params.postId;
    const db = getFirestore(getAdminApp());
    await db.collection("posts").doc(postId).update({
      likeCount: FieldValue.increment(1),
    });
  }
);

export const onLikeDeleted = onDocumentDeleted(
  { document: "posts/{postId}/likes/{uid}", region: FUNCTIONS_REGION },
  async (event) => {
    const postId = event.params.postId;
    const db = getFirestore(getAdminApp());
    const postRef = db.collection("posts").doc(postId);
    // Guard against the post itself having been deleted (admin-only,
    // rare) — Firestore doesn't cascade-delete subcollections, so an
    // unlike after that would otherwise fail with "not found" and log a
    // spurious trigger error.
    const postSnap = await postRef.get();
    if (!postSnap.exists) return;
    await postRef.update({ likeCount: FieldValue.increment(-1) });
  }
);
