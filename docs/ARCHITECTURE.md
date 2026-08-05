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
   camera screen (`go_router`), which also shows the slot's prompt text and (slot 3) a countdown
   to 24:00 JST overlaid on the live preview.
4. The user shoots a photo with the in-app-only camera, chooses public/private (+ an optional
   caption if public), and it's written to `posts/{postId}` + Storage under `posts/{uid}/...`.
5. Mutual connections (see "Resolved: groups → mutual connections" below) see the post in their
   following feed regardless of the public/private choice; a public post is additionally visible
   to everyone via "みんなの投稿".
6. The iOS home screen widget (WidgetKit) reads the latest prompt + this device's post status from
   a shared App Group container that the Flutter app keeps updated via the `home_widget` package
   (including from a background isolate when a prompt arrives while the app is fully terminated).

## Cost design (running-cost-conscious choices)

Firebase Cloud Functions require the **Blaze (pay-as-you-go) plan**, but the design here is meant
to comfortably fit inside the free-tier allowances of that plan for a small-to-medium user base:

- **Batch job frequency**: `dailyBatchJob` runs once a day (00:00 JST). This is the only
  *scheduled* (cron) function — no per-user or per-slot cron jobs.
- **Push delivery pattern**: prompt content is identical for every user. So the batch job
  publishes to a **single global FCM topic** (`daily_prompts`, see
  `functions/src/services/notificationService.ts`) — O(1) sends per slot. Exact send-time
  delivery (times are admin-configurable per day, not fixed crons) is done via **Cloud Tasks**:
  `dailyBatchJob` schedules 3 tasks/day targeting the `sendScheduledPrompt` HTTPS function, which
  fires the actual FCM send at each slot's exact time. Both Cloud Tasks and the extra HTTPS
  invocations sit comfortably inside free-tier allowances at 3 tasks/day.
- **Firestore reads/writes**: avoid fan-out writes (e.g. don't write a "notified" doc per user per
  slot). Prefer topic messaging + client-side read state where possible. The following feed's "one
  query per connection" approach (see below) is a deliberate exception to this, scoped to friend-
  list sizes where it's still cheap.
- **Storage egress**: photo uploads are the dominant cost driver at scale. `CaptureController`
  (`mobile/lib/features/camera/application/camera_controller.dart`) compresses to ~1600px /
  quality 80 before ever holding the bytes in state; `storage.rules` caps upload size at 8MB as a
  backstop, not the primary control.
- **Admin panel hosting**: default to deploying `admin-panel` on **Vercel's free/Hobby tier**
  rather than Firebase Hosting + Cloud Run "web frameworks" support, to avoid paying for an
  always-on container for what's a low-traffic internal tool. `firebase.json` deliberately does
  **not** wire Hosting rewrites for it — this is a documented open decision, not a blocker.
- **Firestore composite indexes**: declared only for queries that actually exist and need one
  (the public feed's two sort orders, ProfileScreen's per-user public-post grid, the admin panel's
  pending-suggestions queue) — see `firestore.indexes.json` and [DATA_MODEL.md](./DATA_MODEL.md)
  "Composite indexes". Multi-field equality-only queries (e.g. the following feed's
  `userId + date`) deliberately don't get one — Firestore serves those from automatic single-field
  indexes already.
- **Likes via a trigger, not a client counter**: `posts/{postId}/likes/{uid}` create/delete fires
  a Firestore trigger (`functions/src/triggers/likes.ts`) that increments/decrements
  `Post.likeCount` server-side, rather than loosening `posts`' write rule to let any signed-in
  user (now potentially the whole user base, via public posts) touch the post document directly.
  Trigger invocations are bounded by actual like-button presses, not a scheduled cost driver.
- **Accepting a connection via a callable, not a wider write rule**: same reasoning as likes —
  `respondToFriendRequest` (Admin SDK) is the only way a `connections` doc is ever created, so
  `firestore.rules` doesn't need to reason about arbitrary cross-user writes.

## Known open gaps

- **Hosting choice for `admin-panel`**: Vercel vs. Firebase Hosting is left open; see above.
- **Only a flat mutual-or-not relationship**: no "close friends" tiers, no blocking, no limit on
  connection count. See "Resolved: groups → mutual connections" below for what IS built.
