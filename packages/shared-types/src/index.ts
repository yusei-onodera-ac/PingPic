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
// groups/{groupId}  — ⚠️ inferred, not defined in the original design doc.
//
// Design decision (not in the original spec): invite-code based
// create/join, one group per user for this MVP (a user with no group yet
// just doesn't have a doc where they're a member). Both mutations go
// through Cloud Functions callables (functions/src/callable/groups.ts) —
// NOT direct client writes — so invite-code uniqueness can be enforced
// with a server-side transaction and firestore.rules can stay a flat
// "members can read, nobody can write directly" rule. See
// docs/DATA_MODEL.md for the full rationale.
// -----------------------------------------------------------------------

export interface Group {
  name: string;
  memberIds: string[];
  inviteCode: string;
  createdBy: string; // uid
  createdAt: FirestoreTimestamp;
}

/** invite_codes/{code} — lookup-only doc mapping a code to its group,
 * used by joinGroupByInviteCode. Never read/written directly by clients. */
export interface InviteCode {
  groupId: string;
}

// -----------------------------------------------------------------------
// posts/{postId}
// -----------------------------------------------------------------------

export type SlotNumber = 1 | 2 | 3;

export interface Post {
  groupId: string;
  userId: string;
  /** "YYYY-MM-DD" */
  date: string;
  slotNumber: SlotNumber;
  photoUrl: string;
  postedAt: FirestoreTimestamp;
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
