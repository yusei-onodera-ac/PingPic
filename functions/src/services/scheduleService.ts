import { getFirestore } from "firebase-admin/firestore";
import type { DailySchedule } from "@pingpic/shared-types";
import { getAdminApp } from "../config/firebaseAdmin";

/** "YYYY-MM-DD" in JST — used as the daily_schedules doc id. */
export function todayDocId(date: Date): string {
  return date.toLocaleDateString("sv-SE", { timeZone: "Asia/Tokyo" }); // sv-SE locale = ISO-ish YYYY-MM-DD
}

/**
 * Reads today's daily_schedules/{date} doc, if it exists.
 * Returns null if the admin hasn't set anything for today at all — callers
 * should treat that the same as "all 3 slots unset" for auto-fill purposes.
 */
export async function readTodaySchedule(
  date: Date
): Promise<DailySchedule | null> {
  const db = getFirestore(getAdminApp());
  const docId = todayDocId(date);
  const snap = await db.collection("daily_schedules").doc(docId).get();
  if (!snap.exists) return null;
  return snap.data() as DailySchedule;
}

/**
 * Persists the (possibly auto-filled) schedule back to Firestore in a
 * single write. `merge: true` so that if only some slots were unset, we
 * don't clobber anything else that might exist on the doc (there isn't
 * anything else today, but it's a safe default for a once-a-day writer).
 */
export async function writeTodaySchedule(
  date: Date,
  schedule: DailySchedule
): Promise<void> {
  const db = getFirestore(getAdminApp());
  const docId = todayDocId(date);
  await db.collection("daily_schedules").doc(docId).set(schedule, { merge: true });
}
