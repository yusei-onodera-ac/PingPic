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
 * TODO: implement.
 * Persists the (possibly auto-filled) schedule back to Firestore, in a
 * single write. Should be called once per day by dailyBatchJob after
 * resolving all 3 slots.
 */
export async function writeTodaySchedule(
  date: Date,
  schedule: DailySchedule
): Promise<void> {
  throw new Error(
    `writeTodaySchedule: not implemented — scaffold stub. date=${todayDocId(
      date
    )} schedule=${JSON.stringify(schedule)}`
  );
}
