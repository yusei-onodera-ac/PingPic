import type { FirestoreTimestamp } from "@pingpic/shared-types";

/** Notification window per docs/DATA_MODEL.md / design spec. */
export const WINDOW_START_HOUR = 7; // 07:00
export const WINDOW_END_HOUR = 22; // 22:00
export const MIN_GAP_HOURS = 4;

/**
 * TODO: implement.
 *
 * Given the already-fixed send times for a day's other slots (0-2 of them),
 * pick a valid Date for a still-unset slot such that:
 *   - it falls within [WINDOW_START_HOUR, WINDOW_END_HOUR)
 *   - it is at least MIN_GAP_HOURS away from every other slot's send time
 *     (already-fixed or previously-picked-in-this-call)
 *
 * Called by dailyBatchJob for each unset slot, in slot order (1, 2, 3), so
 * by the time slot 3 is picked, slots 1 and 2 (whether admin-set or just
 * auto-filled) are already fixed.
 *
 * @param date - the calendar date (JST) being scheduled
 * @param existingSendTimes - send times already fixed for other slots today
 */
export function pickValidSendTime(
  date: Date,
  existingSendTimes: Date[]
): Date {
  throw new Error(
    "pickValidSendTime: not implemented — scaffold stub. " +
      `date=${date.toISOString()} existingSendTimes=${existingSendTimes.length}`
  );
}

/** Convert a JS Date to a plain Firestore-Timestamp-shaped object without
 * depending on either the client or Admin SDK's Timestamp class — the
 * caller (dailyBatchJob, using the Admin SDK) is expected to wrap this with
 * `admin.firestore.Timestamp.fromDate(date)` directly instead in practice;
 * this helper exists mainly so shared-types' FirestoreTimestamp shape has a
 * documented construction path for tests. */
export function toFirestoreTimestampShape(date: Date): FirestoreTimestamp {
  const ms = date.getTime();
  return {
    seconds: Math.floor(ms / 1000),
    nanoseconds: (ms % 1000) * 1e6,
  };
}
