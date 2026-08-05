# PingPic — Firestore Data Model

Source of truth for these shapes (TypeScript) is `packages/shared-types/src/index.ts`. Field
names are **camelCase** throughout (`userId`, not `user_id`) — this must match exactly in
`firestore.rules`/`storage.rules` and in the hand-mirrored Dart models under
`mobile/lib/**/data/*_model.dart` (see the duplication note in
[ARCHITECTURE.md](./ARCHITECTURE.md)); a naming mismatch there silently breaks rules (the field
reads as `null` and every equality check fails closed) rather than throwing a visible error.

## `daily_schedules/{date}`

Doc id: `YYYY-MM-DD`.

| field | type                                          | notes                                                                 |
|-------|------------------------------------------------|-------------------------------------------------------------------------|
| slots | `(ScheduleSlot \| null)[3]` (fixed length 3)   | slot 1/2/3 in order. `null` = not yet configured by an admin — normal during the day, auto-filled by `dailyBatchJob` at 00:00. A missing doc means all 3 are effectively null. |

`ScheduleSlot`:

| field       | type                                                                 | notes |
|-------------|------------------------------------------------------------------------|-------|
| sendTime    | Firestore `Timestamp`                                                   | within 07:00–22:00, ≥4h apart across the day's 3 slots |
| promptText  | `string`                                                                | |
| credit      | `{ type: "admin" }` \| `{ type: "user"; uid: string; displayName: string }` | shown as "○○さん考案" / "運営考案" |

## `friend_requests/{fromUid}_{toUid}` — ⚠️ inferred, not in the original design doc

| field           | type                    | notes |
|-----------------|--------------------------|-------|
| fromUid         | `string`                 | |
| toUid           | `string`                 | |
| fromDisplayName | `string`                 | denormalized, so the recipient's request inbox can show a name |
| status          | `"pending"`               | only ever "pending" while the doc exists — see below |
| createdAt       | Firestore `Timestamp`    | |

**Design decision (not in the original spec)** — the third relationship model this session
landed on, after group membership and then a one-directional follow graph: a **mutual**
connection gated by request + accept, closer to a friend request than a Twitter-style follow.
Sending/cancelling a request is a plain client write (rules-enforced, doc id `{fromUid}_{toUid}`
prevents duplicate pending requests in the same direction). **Accepting** one is not — it also has
to atomically create the `connections` doc below and delete the request, which a rules-only
client write can't coordinate — see `respondToFriendRequest`
(`functions/src/callable/connections.ts`). Rejecting is just a delete, done directly by the
recipient. Accepted/rejected requests aren't kept around with a terminal status; the doc is simply
gone once resolved.

## `connections/{sortedUidA}_{sortedUidB}`

| field        | type                              | notes |
|--------------|-------------------------------------|-------|
| uids         | `[string, string]`                  | the two uids, sorted ascending — matches the doc id |
| displayNames | `Record<string, string>`             | keyed by uid, so either party can show the other's name |
| createdAt    | Firestore `Timestamp`               | |

One doc per pair (not two mirrored per-user subcollection docs) since the relationship is
symmetric — a single `exists()` check from either side, no risk of mirrors drifting. Doc id is
deterministic (`connectionId()` in shared-types, mirrored in `firestore.rules` and mobile's
`ConnectionRepository`) so both sides always compute the same path. **Only** created by
`respondToFriendRequest` (`allow create: if false` in `firestore.rules`); deleting one
("unfriend") is a plain client write by either party.

Still open: no support for anything beyond a flat mutual-or-not relationship (no "close friends"
tiers, no blocking).

## `posts/{postId}`

| field             | type                     | notes |
|-------------------|--------------------------|-------|
| userId            | `string`                 | Firebase Auth uid |
| authorDisplayName | `string`                 | denormalized at post time — no separate user-profile collection exists |
| date              | `string` (`YYYY-MM-DD`)  | |
| slotNumber        | `1 \| 2 \| 3`            | |
| photoUrl          | `string`                 | Storage download URL, `posts/{uid}/...` |
| postedAt          | Firestore `Timestamp`    | |
| promptText        | `string`                 | denormalized copy of the slot's prompt at post time |
| isPublic          | `boolean`                | chosen once at capture time, never toggled after — see below |
| caption           | `string`                 | optional one-line comment, only meaningful/shown when `isPublic` |
| likeCount         | `number`                 | maintained server-side, see below — never client-writable |

No edit/delete-by-owner path — the spec has no photo-editing feature, so `posts` are
effectively append-only from the client's perspective (rules only allow admin update/delete).

**Privacy model**: a mutual connection can always see all of a user's posts, regardless of
`isPublic` (this is what group membership used to grant). `isPublic: true` additionally surfaces
the post to any signed-in user via the "みんなの投稿" feed and lets it carry a caption/likes/
comments in that wider context. Chosen once at capture time, not toggleable after (no editing
flow anywhere else in the app either).

### `posts/{postId}/likes/{uid}`

| field     | type                   | notes |
|-----------|------------------------|-------|
| createdAt | Firestore `Timestamp`  | |

Doc id IS the liker's uid — liking = create this doc, unliking = delete it; existence alone is
the signal, no other fields needed. Clients only ever create/delete their OWN like doc — they
never write `posts.likeCount` directly. `functions/src/triggers/likes.ts` (Firestore
onCreate/onDelete triggers) maintains that counter server-side instead, so `posts`' write rule
can stay admin-only even though "like" is now a plain signed-in-user action on documents that
might be visible to the entire user base.

### `posts/{postId}/comments/{commentId}`

| field       | type                   | notes |
|-------------|------------------------|-------|
| userId      | `string`               | |
| displayName | `string`               | denormalized, same convention as `authorDisplayName` |
| text        | `string`               | 1–280 chars, enforced in firestore.rules |
| createdAt   | Firestore `Timestamp`  | |

No edit/delete-by-author, same "no editing" posture as posts themselves.

## `prompt_suggestions/{suggestionId}`

| field          | type                                             | notes |
|----------------|---------------------------------------------------|-------|
| suggestionText | `string`                                           | |
| submitterInfo  | `{ uid: string; displayName: string }`             | |
| status         | `"pending" \| "approved" \| "rejected"`            | admin transitions only |
| createdAt      | Firestore `Timestamp`                              | |

## `prompt_pool/{entryId}` — the "popular prompt" stock

| field      | type                   | notes |
|------------|------------------------|-------|
| promptText | `string`               | |
| usageCount | `number`                | incremented each time the batch job uses it, for admin visibility |
| createdAt  | Firestore `Timestamp`  | |

Used only by `dailyBatchJob` (via Admin SDK, bypasses rules) and the admin panel's
"popular prompt pool" management screen.

## Composite indexes

Declared in `firestore.indexes.json`:
- `posts`: `isPublic ASC, postedAt DESC` — the "みんなの投稿" feed's newest-first sort.
- `posts`: `isPublic ASC, likeCount DESC` — that feed's default most-liked-first sort.
- `posts`: `userId ASC, isPublic ASC, postedAt DESC` — ProfileScreen's "公開した投稿" grid.
- `prompt_suggestions`: `status ASC, createdAt ASC` — the admin panel's pending-suggestions queue.

`userId + date` (two pure equality filters, used by `watchUserPosts` for the following feed) does
NOT need one — Firestore serves multi-field equality-only queries from its automatic single-field
indexes. `friend_requests`' `toUid + status` query (incoming requests) is similarly two equality
filters only, no composite index needed either.
