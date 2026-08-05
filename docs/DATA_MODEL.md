# PingPic — Firestore Data Model

Source of truth for these shapes (TypeScript) is `packages/shared-types/src/index.ts`. Field
names are **camelCase** throughout (`userId`, not `user_id`) — this must match exactly in
`firestore.rules`/`storage.rules` and in the hand-mirrored Dart models under
`mobile/lib/**/data/*_model.dart` (see the duplication note in
[ARCHITECTURE.md](./ARCHITECTURE.md)); a naming mismatch there silently breaks rules (the field
reads as `null` and every equality check fails closed) rather than throwing a visible error.

## `daily_schedules/{date}`

Doc id: `YYYY-MM-DD`.

| field | type                                | notes                          |
|-------|--------------------------------------|----------------------------------|
| slots | `ScheduleSlot[3]` (fixed length 3)   | slot 1/2/3 in send-time order    |

`ScheduleSlot`:

| field       | type                                                                 | notes |
|-------------|------------------------------------------------------------------------|-------|
| sendTime    | Firestore `Timestamp`                                                   | within 07:00–22:00, ≥4h apart across the day's 3 slots |
| promptText  | `string`                                                                | |
| credit      | `{ type: "admin" }` \| `{ type: "user"; uid: string; displayName: string }` | shown as "○○さん考案" / "運営考案" |

## `groups/{groupId}` — ⚠️ inferred, not in the original design doc

| field     | type       | notes |
|-----------|------------|-------|
| name      | `string`   | |
| memberIds | `string[]` | Firebase Auth uids |

**TODO: unconfirmed** — no group creation/invite/join flow is defined anywhere in the design
doc. This is the minimal shape needed for `posts.groupId` and Firestore/Storage rules to
type-check and compile against. Revisit once the actual group-management UX is designed.

## `posts/{postId}`

| field      | type                     | notes |
|------------|--------------------------|-------|
| groupId    | `string`                 | → `groups/{groupId}` |
| userId     | `string`                 | Firebase Auth uid |
| date       | `string` (`YYYY-MM-DD`)  | |
| slotNumber | `1 \| 2 \| 3`            | |
| photoUrl   | `string`                 | Storage download URL, `posts/{uid}/...` |
| postedAt   | Firestore `Timestamp`    | |

No edit/delete-by-owner path — the spec has no photo-editing feature, so `posts` are
effectively append-only from the client's perspective (rules only allow admin update/delete).

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

None pre-declared (`firestore.indexes.json` starts empty). Add them once real queries land —
the most likely first one is `posts` filtered by `groupId` + `date`, ordered by `slotNumber`.
