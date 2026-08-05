/**
 * PingPic shared Firestore document types.
 *
 * Canonical schema description (with rationale) lives in docs/DATA_MODEL.md —
 * keep this file and that doc in sync.
 *
 * Consumed by: functions/, admin-panel/.
 * NOT consumed by mobile/ — Dart cannot import TS. The Flutter models under
 * mobile/lib/**\/data/*_model.dart are hand-mirrored copies of these shapes.
 * See docs/ARCHITECTURE.md "Known duplication" for the tradeoff.
 */

// Deliberately NOT importing `Timestamp` from `firebase/firestore` or
// `firebase-admin/firestore` here — `functions` uses the Admin SDK and
// `admin-panel` uses the client SDK, and those are two different classes.
// This minimal structural type is satisfied by both, so this package stays
// dependency-free and safe to import from either side.
export interface FirestoreTimestamp {
  seconds: number;
  nanoseconds: number;
}

/** Reads a structural FirestoreTimestamp (real Admin/Client SDK Timestamp
 * instances satisfy this shape too, since both expose these two fields)
 * back into a JS Date, without needing either SDK's Timestamp class. */
export function timestampToDate(ts: FirestoreTimestamp): Date {
  return new Date(ts.seconds * 1000 + ts.nanoseconds / 1e6);
}

// -----------------------------------------------------------------------
// daily_schedules/{date}   (doc id: "YYYY-MM-DD")
// -----------------------------------------------------------------------

export type PromptCredit =
  | { type: "admin" }
  | { type: "user"; uid: string; displayName: string };

export interface ScheduleSlot {
  sendTime: FirestoreTimestamp;
  promptText: string;
  credit: PromptCredit;
}

/**
 * Always length 3 (index 0/1/2 = slot 1/2/3). A `null` entry means that
 * slot hasn't been configured by an admin yet — this is the normal state
 * for part of a day before the 00:00 batch job
 * (functions/src/scheduled/dailyBatchJob.ts) auto-fills whatever is still
 * null at midnight. A missing document (date not yet touched at all)
 * should be treated identically to `{ slots: [null, null, null] }`.
 */
export interface DailySchedule {
  slots: [ScheduleSlot | null, ScheduleSlot | null, ScheduleSlot | null];
}

export * from "./scheduleRules";

// -----------------------------------------------------------------------
// friend_requests/{fromUid}_{toUid}   and   connections/{sortedUidA}_{sortedUidB}
//
// Design decision (not in the original spec): PingPic went through two
// earlier relationship models in this session — group membership, then a
// one-directional "follow" graph — before landing here: a mutual
// connection, gated by an approval step (request -> accept), after which
// BOTH parties can see all of each other's posts. Closer to a "friend
// request" than a Twitter-style follow.
//
// `friend_requests` docs are plain client writes/deletes (rules-enforced
// — see firestore.rules) since the constraint per doc is simple. Turning
// an accepted request into a `connections` doc is NOT a plain client
// write, though — it's the one place server-side arbitration earns its
// keep this time: `respondToFriendRequest` (functions/src/callable/
// connections.ts) validates the request and atomically creates the
// connection + deletes the request, via the Admin SDK. `connections`'
// create rule is `if false` — the callable is the only way one is ever
// created. Deleting one ("unfriend") IS a plain client write by either
// party, no approval needed for that direction.
//
// `connections` uses a SINGLE doc per pair (id = the two uids sorted
// ascending, joined with "_") rather than two mirrored per-user
// subcollections, since the relationship is symmetric — one doc,
// one exists() check from either side, no risk of the two mirrors
// drifting out of sync.
// -----------------------------------------------------------------------

export type FriendRequestStatus = "pending";

export interface FriendRequest {
  fromUid: string;
  toUid: string;
  /** Denormalized so the recipient's incoming-requests list can show a
   * name without an extra lookup — same convention as
   * Post.authorDisplayName. */
  fromDisplayName: string;
  status: FriendRequestStatus;
  createdAt: FirestoreTimestamp;
}

