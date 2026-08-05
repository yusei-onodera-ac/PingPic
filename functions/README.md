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
│   └── groups.ts                  # createGroup / joinGroupByInviteCode — implemented
├── services/
│   ├── scheduleService.ts         # implemented
│   ├── promptPoolService.ts       # implemented
│   └── notificationService.ts     # implemented (Cloud Tasks scheduling)
└── utils/timeSlot.ts              # implemented (pickValidSendTime algorithm + tests)
```

`callable/groups.ts` is the invite-code based group create/join flow — a design decision made
when implementing it (the design doc never specified one), documented in
[docs/DATA_MODEL.md](../docs/DATA_MODEL.md) and `packages/shared-types/src/index.ts`'s `Group`
doc comment. It's the reason `firestore.rules`' `posts` create/read rules could finally get a
real `isGroupMember()` check instead of a placeholder TODO.

`dailyBatchJob` and its dependencies (`pickValidSendTime`, `promptPoolService`,
`scheduleService`, `notificationService`, `sendScheduledPrompt`) are real logic, not stubs — see
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "Cost design" for the global-topic + Cloud Tasks
approach, and [docs/SETUP.md](../docs/SETUP.md) for the one-time Cloud Tasks queue/IAM setup this
needs before it'll actually deliver a push. `npm test` covers `pickValidSendTime`'s scheduling
algorithm with property-style checks (window bounds, gap enforcement, exhaustion).

Still genuinely out of scope for this pass: the mobile app's camera/UI, WidgetKit, and the
admin-panel's calendar edit UX — see the repo-root README's stub/real split.
