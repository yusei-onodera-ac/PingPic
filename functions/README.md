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
├── index.ts                # exported functions
├── config/firebaseAdmin.ts # Admin SDK singleton + secrets wiring point
├── scheduled/dailyBatchJob.ts
├── services/                # scheduleService, promptPoolService, notificationService — all STUBS
└── utils/timeSlot.ts        # STUB
```

Everything under `services/` and `utils/timeSlot.ts` throws `not implemented` — they exist to
pin down function signatures the scaffold's tests/dailyBatchJob shape already depend on.
