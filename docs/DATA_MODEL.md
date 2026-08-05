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

## `groups/{groupId}` — ⚠️ inferred, not in the original design doc

| field      | type                    | notes |
|------------|--------------------------|-------|
| name       | `string`                 | |
| memberIds  | `string[]`               | Firebase Auth uids |
| inviteCode | `string`                 | 6-char code, see below |
| createdBy  | `string`                 | uid of the creator |
| createdAt  | Firestore `Timestamp`    | |

**Design decision (not in the original spec)**: invite-code based create/join, one group per
user for this MVP — see `functions/src/callable/groups.ts`. Mutated only through the
`createGroup` / `joinGroupByInviteCode` callables (Admin SDK), never by direct client writes, so
invite-code uniqueness can be enforced with a server-side transaction and `firestore.rules` stays
a flat "members can read, nobody writes directly" rule. Clients list their own group via
`where('memberIds', 'array-contains', uid)`.

Still open: no support for a user belonging to more than one group (there is a `leaveGroup`
callable and a matching FeedScreen UI action, just no way to be in two groups at once).

## `invite_codes/{code}` — lookup table for joining

| field   | type     | notes |
|---------|----------|-------|
| groupId | `string` | |

Doc id is the invite code itself. Never read or written by clients directly — only
`joinGroupByInviteCode` touches it, via the Admin SDK. If it were client-readable, codes could be
enumerated without going through that function's validation.

## `posts/{postId}`

| field             | type                     | notes |
|-------------------|--------------------------|-------|
| groupId           | `string`                 | → `groups/{groupId}` |
| userId            | `string`                 | Firebase Auth uid |
| authorDisplayName | `string`                 | denormalized at post time — no separate user-profile collection exists |
| date              | `string` (`YYYY-MM-DD`)  | |
| slotNumber        | `1 \| 2 \| 3`            | |
| photoUrl          | `string`                 | Storage download URL, `posts/{groupId}/{uid}/...` |
| postedAt          | Firestore `Timestamp`    | |
| promptText        | `string`                 | denormalized copy of the slot's prompt at post time |
| isPublic          | `boolean`                | chosen once at capture time, never toggled after — see below |
| caption           | `string`                 | optional one-line comment, only meaningful/shown when `isPublic` |
| likeCount         | `number`                 | maintained server-side, see below — never client-writable |

No edit/delete-by-owner path — the spec has no photo-editing feature, so `posts` are
effectively append-only from the client's perspective (rules only allow admin update/delete).

**Design decision (not in the original spec)**: at capture time, the poster can choose to make a
photo public. A public post becomes visible to any signed-in user via the "みんなの投稿" feed —
not just the poster's group — and can carry a caption, likes, and comments. This is deliberately
NOT toggleable after posting (no editing flow, consistent with the rest of the app). Private
(the default) posts behave exactly as before: group-only, no caption/like/comment UI shown.

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
- `prompt_suggestions`: `status ASC, createdAt ASC` — the admin panel's pending-suggestions queue.

`groupId + date` (two pure equality filters, used by `watchGroupPosts`) does NOT need one —
Firestore serves multi-field equality-only queries from its automatic single-field indexes.