export interface Connection {
  /** Exactly 2 uids, sorted ascending — matches the doc id. */
  uids: [string, string];
  /** Keyed by uid, so either party can look up the OTHER's name without
   * a user-profile collection. */
  displayNames: Record<string, string>;
  createdAt: FirestoreTimestamp;
}

/** Deterministic connections/{...} doc id for a pair of uids, order-
 * independent. Mirrored in mobile's ConnectionRepository (Dart) and
 * firestore.rules' connectionId() — keep all three in sync. */
export function connectionId(uidA: string, uidB: string): string {
  return uidA < uidB ? `${uidA}_${uidB}` : `${uidB}_${uidA}`;
}

// -----------------------------------------------------------------------
// posts/{postId}
// -----------------------------------------------------------------------

export type SlotNumber = 1 | 2 | 3;

export interface Post {
  userId: string;
  /** Denormalized from Firebase Auth's user.displayName at post time —
   * there's no separate user-profile collection in this app, and the
   * public feed / following feed both need a name to show without a
   * per-card user lookup. Matches the same "userId ?? email ?? '匿名
   * ユーザー'" fallback used for prompt suggestions' submitterInfo. */
  authorDisplayName: string;
  /** "YYYY-MM-DD" */
  date: string;
  slotNumber: SlotNumber;
  photoUrl: string;
  postedAt: FirestoreTimestamp;
  /** Denormalized copy of the slot's ScheduleSlot.promptText at post
   * time — so the "みんなの投稿" public feed and post detail screen can
   * show what prompt a photo was answering without an extra
   * daily_schedules read per post. Never updated after creation (there's
   * no prompt-editing flow that would need to keep it in sync). */
  promptText: string;
  /**
   * Chosen at capture time (not toggleable afterward — see mobile's
   * CapturedPreviewView). Controls visibility to the WIDER app, not to
   * followers — followers can always see all of a user's posts
   * regardless of this flag (see firestore.rules' posts read rule and
   * docs/ARCHITECTURE.md's "Resolved: groups → followers" section for
   * the full privacy model). `isPublic: true` additionally surfaces the
   * post in the "みんなの投稿" feed, visible to any signed-in user.
   */
  isPublic: boolean;
  /** Optional one-line comment posted alongside a photo. Present
   * (possibly empty-string) even on private posts for schema simplicity,
   * but only ever shown in the UI for public ones. */
  caption: string;
  /** Denormalized count, maintained server-side by
   * functions/src/triggers/likes.ts reacting to the posts/{postId}/likes
   * subcollection — never written directly by clients (see
   * firestore.rules: posts.allow update is admin-only). */
  likeCount: number;
}

/** posts/{postId}/likes/{uid} — doc id IS the liker's uid, so "like" is
 * just create-this-doc and "unlike" is delete-this-doc; existence alone
 * is the signal, no fields needed. Drives likeCount via a Cloud
 * Functions trigger rather than a client-side counter update, so the
 * `posts` collection's write rule can stay admin-only even though
 * "everyone" can now see public posts. */
export interface Like {
  createdAt: FirestoreTimestamp;
}

/** posts/{postId}/comments/{commentId} */
export interface Comment {
  userId: string;
  displayName: string;
  text: string;
  createdAt: FirestoreTimestamp;
}

// -----------------------------------------------------------------------
// prompt_suggestions/{suggestionId}
// -----------------------------------------------------------------------

export type SuggestionStatus = "pending" | "approved" | "rejected";

export interface PromptSuggestion {
  suggestionText: string;
  submitterInfo: {
    uid: string;
    displayName: string;
  };
  status: SuggestionStatus;
  createdAt: FirestoreTimestamp;
}

// -----------------------------------------------------------------------
// prompt_pool/{entryId}  — "popular prompt" stock for 00:00 auto-fill
// -----------------------------------------------------------------------

export interface PromptPoolEntry {
  promptText: string;
  usageCount: number;
  createdAt: FirestoreTimestamp;
}