- **Image compression tuning**: `CaptureController.capture()` compresses to ~1600px/quality 80
  before upload, but those numbers are a starting guess, not tuned against real device photos.
- **Following feed doesn't paginate**: `watchUserPosts` issues one Firestore listener per
  connection with no upper bound — fine at friend-following scale, would need batching/pagination
  for someone with hundreds of connections. See its doc comment in
  `mobile/lib/features/feed/data/feed_repository.dart`.

### Resolved: groups → mutual connections (two pivots this session)

This went through three shapes before landing here:

1. **Group membership** (original scaffold) — invite-code create/join, one group per user,
   `posts.groupId` scoped visibility to the group.
2. **One-directional follow** (briefly) — Twitter-style, no approval step.
3. **Mutual connection via request + accept** (current) — closer to a friend request. Sending or
   cancelling a `friend_requests/{fromUid}_{toUid}` doc is a plain client write (rules-enforced);
   **accepting** one is not, since it has to atomically create a `connections/{sortedPair}` doc
   AND delete the request — that's `respondToFriendRequest`
   (`functions/src/callable/connections.ts`), the one place in this relationship model that needs
   server-side arbitration. Unfriending (deleting a `connections` doc) is a plain client write by
   either party, no approval needed for that direction.

A mutual connection sees ALL of the other person's posts regardless of `Post.isPublic` — this is
what group membership used to grant. `isPublic` now only controls whether a post ALSO surfaces to
people you're not connected to, via "みんなの投稿". See [DATA_MODEL.md](./DATA_MODEL.md) for the
full schema and the `posts`/Storage rules for how both checks compose.

`connectionId(a, b)` (sorted-pair doc id) is implemented identically in three places that must
stay in sync: `packages/shared-types/src/index.ts`, `firestore.rules`/`storage.rules`, and
mobile's `ConnectionRepository`.

### Resolved: TikTok-style following feed

`mobile`'s first tab ("フォロー中") is a full-screen vertical `PageView` — one page per
connection, swipe up/down to move between people. Within a page, a second horizontal `PageView`
holds that person's 3 daily slots, Instagram-carousel style; a slot nobody's posted to yet shows
`PulsingPlaceholder` (a soft opacity-pulse placeholder — PingPic's own interpretation of "waiting
for a photo", not a pixel-for-pixel reproduction of any specific app's animation) instead of a
photo. The prompt text and (slot 3) a countdown are overlaid at the bottom, same visual language
as the camera screen's top bar.

Cost note: this issues one `watchUserPosts(uid, date)` Firestore listener per connection (see the
cost-design section above) — acceptable at friend-following scale, flagged as a real limit in
"Known open gaps" for larger connection counts.

### Resolved: profile screens

Reachable by tapping an avatar/name anywhere one appears (PostCard, the following feed's
overlay). Shows the person's display name, a `ConnectionButton` (see below) if it's not your own
profile, and a grid of their **public** posts only ("下に公開とした投稿が表示" per this session's
requirement) — even once connected, this screen doesn't also surface their private posts; the
following feed is what's for those. `displayName` is passed through navigation (query param) from
wherever the tap originated rather than looked up from a user-profile collection, which doesn't
exist in this app.

`ConnectionButton` (`features/connections/presentation/widgets/`) is a 4-state widget — none (send
request) / outgoing pending (cancel) / incoming pending (accept) / connected (remove) — built by
nesting 3 single-document `StreamBuilder`s rather than pulling in a stream-combining dependency
for what's only ever 3 listeners.

### Resolved: settings screen

`mobile`'s settings screen (gear icon on the "みんな" tab's app bar) covers: account email +
sign-out, a notification on/off toggle (persisted via `shared_preferences` — FCM has no client API
to query "am I subscribed to topic X", so this is the local source of truth, kept in sync with
actual `subscribeToDailyPrompts`/`unsubscribeFromDailyPrompts` calls), a friend-requests inbox
(accept/reject, badge-counted), a connections list (view/unfriend), a link to the existing prompt-
suggestion form, and the app version (`package_info_plus`).

### Resolved: admin auth (session cookies + server-side verification)

