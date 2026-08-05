import type { ScheduleSlot, SlotNumber } from "@pingpic/shared-types";

/**
 * TODO: implement.
 *
 * Cost/design note: send per-GROUP FCM topic messages (`group_<id>`)
 * rather than looping over every member's device token individually — see
 * docs/ARCHITECTURE.md "Cost design". This keeps a day's 3 notification
 * sends at O(groups) function work, not O(users).
 *
 * At send time (T1/T2/T3), this should be invoked by a Cloud
 * Scheduler-triggered function (or Cloud Tasks scheduled by dailyBatchJob
 * for each slot's exact send_time) with the slot's prompt payload, and
 * publish to every active group's topic. The actual "at send_time, fire"
 * mechanism (Cloud Tasks vs. 3 fixed onSchedule crons vs. something else)
 * is an open implementation decision — not resolved in this scaffold.
 */
export async function scheduleGroupPush(
  slotNumber: SlotNumber,
  slot: ScheduleSlot
): Promise<void> {
  throw new Error(
    `scheduleGroupPush: not implemented — scaffold stub. slotNumber=${slotNumber} promptText=${slot.promptText}`
  );
}
