import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { getMessaging } from "firebase-admin/messaging";
import { getAdminApp } from "../config/firebaseAdmin";
import { FUNCTIONS_REGION } from "../config/params";
import { DAILY_PROMPTS_TOPIC } from "../services/notificationService";

interface SendScheduledPromptBody {
  date: string; // "YYYY-MM-DD"
  slotNumber: 1 | 2 | 3;
  promptText: string;
}

function isValidBody(body: unknown): body is SendScheduledPromptBody {
  const b = body as Partial<SendScheduledPromptBody> | undefined;
  return (
    !!b &&
    typeof b.date === "string" &&
    (b.slotNumber === 1 || b.slotNumber === 2 || b.slotNumber === 3) &&
    typeof b.promptText === "string" &&
    b.promptText.length > 0
  );
}

/**
 * Invoked by Cloud Tasks (see services/notificationService.ts
 * schedulePromptNotification) at exactly a slot's sendTime. NOT deployed
 * with --allow-unauthenticated — Cloud Tasks calls it with a Google-signed
 * OIDC token, which gen2 Cloud Functions verifies automatically before
 * this handler runs; grant the Cloud Tasks queue's service account the
 * Cloud Functions Invoker role (see docs/SETUP.md) or every call 403s.
 *
 * Sends one FCM message to the single global DAILY_PROMPTS_TOPIC — see
 * notificationService.ts for why a global topic (not per-group/per-user)
 * is the deliberate, cost-minimal choice here.
 */
export const sendScheduledPrompt = onRequest(
  { region: FUNCTIONS_REGION, memory: "128MiB", timeoutSeconds: 30 },
  async (req, res) => {
    if (!isValidBody(req.body)) {
      res.status(400).send("Bad Request: expected { date, slotNumber, promptText }");
      return;
    }
    const { date, slotNumber, promptText } = req.body;

    getAdminApp();
    const messageId = await getMessaging().send({
      topic: DAILY_PROMPTS_TOPIC,
      notification: {
        title: `お題 ${slotNumber}`,
        body: promptText,
      },
      data: {
        date,
        slotNumber: String(slotNumber),
      },
      apns: {
        payload: {
          aps: {
            // TODO: a real notification-service-extension / category is
            // needed for "tap notification -> open straight to camera
            // screen" per the design doc's lock-screen requirement — this
            // is just the data payload the Flutter side reads to route.
            category: "PINGPIC_PROMPT",
          },
        },
      },
    });

    logger.info("sendScheduledPrompt: sent", { date, slotNumber, messageId });
    res.status(200).send("ok");
  }
);
