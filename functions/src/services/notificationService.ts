import { CloudTasksClient } from "@google-cloud/tasks";
import type { SlotNumber } from "@pingpic/shared-types";
import { sendScheduledPromptUrl, FUNCTIONS_REGION, CLOUD_TASKS_QUEUE } from "../config/params";

let tasksClient: CloudTasksClient | null = null;
function getTasksClient(): CloudTasksClient {
  if (!tasksClient) tasksClient = new CloudTasksClient();
  return tasksClient;
}

/**
 * FCM topic every device subscribes to for daily prompt pushes (see
 * mobile/lib/features/notifications/data/push_notification_service.dart).
 *
 * Design note: the design doc's prompt content is identical for every
 * user — so a single global topic broadcast is both the simplest AND the
 * cheapest option: one FCM send per slot (O(1)) instead of looping per
 * device token. See docs/ARCHITECTURE.md "Cost design".
 */
export const DAILY_PROMPTS_TOPIC = "daily_prompts";

/**
 * Schedules a Cloud Task that will POST to the `sendScheduledPrompt` HTTPS
 * function at exactly `sendTime`, which performs the actual FCM publish.
 * Using Cloud Tasks (rather than e.g. 3 additional fixed cron schedules)
 * because send times are admin-configurable per day, not fixed — Cloud
 * Tasks lets each day's dailyBatchJob schedule that day's exact times.
 *
 * Requires a Cloud Tasks queue named CLOUD_TASKS_QUEUE to already exist in
 * FUNCTIONS_REGION (created once via `gcloud tasks queues create`, see
 * docs/SETUP.md) and the SEND_SCHEDULED_PROMPT_URL param to be set to the
 * deployed sendScheduledPrompt function's URL.
 */
export async function schedulePromptNotification(params: {
  projectId: string;
  date: string; // "YYYY-MM-DD"
  slotNumber: SlotNumber;
  promptText: string;
  sendTime: Date;
}): Promise<void> {
  const { projectId, date, slotNumber, promptText, sendTime } = params;
  const url = sendScheduledPromptUrl.value();
  if (!url) {
    throw new Error(
      "schedulePromptNotification: SEND_SCHEDULED_PROMPT_URL param is not set — see docs/SETUP.md."
    );
  }

  const client = getTasksClient();
  const queuePath = client.queuePath(projectId, FUNCTIONS_REGION, CLOUD_TASKS_QUEUE);
  const body = Buffer.from(JSON.stringify({ date, slotNumber, promptText })).toString("base64");

  try {
    await client.createTask({
      parent: queuePath,
      task: {
        name: `${queuePath}/tasks/${date}-slot${slotNumber}`, // fixed name: re-running dailyBatchJob for the same day is idempotent
        httpRequest: {
          httpMethod: "POST",
          url,
          headers: { "Content-Type": "application/json" },
          body,
          // Cloud Tasks attaches a Google-signed OIDC ID token when calling
          // sendScheduledPrompt, which (being a non-public gen2 function)
          // verifies it — this is the auth boundary, not a shared secret.
          oidcToken: {
            serviceAccountEmail: `${projectId}@appspot.gserviceaccount.com`,
          },
        },
        scheduleTime: {
          seconds: Math.floor(sendTime.getTime() / 1000),
        },
      },
    });
  } catch (err: unknown) {
    // gRPC code 6 = ALREADY_EXISTS — expected if dailyBatchJob (or a
    // manual "Run now") fires twice for the same day/slot; Cloud Tasks
    // keeps task names reserved for a window after creation/completion.
    const code = (err as { code?: number })?.code;
    if (code !== 6) throw err;
  }
}
