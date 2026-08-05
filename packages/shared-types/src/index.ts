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

/** Always exactly 3 slots (T1, T2, T3), index 0/1/2. */
export interface DailySchedule {
  slots: [ScheduleSlot, ScheduleSlot, ScheduleSlot];
}

// -----------------------------------------------------------------------
// groups/{groupId}  — ⚠️ inferred, not defined in the original design doc.
// TODO: unconfirmed — no group creation/invite/join flow specified yet.
// -----------------------------------------------------------------------

export interface Group {
  name: string;
  memberIds: string[];
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
