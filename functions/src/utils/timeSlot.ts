import { WINDOW_START_HOUR, WINDOW_END_HOUR, MIN_GAP_HOURS, timestampToDate } from "@pingpic/shared-types";

// Re-exported so existing imports of these from this module keep working —
// canonical definitions live in packages/shared-types (shared with
// admin-panel's client-side validation / timestamp reading too).
export { WINDOW_START_HOUR, WINDOW_END_HOUR, MIN_GAP_HOURS, timestampToDate };

/**
 * Returns the Date for `hour`:00:00 JST on the same calendar date as
 * `date` (also interpreted in JST). JST has no DST, so a fixed +09:00
 * offset is safe to hardcode.
 */
function jstHourBoundary(date: Date, hour: number): Date {
  const dateStrJst = date.toLocaleDateString("sv-SE", { timeZone: "Asia/Tokyo" }); // "YYYY-MM-DD"
  return new Date(`${dateStrJst}T${String(hour).padStart(2, "0")}:00:00+09:00`);
}

/**
 * Picks a valid Date for a still-unset slot such that it falls within
 * [WINDOW_START_HOUR, WINDOW_END_HOUR) JST and is at least MIN_GAP_HOURS
 * away from every time in `existingSendTimes`.
 *
 * Implementation: compute the "forbidden" ±MIN_GAP_HOURS interval around
 * each existing time (clipped to the window), merge overlaps, and pick a
 * uniformly random point in whatever window time remains — rather than
 * rejection-sampling random times and checking validity, which could spin
 * indefinitely as the window fills up. With the spec's max of 3 slots/day
 * in a 15h window requiring 4h gaps, a valid remainder always exists
 * (3 slots need only 8h of spread at minimum), but this still throws
 * loudly if that assumption is ever violated by a caller.
 *
 * Called by dailyBatchJob for each unset slot in slot order (1, 2, 3), so
 * by the time slot 3 is picked, slots 1 and 2 are already fixed.
 */
export function pickValidSendTime(date: Date, existingSendTimes: Date[]): Date {
  const windowStart = jstHourBoundary(date, WINDOW_START_HOUR).getTime();
  const windowEnd = jstHourBoundary(date, WINDOW_END_HOUR).getTime();
  const gapMs = MIN_GAP_HOURS * 60 * 60 * 1000;

  const forbidden = existingSendTimes
    .map((t): [number, number] => [t.getTime() - gapMs, t.getTime() + gapMs])
    .map(([s, e]): [number, number] => [Math.max(s, windowStart), Math.min(e, windowEnd)])
    .filter(([s, e]) => s < e)
    .sort((a, b) => a[0] - b[0]);

  const merged: [number, number][] = [];
  for (const [s, e] of forbidden) {
    const last = merged[merged.length - 1];
    if (last && s <= last[1]) {
      last[1] = Math.max(last[1], e);
    } else {
      merged.push([s, e]);
    }
  }

  const allowed: [number, number][] = [];
  let cursor = windowStart;
  for (const [s, e] of merged) {
    if (cursor < s) allowed.push([cursor, s]);
    cursor = Math.max(cursor, e);
  }
  if (cursor < windowEnd) allowed.push([cursor, windowEnd]);

  const totalMs = allowed.reduce((sum, [s, e]) => sum + (e - s), 0);
  if (totalMs <= 0) {
    throw new Error(
      "pickValidSendTime: no valid time remains in the 07:00-22:00 window " +
        `given ${existingSendTimes.length} existing send time(s) with a ${MIN_GAP_HOURS}h gap requirement.`
    );
  }

  let r = Math.random() * totalMs;
  for (const [s, e] of allowed) {
    const len = e - s;
    if (r < len) return new Date(s + r);
    r -= len;
  }
  // Unreachable in practice (floating point edge case at most) — fall back
  // to the start of the last allowed interval rather than crash.
  return new Date(allowed[allowed.length - 1][0]);
}
