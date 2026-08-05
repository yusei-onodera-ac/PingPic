/**
 * Pure scheduling-window rules — no Firestore/SDK/timezone-library
 * dependency, so this is safe to import from both functions/ (Node,
 * computes in JST) and admin-panel/ (browser, for client-side validation
 * feedback before save — the batch job remains the real enforcement
 * point server-side).
 */

export const WINDOW_START_HOUR = 7; // 07:00
export const WINDOW_END_HOUR = 22; // 22:00
export const MIN_GAP_HOURS = 4;

export interface HourMinute {
  hour: number;
  minute: number;
}

/**
 * Validates a day's (up to 3) candidate send times against the window and
 * inter-slot gap rules. Returns a list of human-readable problem strings
 * (Japanese, since this is only ever surfaced in the admin panel) —
 * empty means valid. Entries may be `null` for not-yet-configured slots,
 * which are simply skipped.
 */
export function validateSendTimes(times: (HourMinute | null)[]): string[] {
  const problems: string[] = [];

  times.forEach((t, i) => {
    if (!t) return;
    if (t.hour < WINDOW_START_HOUR || t.hour >= WINDOW_END_HOUR) {
      problems.push(
        `スロット${i + 1}: ${String(WINDOW_START_HOUR).padStart(2, "0")}:00〜${String(
          WINDOW_END_HOUR
        ).padStart(2, "0")}:00 の間で設定してください`
      );
    }
  });

  const indexed = times
    .map((t, i) => (t ? { i, minutesOfDay: t.hour * 60 + t.minute } : null))
    .filter((x): x is { i: number; minutesOfDay: number } => x !== null);

  for (let a = 0; a < indexed.length; a++) {
    for (let b = a + 1; b < indexed.length; b++) {
      const gapHours = Math.abs(indexed[a].minutesOfDay - indexed[b].minutesOfDay) / 60;
      if (gapHours < MIN_GAP_HOURS) {
        problems.push(
          `スロット${indexed[a].i + 1}とスロット${indexed[b].i + 1}の間隔が${MIN_GAP_HOURS}時間未満です`
        );
      }
    }
  }

  return problems;
}
