import { initializeApp, getApps, App } from "firebase-admin/app";

/**
 * Singleton Admin SDK app instance. Import `adminApp` (or the Firestore/Auth
 * getters below) rather than calling initializeApp() again elsewhere —
 * Cloud Functions can re-invoke module scope across warm instances, and
 * double-init throws.
 */
export function getAdminApp(): App {
  const existing = getApps();
  if (existing.length > 0) {
    return existing[0];
  }
  return initializeApp();
}

/**
 * Secrets (e.g. APNS_AUTH_KEY) should be declared with
 * `firebase-functions/params` `defineSecret` and bound per-function via
 * `runWith({ secrets: [...] })` — NOT read from `.env` or committed files.
 * See docs/SETUP.md "Firebase backend" section.
 *
 * TODO: once APNs is wired directly (if not going through FCM's APNs
 * bridge), declare the secret here, e.g.:
 *   export const apnsAuthKey = defineSecret("APNS_AUTH_KEY");
 */
