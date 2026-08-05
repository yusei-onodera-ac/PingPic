import { defineString } from "firebase-functions/params";

/**
 * Deployment-environment config (not secrets — no defineSecret needed).
 * Set via `firebase functions:config:set` equivalents / .env.<project-id>
 * files that firebase-functions/params reads at deploy time, or via
 * `firebase deploy --only functions` prompts on first deploy.
 *
 * sendScheduledPromptUrl: the HTTPS URL of the `sendScheduledPrompt`
 * function once deployed (region-qualified, e.g.
 * https://asia-northeast1-<project>.cloudfunctions.net/sendScheduledPrompt).
 * Cloud Tasks created by notificationService.ts target this URL. It can't
 * be known before first deploy — see docs/SETUP.md for the bootstrap
 * chicken-and-egg (deploy once, then set this, then redeploy).
 */
export const sendScheduledPromptUrl = defineString("SEND_SCHEDULED_PROMPT_URL");

/** Region used for both Cloud Functions and the Cloud Tasks queue — keep
 * these in the same region to avoid cross-region latency/cost. */
export const FUNCTIONS_REGION = "asia-northeast1";
export const CLOUD_TASKS_QUEUE = "daily-prompt-notifications";
