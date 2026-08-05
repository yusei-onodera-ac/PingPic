#!/usr/bin/env node
/**
 * One-off script to grant (or revoke) the `admin: true` custom claim that
 * gates the whole admin-panel (see admin-panel/src/app/(admin)/layout.tsx
 * and app/api/session/route.ts). Deliberately NOT a UI action — run by a
 * project owner with direct access to a service account key, since it's
 * how the FIRST admin gets created (there's no other bootstrap path by
 * design: a self-service "make me admin" button would defeat the point).
 *
 * Usage:
 *   node scripts/grant-admin-claim.mjs --email=you@example.com \
 *     --service-account=./serviceAccountKey.json
 *
 *   node scripts/grant-admin-claim.mjs --email=you@example.com \
 *     --service-account=./serviceAccountKey.json --revoke
 *
 * The service account JSON is the same kind of file
 * admin-panel/.env.local.example's FIREBASE_ADMIN_SERVICE_ACCOUNT_JSON
 * wants (download from Firebase Console -> Project Settings -> Service
 * Accounts -> Generate new private key). Never commit it — see the root
 * .gitignore, which already excludes serviceAccountKey.json by name.
 *
 * Requires `firebase-admin` to be resolvable from here — `npm install` at
 * the repo root (npm workspaces hoist functions/'s firebase-admin
 * dependency), or run from inside functions/ if that ever stops being
 * true.
 */

import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

function parseArgs(argv) {
  const args = { revoke: false };
  for (const arg of argv) {
    if (arg === "--revoke") {
      args.revoke = true;
    } else if (arg.startsWith("--email=")) {
      args.email = arg.slice("--email=".length);
    } else if (arg.startsWith("--service-account=")) {
      args.serviceAccountPath = arg.slice("--service-account=".length);
    }
  }
  return args;
}

async function main() {
  const { email, serviceAccountPath, revoke } = parseArgs(process.argv.slice(2));

  if (!email || !serviceAccountPath) {
    console.error(
      "Usage: node scripts/grant-admin-claim.mjs --email=<email> --service-account=<path> [--revoke]"
    );
    process.exit(1);
  }

  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf8"));
  initializeApp({ credential: cert(serviceAccount) });
  const auth = getAuth();

  const user = await auth.getUserByEmail(email);
  const existingClaims = user.customClaims ?? {};
  await auth.setCustomUserClaims(user.uid, { ...existingClaims, admin: !revoke });

  console.log(
    `${revoke ? "Revoked" : "Granted"} admin claim for ${email} (uid: ${user.uid}).`
  );
  console.log(
    "They must sign out and back in (or their current session cookie must expire) " +
      "for this to take effect, since Firebase ID tokens cache claims."
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
