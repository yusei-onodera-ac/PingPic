/**
 * "YYYY-MM-DD" for a given Date, using the browser's local time.
 *
 * NOTE: unlike functions/src/services/scheduleService.ts's `todayDocId`
 * (which deliberately pins JST since the batch job's window/gap rules are
 * JST-based), this admin-panel helper uses the admin's local browser
 * timezone. That's fine for picking which calendar day to edit, but the
 * actual send-time values entered in SlotEditorModal are still
 * constructed with an explicit +09:00 offset — see that component — so
 * an admin browsing from outside Japan doesn't silently schedule prompts
 * at the wrong JST hour.
 */
export function toDateId(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** Breaks a Date into its JST hour/minute, regardless of the browser's
 * own timezone. */
export function jstHourMinute(date: Date): { hour: number; minute: number } {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  return {
    hour: Number(parts.find((p) => p.type === "hour")?.value ?? "0"),
    minute: Number(parts.find((p) => p.type === "minute")?.value ?? "0"),
  };
}

/** Formats a Date as "HH:MM" in JST, for pre-filling a slot's time input. */
export function toJstTimeInputValue(date: Date): string {
  const { hour, minute } = jstHourMinute(date);
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

/** Builds a Date from a "YYYY-MM-DD" date id + "HH:MM" time input value,
 * anchored to JST explicitly (+09:00) regardless of the admin's browser
 * timezone — see the module doc comment above. */
export function jstDateFromParts(dateId: string, hhmm: string): Date {
  return new Date(`${dateId}T${hhmm}:00+09:00`);
}
