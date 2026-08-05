import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { Timestamp } from "firebase-admin/firestore";
import type { ScheduleSlot, SlotNumber, DailySchedule } from "@pingpic/shared-types";
import { readTodaySchedule, writeTodaySchedule, todayDocId } from "../services/scheduleService";
import { pickRandomPopularPrompt, incrementUsageCount } from "../services/promptPoolService";
import { schedulePromptNotification } from "../services/notificationService";
import { pickValidSendTime, timestampToDate } from "../utils/timeSlot";
import { FUNCTIONS_REGION } from "../config/params";

const SLOT_NUMBERS: SlotNumber[] = [1, 2, 3];

/**
 * Runs once a day at 00:00 Asia/Tokyo. This is the ONLY scheduled function
 * in the system by design — see docs/ARCHITECTURE.md "Cost design".
 *
 * Spec (design doc §4):
 *   1. Schedule check — read today's daily_schedules/{date} doc.
 *   2. Auto-fill — for any of the 3 slots left unset by an admin, pick a
 *      valid send time (07:00–22:00, ≥4h apart from the other slots) and
 *      assign a prompt from prompt_pool, credited "admin".
 *   3. Notification reservation — schedule the day's 3 push sends via
 *      Cloud Tasks (see services/notificationService.ts).
 */
export const dailyBatchJob = onSchedule(
  {
    schedule: "0 0 * * *",
    timeZone: "Asia/Tokyo",
    region: FUNCTIONS_REGION,
    // Lowest viable tier for a once-a-day job — cost guardrail, see
    // docs/ARCHITECTURE.md. Raise only if profiling shows it's needed.
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
    if (!projectId) {
      throw new Error("dailyBatchJob: GCLOUD_PROJECT env var is not set (unexpected in Cloud Functions runtime)");
    }

    const today = new Date();
    const dateId = todayDocId(today);
    logger.info("dailyBatchJob: starting", { scheduledTime: event.scheduleTime, dateId });

    // --- Step 1: schedule check ---
    const existing = await readTodaySchedule(today);
    logger.info("dailyBatchJob: read today's schedule", { hadExistingDoc: existing !== null });

    // --- Step 2: auto-fill unset slots, slot by slot so each pick sees
    // the send times already resolved for earlier slots today. ---
    const resolvedSlots: ScheduleSlot[] = [];
    const resolvedSendTimes: Date[] = [];

    for (const slotNumber of SLOT_NUMBERS) {
      const existingSlot = existing?.slots?.[slotNumber - 1];
      if (existingSlot) {
        resolvedSlots.push(existingSlot);
        resolvedSendTimes.push(timestampToDate(existingSlot.sendTime));
        logger.info(`dailyBatchJob: slot ${slotNumber} already set by admin`, {});
        continue;
      }

      const sendTime = pickValidSendTime(today, resolvedSendTimes);
      const picked = await pickRandomPopularPrompt();
      if (!picked) {
        // Fail loudly rather than silently skip a slot — an empty
        // prompt_pool is a content-ops problem the admin needs to know
        // about immediately (see docs/SETUP.md monitoring note / Cloud
        // Functions error reporting).
        throw new Error(
          `dailyBatchJob: slot ${slotNumber} needs auto-fill but prompt_pool is empty — add entries via the admin panel.`
        );
      }

      const slot: ScheduleSlot = {
        // Timestamp.fromDate() satisfies the structural FirestoreTimestamp
        // type AND is stored as a real Firestore Timestamp (not a map) —
        // see packages/shared-types/src/index.ts's note on why this
        // package avoids importing the SDK's Timestamp class directly.
        sendTime: Timestamp.fromDate(sendTime),
        promptText: picked.entry.promptText,
        credit: { type: "admin" },
      };
      resolvedSlots.push(slot);
      resolvedSendTimes.push(sendTime);
      await incrementUsageCount(picked.id);

      logger.info(`dailyBatchJob: auto-filled slot ${slotNumber}`, {
        sendTime: sendTime.toISOString(),
        promptPoolEntryId: picked.id,
      });
    }

    // --- Persist the fully-resolved schedule in one write. ---
    const schedule: DailySchedule = {
      slots: resolvedSlots as [ScheduleSlot, ScheduleSlot, ScheduleSlot],
    };
    await writeTodaySchedule(today, schedule);

    // --- Step 3: schedule the day's 3 push sends. ---
    for (const slotNumber of SLOT_NUMBERS) {
      const slot = resolvedSlots[slotNumber - 1];
      const sendTime = resolvedSendTimes[slotNumber - 1];
      await schedulePromptNotification({
        projectId,
        date: dateId,
        slotNumber,
        promptText: slot.promptText,
        sendTime,
      });
    }

    logger.info("dailyBatchJob: complete", { dateId });
  }
);
