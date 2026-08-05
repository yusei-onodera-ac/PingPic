# PingPic — Firestore Data Model

Source of truth for these shapes (TypeScript) is `packages/shared-types/src/index.ts`.
Flutter/Dart models under `mobile/lib/**/data/*_model.dart` are hand-mirrored copies —
see the duplication note in [ARCHITECTURE.md](./ARCHITECTURE.md).

## `daily_schedules/{date}`

Doc id: `YYYY-MM-DD`.

| field   | type                                  | notes                                    |
|---------|---------------------------------------|-------------------------------------------|
| slots   | `ScheduleSlot[3]` (fixed length 3)    | slot 1/2/3 in send-time order              |

`ScheduleSlot`:

| field        | type                              | notes |
|--------------|------------------------------------|-------|
| send_time    | Firestore `Timestamp`              | within 07:00–22:00, ≥4h apart across the day's 3 slots |
| prompt_text  | `string`                           | |
| credit_type  | `"admin"` \| `{ type: "user"; display_name: string; uid: string }` | shown as "○○さん考案" / "運営考案" |

## `groups/{groupId}` — ⚠️ inferred, not in the original design doc

| field       | type       | notes |
|-------------|------------|-------|
| name        | `string`   | |
| member_ids  | `string[]` | Firebase Auth uids |

**TODO: unconfirmed** — no group creation/invite/join flow is defined anywhere in the design
doc. This is the minimal shape needed for `posts.group_id` and Firestore/Storage rules to
type-check and compile against. Revisit once the actual group-management UX is designed.

## `posts/{postId}`

| field        | type                | notes |
|--------------|---------------------|-------|
| group_id     | `string`            | → `groups/{groupId}` |
| user_id      | `string`            | Firebase Auth uid |
| date         | `string` (`YYYY-MM-DD`) | |
| slot_number  | `1 \| 2 \| 3`       | |
| photo_url    | `string`            | Storage download URL, `posts/{uid}/...` |
| posted_at    | Firestore `Timestamp` | |

No edit/delete-by-owner path — the spec has no photo-editing feature, so `posts` are
effectively append-only from the client's perspective (rules only allow admin update/delete).

## `prompt_suggestions/{suggestionId}`

| field             | type                                          | notes |
|-------------------|-----------------------------------------------|-------|
| suggestion_text   | `string`                                       | |
| submitter_info    | `{ uid: string; display_name: string }`        | |
| status            | `"pending" \| "approved" \| "rejected"`        | admin transitions only |
| created_at        | Firestore `Timestamp`                          | |

## `prompt_pool/{entryId}` — the "popular prompt" stock

| field        | type                   | notes |
|--------------|------------------------|-------|
| prompt_text  | `string`               | |
| usage_count  | `number`                | incremented each time the batch job uses it, for admin visibility |
| created_at   | Firestore `Timestamp`  | |

Used only by `dailyBatchJob` (via Admin SDK, bypasses rules) and the admin panel's
"popular prompt pool" management screen.

## Composite indexes

None pre-declared (`firestore.indexes.json` starts empty). Add them once real queries land —
the most likely first one is `posts` filtered by `group_id` + `date`, ordered by `slot_number`.
