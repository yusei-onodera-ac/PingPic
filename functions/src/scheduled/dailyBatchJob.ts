import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import type { ScheduleSlot, SlotNumber } from "@pingpic/shared-types";
import { readTodaySchedule, writeTodaySchedule } from "../services/scheduleService";
import { pickRandomPopularPrompt, incrementUsageCount } from "../services/promptPoolService";
import { scheduleGroupPush } from "../services/notificationService";
import { pickValidSendTime } from "../utils/timeSlot";

/**
 * Runs once a day at 00:00 Asia/Tokyo. This is the ONLY scheduled function
 * in the system by design — see docs/ARCHITECTURE.md "Cost design".
 *
 * Spec (design doc §4), implemented as 3 steps below:
 *   1. Schedule check — read today's daily_schedules/{date} doc.
 *   2. Auto-fill — for any of the 3 slots left unset by an admin, pick a
 *      valid send time (07:00–22:00, ≥4h apart from the other slots) and
 *      assign a prompt from prompt_pool, credited "admin".
 *   3. Notification reservation — schedule the day's 3 push sends.
 *
 * This scaffold wires the shape of all 3 steps and calls into typed stub
 * services so the seams are testable before real logic lands — see the
 * TODOs in services/scheduleService.ts, services/promptPoolService.ts,
 * services/notificationService.ts, and utils/timeSlot.ts.
 */
export const dailyBatchJob = onSchedule(
  {
    schedule: "0 0 * * *",
    timeZone: "Asia/Tokyo",
    // Lowest viable tier for a once-a-day job — cost guardrail, see
    // docs/ARCHITECTURE.md. Raise only if profiling shows it's needed.
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const today = new Date();
    logger.info("dailyBatchJob: starting", { scheduledTime: event.scheduleTime });

    // --- Step 1: schedule check ---
    const existing = await readTodaySchedule(today);
    logger.info("dailyBatchJob: read today's schedule", {
      hadExistingDoc: existing !== null,
    });

    // --- Step 2: auto-fill unset slots ---
    // TODO: this loop is a scaffold shape only — `existing` may be null
    // (no doc at all) or have fewer/partial slots depending on what the
    // admin actually saved; real logic must handle both, and must call
    // pickValidSendTime with the OTHER already-resolved slots' times so the
    // ≥4h-apart constraint holds across the whole day, not just per-slot.
    const resolvedSlots: ScheduleSlot[] = [];
    for (const slotNumber of [1, 2, 3] as SlotNumber[]) {
      const existingSlot = existing?.slots?.[slotNumber - 1];
      if (existingSlot) {
        resolvedSlots.push(existingSlot);
        continue;
      }

      logger.info(`dailyBatchJob: slot ${slotNumber} unset, auto-filling`, {});
      // TODO: wire pickValidSendTime(today, resolvedSlots.map(s => ...))
      // and pickRandomPopularPrompt() together into a real ScheduleSlot,
      // then incrementUsageCount() on whatever pool entry was used.
      void pickValidSendTime;
      void pickRandomPopularPrompt;
      void incrementUsageCount;
    }

    // --- Step 3: schedule the day's 3 push sends ---
    // TODO: once resolvedSlots is fully populated above, schedule each via
    // scheduleGroupPush (or a Cloud Tasks equivalent that fires exactly at
    // each slot's send_time — see notificationService.ts note).
    void scheduleGroupPush;
    void writeTodaySchedule;

    logger.info("dailyBatchJob: scaffold run complete (no writes performed yet)");
  }
);
