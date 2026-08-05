# @pingpic/functions

Cloud Functions for PingPic. See [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) and
[docs/SETUP.md](../docs/SETUP.md) at the repo root for the full picture — this file just covers
local commands.

```bash
npm install
npm run build         # compile TS -> lib/
npm run type-check    # tsc --noEmit
npm run lint
npm run test          # vitest
npm run serve         # build + start the Functions emulator only
```

From the repo root, `firebase emulators:start --only firestore,functions,auth,storage` runs this
alongside Firestore/Auth/Storage, which is what `dailyBatchJob` actually needs to do anything
useful (it reads/writes Firestore).

## Structure

```
src/
├── index.ts                       # exported functions
├── config/{firebaseAdmin,params}.ts   # Admin SDK singleton, deploy-env params
├── scheduled/
│   ├── dailyBatchJob.ts           # 00:00 cron — implemented
│   └── sendScheduledPrompt.ts     # HTTPS, invoked by Cloud Tasks — implemented
├── callable/
│   └── connections.ts              # respondToFriendRequest — implemented
├── triggers/
│   └── likes.ts                   # onLikeCreated / onLikeDeleted — maintains Post.likeCount
├── services/
│   ├── scheduleService.ts         # implemented
│   ├── promptPoolService.ts       # implemented
│   └── notificationService.ts     # implemented (Cloud Tasks scheduling)
└── utils/timeSlot.ts              # implemented (pickValidSendTime algorithm + tests)
```

`triggers/likes.ts` reacts to `posts/{postId}/likes/{uid}` create/delete and updates
`Post.likeCount` via the Admin SDK — see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "Cost
design" for why this is a trigger rather than a client-writable counter field (now that posts can
be public, "who can increment likeCount" is a much bigger trust boundary than group-only ever was).

`callable/connections.ts` handles ACCEPTING a friend request — the only step in PingPic's
request/accept mutual-connection model (see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)
"Resolved: groups → mutual connections") that needs server-side arbitration, since it atomically
creates a `connections` doc and deletes the request. Sending/cancelling a request and unfriending
are plain client writes instead — see `firestore.rules`.

`dailyBatchJob` and its dependencies (`pickValidSendTime`, `promptPoolService`,
`scheduleService`, `notificationService`, `sendScheduledPrompt`) are real logic, not stubs — see
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "Cost design" for the global-topic + Cloud Tasks
approach, and [docs/SETUP.md](../docs/SETUP.md) for the one-time Cloud Tasks queue/IAM setup this
needs before it'll actually deliver a push. `npm test` covers `pickValidSendTime`'s scheduling
algorithm with property-style checks (window bounds, gap enforcement, exhaustion).

Still genuinely out of scope for this pass: the mobile app's camera/UI, WidgetKit, and the
admin-panel's calendar edit UX — see the repo-root README's stub/real split.
