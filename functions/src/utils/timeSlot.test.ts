import { describe, it, expect } from "vitest";
import { pickValidSendTime, timestampToDate, WINDOW_START_HOUR, WINDOW_END_HOUR, MIN_GAP_HOURS } from "./timeSlot";

const SAMPLE_DATE = new Date("2026-08-05T00:00:00+09:00");

function jstHour(date: Date, hour: number, minute = 0): Date {
  const dateStr = date.toLocaleDateString("sv-SE", { timeZone: "Asia/Tokyo" });
  return new Date(`${dateStr}T${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:00+09:00`);
}

describe("pickValidSendTime", () => {
  it("with no existing times, always falls within the 07:00-22:00 JST window", () => {
    for (let i = 0; i < 200; i++) {
      const t = pickValidSendTime(SAMPLE_DATE, []);
      expect(t.getTime()).toBeGreaterThanOrEqual(jstHour(SAMPLE_DATE, WINDOW_START_HOUR).getTime());
      expect(t.getTime()).toBeLessThanOrEqual(jstHour(SAMPLE_DATE, WINDOW_END_HOUR).getTime());
    }
  });

  it("respects the >=4h gap from a single existing time", () => {
    const existing = jstHour(SAMPLE_DATE, 10); // 10:00
    for (let i = 0; i < 200; i++) {
      const t = pickValidSendTime(SAMPLE_DATE, [existing]);
      const gapHours = Math.abs(t.getTime() - existing.getTime()) / (60 * 60 * 1000);
      expect(gapHours).toBeGreaterThanOrEqual(MIN_GAP_HOURS - 1e-9);
    }
  });

  it("respects the >=4h gap from two existing times", () => {
    const t1 = jstHour(SAMPLE_DATE, 8);
    const t2 = jstHour(SAMPLE_DATE, 18);
    for (let i = 0; i < 200; i++) {
      const t3 = pickValidSendTime(SAMPLE_DATE, [t1, t2]);
      expect(Math.abs(t3.getTime() - t1.getTime()) / (60 * 60 * 1000)).toBeGreaterThanOrEqual(MIN_GAP_HOURS - 1e-9);
      expect(Math.abs(t3.getTime() - t2.getTime()) / (60 * 60 * 1000)).toBeGreaterThanOrEqual(MIN_GAP_HOURS - 1e-9);
    }
  });

  it("throws when no valid window remains", () => {
    // 07:00-22:00 is 15h; three times 4h apart (e.g. 07,11,15,19) can
    // still leave gaps, but tightly packing many existing times exhausts
    // the window entirely.
    const existing = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21].map((h) =>
      jstHour(SAMPLE_DATE, h)
    );
    expect(() => pickValidSendTime(SAMPLE_DATE, existing)).toThrow();
  });
});

describe("timestampToDate", () => {
  it("round-trips seconds/nanoseconds back to the same instant", () => {
    const original = new Date("2026-08-05T10:30:00.500+09:00");
    const asTimestampShape = {
      seconds: Math.floor(original.getTime() / 1000),
      nanoseconds: (original.getTime() % 1000) * 1e6,
    };
    const roundTripped = timestampToDate(asTimestampShape);
    expect(Math.abs(roundTripped.getTime() - original.getTime())).toBeLessThan(1);
  });
});
