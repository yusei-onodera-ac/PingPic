# PingPic — Local Setup

This repo was scaffolded without Node.js, Flutter SDK, or the Firebase CLI installed on the
authoring machine, so none of the commands below have been run yet. Install the tools, then
follow this order.

## 0. Prerequisites

- Node.js 20.x LTS + npm
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) — consider
  [FVM](https://fvm.app/) to pin the version via `mobile/.fvmrc`
- Xcode (for iOS build + the WidgetKit target — see [IOS_WIDGET_SETUP.md](./IOS_WIDGET_SETUP.md))
- A Firebase project on the **Blaze plan** (required for Cloud Functions; see cost notes in
  [ARCHITECTURE.md](./ARCHITECTURE.md)) — or just use the local Emulator Suite for all dev work.

## 1. Root workspace

```bash
npm install
firebase login
firebase use --add   # pick/create your Firebase project, replaces the "pingpic-dev" placeholder in .firebaserc
```

## 2. Shared types

```bash
npm run build --workspace=packages/shared-types
```

## 3. Firebase backend (Cloud Functions + Firestore/Storage rules)

```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --only firestore,functions,auth,storage
```

Open http://localhost:4000 (Emulator UI) — confirm `dailyBatchJob` is listed under Functions and
can be triggered manually ("Run now").

### Cloud Tasks (one-time, per Firebase project)

`dailyBatchJob` schedules exact-time push delivery via Cloud Tasks (see
[docs/ARCHITECTURE.md](./ARCHITECTURE.md) "Cost design"). This needs a queue and an IAM grant
that only have to be set up once per project, and can't be expressed in `firebase.json`:

```bash
gcloud tasks queues create daily-prompt-notifications --location=asia-northeast1

# Allow the Cloud Tasks queue's service account to invoke the (non-public)
# sendScheduledPrompt function it targets:
gcloud functions add-invoker-policy-binding sendScheduledPrompt \
  --region=asia-northeast1 \
  --member="serviceAccount:<PROJECT_ID>@appspot.gserviceaccount.com"
```

Then set the `SEND_SCHEDULED_PROMPT_URL` param (chicken-and-egg: this needs `sendScheduledPrompt`
to have been deployed once already, to know its URL):

```bash
firebase deploy --only functions:sendScheduledPrompt   # first deploy, to learn its URL
firebase functions:params:set SEND_SCHEDULED_PROMPT_URL="https://asia-northeast1-<PROJECT_ID>.cloudfunctions.net/sendScheduledPrompt"
firebase deploy --only functions                        # redeploy dailyBatchJob with the param set
```

Secrets (APNs signing key, etc.) are **never** stored in a `.env` file — use:

```bash
firebase functions:secrets:set APNS_AUTH_KEY
```

and reference it via `firebase-functions/params` `defineSecret` in code (see
`functions/src/config/firebaseAdmin.ts` for the wiring point).

## 4. Admin panel

```bash
cd admin-panel
cp .env.local.example .env.local   # fill in your Firebase web app config AND
                                    # FIREBASE_ADMIN_SERVICE_ACCOUNT_JSON (server-only —
                                    # see that file's comment on where to get it)
npm install
npm run dev
```

Visit http://localhost:3000 — should redirect to `/login`.

### Bootstrapping the first admin

Nobody can sign in successfully until at least one Firebase Auth account has the `admin: true`
custom claim — there's no self-service path to get it (that would defeat the point). From the
repo root, with a downloaded service account key:

```bash
npm run grant-admin-claim -- --email=you@example.com --service-account=./serviceAccountKey.json
```

The account must already exist in Firebase Auth (create it via the Firebase Console or have the
person sign up once and fail to get in first). See `scripts/grant-admin-claim.mjs` for the
revoke flag and more detail.

### How sign-in actually gates access

`/login` signs in with the Firebase client SDK, then POSTs the resulting ID token to
`/api/session` (`admin-panel/src/app/api/session/route.ts`), which verifies it with the Admin SDK,
checks the `admin` claim, and — only if that passes — sets an HttpOnly session cookie. The
`(admin)/layout.tsx` Server Component re-verifies that cookie (`verifySessionCookie`, with
`checkRevoked`) on every request; `middleware.ts` only does a cheap cookie-presence check for
UX (Next.js 14 middleware runs on the Edge runtime, which can't run the Admin SDK — the layout is
where real verification happens). See [ARCHITECTURE.md](./ARCHITECTURE.md) for more.

Deploy target: **Vercel (free/Hobby tier)** by default — see the cost note in
[ARCHITECTURE.md](./ARCHITECTURE.md). Firebase Hosting + Cloud Run is an open alternative, not
wired up here.

## 5. Mobile app (Flutter)

The `mobile/` directory in this scaffold contains only the Dart source (`lib/`), `pubspec.yaml`,
and `analysis_options.yaml` — **not** the generated `ios/`/`android/` platform folders. Those are
produced by the Flutter tool itself and shouldn't be hand-authored (see
[IOS_WIDGET_SETUP.md](./IOS_WIDGET_SETUP.md) for why). To bootstrap them:

```bash
cd mobile
flutter create --org com.pingpic --project-name pingpic .
flutter pub get
```

This generates `ios/`, `android/`, etc. **without overwriting** the existing `lib/`,
`pubspec.yaml`, or `analysis_options.yaml` in this scaffold (Flutter's `create` merges into an
existing directory). After that:

```bash
dart pub global activate flutterfire_cli
flutterfire configure   # generates lib/firebase_options.dart for real — overwrites the placeholder
flutter analyze
flutter test
flutter run -d <ios-simulator-id>
```

Then apply the iOS-specific overrides documented in
[IOS_WIDGET_SETUP.md](./IOS_WIDGET_SETUP.md) (Info.plist camera-only permission text, App Group
entitlement, WidgetKit extension target).

## Verification checklist

- [ ] `npm ls --workspaces` from repo root resolves `@pingpic/shared-types` for both `functions`
      and `admin-panel`
- [ ] `firebase emulators:start` boots with no rules-parse errors
- [ ] `admin-panel`: `npm run build` and `npm run type-check` are clean
- [ ] `mobile`: `flutter analyze` and `flutter test` are clean after `flutter create .`
