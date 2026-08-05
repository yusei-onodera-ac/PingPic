# PingPic — Architecture Overview

## Three pieces, one monorepo

```
mobile/         Flutter app (iOS-first), separate Dart/pub ecosystem
functions/      Firebase Cloud Functions (TypeScript) — 00:00 batch job, push scheduling
admin-panel/    Next.js admin panel — calendar-style prompt editor
packages/shared-types/   TS types for Firestore documents, shared by functions + admin-panel
```

Single git history because `functions`, `admin-panel`, and `packages/shared-types` share a Firestore
schema that must stay in lockstep — splitting repos would require versioning and publishing
`shared-types` as a real package, which isn't justified at this size.

**Known duplication**: Dart cannot import the TypeScript `shared-types` package. Flutter models
under `mobile/lib/**/data/*_model.dart` are hand-mirrored copies of the shapes in
`packages/shared-types/src/index.ts`. If the two drift, Firestore rules/tests won't catch it —
this is a real risk to keep in mind as the schema evolves. A future improvement is generating the
Dart models from a shared JSON Schema (e.g. via `quicktype`), but that's out of scope for this
scaffold.

## Data flow (high level)

1. Admin sets/edits `daily_schedules/{date}` slots via the Next.js admin panel (or leaves them
   unset).
2. Every day at 00:00 JST, the `dailyBatchJob` Cloud Function reads that day's schedule, fills any
   unset slot from `prompt_pool` (respecting the ≥4h gap / 07:00–22:00 window), and schedules the
   day's 3 push notifications.
3. At each scheduled time, a push goes out; tapping it deep-links the Flutter app straight to the
   camera screen (`go_router`).
4. The user shoots a photo with the in-app-only camera and it's written to `posts/{postId}` +
   Storage under `posts/{uid}/...`.
5. The iOS home screen widget (WidgetKit) reads the latest prompt + group post status from a
   shared App Group container that the Flutter app keeps updated via the `home_widget` package.

## Cost design (running-cost-conscious choices)

Firebase Cloud Functions require the **Blaze (pay-as-you-go) plan**, but the design here is meant
to comfortably fit inside the free-tier allowances of that plan for a small-to-medium user base:

- **Batch job frequency**: `dailyBatchJob` runs once a day (00:00 JST). This is the only
  *scheduled* (cron) function — no per-user or per-slot cron jobs.
- **Push delivery pattern**: prompt content is identical for every user (the design doc has one
  global prompt per slot, not per-group). So the batch job publishes to a **single global FCM
  topic** (`daily_prompts`, see `functions/src/services/notificationService.ts`) — O(1) sends per
  slot, cheaper than even a per-group loop. Exact send-time delivery (times are
  admin-configurable per day, not fixed crons) is done via **Cloud Tasks**: `dailyBatchJob`
  schedules 3 tasks/day targeting the `sendScheduledPrompt` HTTPS function, which fires the
  actual FCM send at each slot's exact time. Both Cloud Tasks and the extra HTTPS invocations sit
  comfortably inside free-tier allowances at 3 tasks/day.
- **Firestore reads/writes**: avoid fan-out writes (e.g. don't write a "notified" doc per user per
  slot). Prefer topic messaging + client-side read state where possible.
- **Storage egress**: photo uploads are the dominant cost driver at scale. The Flutter camera
  repository (`mobile/lib/features/camera/data/camera_repository.dart`) has a TODO to
  compress/resize images client-side before upload; `storage.rules` caps upload size at 8MB as a
  guardrail.
- **Admin panel hosting**: default to deploying `admin-panel` on **Vercel's free/Hobby tier**
  rather than Firebase Hosting + Cloud Run "web frameworks" support, to avoid paying for an
  always-on container for what's a low-traffic internal tool. `firebase.json` deliberately does
  **not** wire Hosting rewrites for it — this is a documented open decision, not a blocker.
- **Firestore composite indexes**: none are pre-declared (`firestore.indexes.json` is empty) —
  add them only once real queries (e.g. `posts` by `groupId + date + slotNumber`) are built, to
  avoid maintaining unused indexes.

## Known open gaps

- **Admin auth**: production should move from the client-side `AuthGuard` redirect to Next.js
  `middleware.ts` + session cookies (`Admin SDK.createSessionCookie`). Scaffolded as a TODO —
  see `admin-panel/src/components/layout/AuthGuard.tsx`.
- **Hosting choice for `admin-panel`**: Vercel vs. Firebase Hosting is left open; see above.
- **Group feed UI**: now that `groups` exists (see below), `mobile`'s FeedScreen only shows the
  signed-in user's own post status per slot — a real shared group feed (seeing groupmates'
  blurred/unblurred posts, per the design doc's retention mechanic) is still unbuilt.
- **No "leave group" / multi-group support**: the invite-code flow (below) is intentionally an
  MVP simplification — one group per user, no leave flow.
- **Image compression before upload**: not implemented — see
  `mobile/lib/features/camera/application/camera_controller.dart`'s TODO. `storage.rules` only
  rejects >8MB, it doesn't shrink anything.
- **HomeWidgetService not called from any real app flow yet**: the service and its App Group
  wiring work, but nothing invokes `updateWidgetData` after a prompt notification or a post yet.

### Resolved: `groups` collection (was previously unconfirmed)

The design doc never defined how groups are created or joined. Decision made when implementing
this: **invite-code based create/join**, one group per user for this MVP. `createGroup` and
`joinGroupByInviteCode` (`functions/src/callable/groups.ts`) are the only way `groups` and
`invite_codes` get written — never direct client writes — so invite-code uniqueness is enforced
with a server-side Firestore transaction, and `firestore.rules` stays simple (members can read
their own group; everything else is `allow write: if false`). This also finally let
`posts` and Storage's `posts.rules` enforce real group-membership checks instead of the
placeholder TODOs from earlier passes.