Previously a client-side-only `AuthGuard` component (checked the Firebase Auth state and custom
claim in the browser, redirected if missing) — real content was still delivered to the browser
before that check ran, and nothing was verified server-side. Now:

- `/login` signs in with the client SDK, then exchanges the ID token for an HttpOnly session
  cookie via `POST /api/session` (`admin-panel/src/app/api/session/route.ts`), which verifies the
  token and the `admin` claim with the Admin SDK before issuing the cookie.
- `(admin)/layout.tsx` (a Server Component, Node.js runtime) calls `verifySessionCookie` on every
  request — this is the real boundary now.
- `middleware.ts` (Edge runtime) only does a cheap cookie-presence check for UX, since the Admin
  SDK can't run at the Edge in Next.js 14 — real verification is left entirely to the layout.
- The first (and every subsequent) admin's `admin: true` custom claim is granted via
  `scripts/grant-admin-claim.mjs`, run locally with a service account key — deliberately not a
  self-service admin-panel action. See [SETUP.md](./SETUP.md).

### Resolved: widget updates while fully terminated

`HomeWidgetService`'s call sites (new prompt notification, after posting) only ran while the app
process was alive. `mobile/lib/main.dart` now registers
`FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)` — a top-level function
(`features/notifications/data/push_notification_service.dart`) that FCM runs in its own isolate
with no access to app state, so it re-initializes Firebase and talks to the `home_widget` package
directly rather than through `HomeWidgetServiceImpl`. This is what makes the widget update even
when a prompt arrives with the app fully killed, not just backgrounded.

### Resolved: public posts / みんなの投稿 (like/comment system)

Design decision (not in the original spec): at capture time, the poster can make an individual
photo public — visible to any signed-in user via a "みんなの投稿" tab, with an optional one-line
caption, likes, and comments. Deliberately a capture-time choice, not toggleable afterward (no
editing flow anywhere else in the app either).

- `mobile`'s root screen is `HomeShell` (`core/widgets/home_shell.dart`), a two-tab
  `NavigationBar` shell (フォロー中 / みんな) — `AppRoutes.feed` ("/") builds this instead of a
  single feed screen.
- The public feed (`features/public_feed/`) is a flat stream of every public post, deliberately
  mixing posts from different prompts/dates/users together rather than grouping by prompt. Each
  card denormalizes and shows its own `promptText` (so a mixed feed still makes sense per-card)
  and defaults to most-liked-first (`PublicFeedSort.mostLiked`), with a toggle to newest-first —
  see `PublicFeedRepository.watchPublicPosts`.
- Card design follows Instagram's post-card convention (avatar+name header — tap to open their
  profile — full-width photo with the prompt as a corner badge, like/comment icon row, caption,
  "view comments" link) since that's a well-understood pattern for exactly this kind of public
  social feed — see `widgets/post_card.dart`.
- Likes: see the cost-design note above on why a Cloud Functions trigger drives `likeCount` rather
  than a client-writable counter.
- Comments: a straightforward `posts/{postId}/comments` subcollection, no edit/delete-by-author
  (same "no editing" posture as posts themselves), 1–280 chars enforced in `firestore.rules`.
- `authorDisplayName` and `promptText` are both denormalized onto `Post` at write time — there's
  no user-profile collection to join against, and re-deriving the prompt from `daily_schedules`
  per card would mean an extra read per post in a feed that can mix many different dates.

## UI design system (mobile)

See `mobile/lib/core/theme/`: `app_colors.dart` (a small hand-picked palette: warm coral primary,
muted teal-green for "posted"/success states, near-black/warm-cream surfaces — not a BeReal clone,
but takes cues from it and from TikTok/Instagram's social-feed conventions per this session's
direction) and `app_text_styles.dart` (a hand-tuned type scale using system fonts — no
`google_fonts` dependency, since every string in this app is Japanese and a Latin-only display
font wouldn't affect any of the copy that actually needs it). `core/widgets/` holds cross-screen
pieces: `CountdownText` (also what implements the design doc's slot-3 "当日24:00まで(カウントダウン
表示)" requirement, missed in earlier passes), `EmptyState`, `StatusPill`, `PulsingPlaceholder`,
`HomeShell`.
