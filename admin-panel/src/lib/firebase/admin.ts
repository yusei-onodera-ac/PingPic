import "server-only";
import { initializeApp, getApps, cert, App } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Server-only Admin SDK. NEVER import this from a 'use client' file — the
 * `server-only` import above makes that a build-time error if attempted.
 *
 * Used by: (admin)/layout.tsx (verifySessionCookie — the real auth
 * boundary, see that file), app/api/session/route.ts
 * (verifyIdToken/createSessionCookie), and any future server
 * components/route handlers/CalendarView-style data hooks that need
 * elevated Firestore access.
 *
 * Assigning the `admin: true` custom claim itself (making an account an
 * admin in the first place) is intentionally NOT here or anywhere in
 * this app — it's a one-off script run by a project owner with direct
 * service-account access, not a self-service admin-panel action. See
 * scripts/grant-admin-claim.mjs at the repo root.
 */
function getAdminApp(): App {
  const existing = getApps();
  if (existing.length > 0) return existing[0];

  const serviceAccountJson = process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    throw new Error(
      "FIREBASE_ADMIN_SERVICE_ACCOUNT_JSON is not set — see admin-panel/.env.local.example"
    );
  }
  return initializeApp({
    credential: cert(JSON.parse(serviceAccountJson)),
  });
}

export const adminAuth = () => getAuth(getAdminApp());
export const adminDb = () => getFirestore(getAdminApp());
