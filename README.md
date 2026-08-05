# PingPic (ピンピック)

1日3回届くお題通知に合わせて、無加工写真を撮影・グループで共有するログアプリ。

This is a **project scaffold** — buildable skeletons for three pieces plus a shared-types
package, not a finished app. Business logic (camera capture, WidgetKit view, the 00:00 batch
job's actual algorithm, calendar drag-and-drop, auth completion) is stubbed with `TODO` markers
throughout; see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full stub-vs-real split.

## Structure

| Path | What | Stack |
|------|------|-------|
| [`mobile/`](mobile/) | iOS-first app | Flutter |
| [`functions/`](functions/) | 00:00 batch job, push scheduling | Firebase Cloud Functions (TS) |
| [`admin-panel/`](admin-panel/) | Calendar-style prompt editor | Next.js |
| [`packages/shared-types/`](packages/shared-types/) | Firestore doc types shared by `functions` + `admin-panel` | TypeScript |

Firestore rules: [`firestore.rules`](firestore.rules) · [`storage.rules`](storage.rules) — see
[docs/DATA_MODEL.md](docs/DATA_MODEL.md) for the collection shapes they enforce.

## Getting started

See **[docs/SETUP.md](docs/SETUP.md)** for the full local bootstrap (all 4 sub-projects, in
dependency order). Short version:

```bash
npm install                    # root workspaces: functions, admin-panel, packages/shared-types
firebase login && firebase use --add
firebase emulators:start --only firestore,functions,auth,storage
```

Mobile app setup (Flutter isn't bundled as generated `ios/`/`android/` folders in this repo — see
[mobile/README.md](mobile/README.md) for why and how to generate them locally).

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit together, cost-design
  choices, known open gaps
- [docs/DATA_MODEL.md](docs/DATA_MODEL.md) — Firestore collection reference
- [docs/SETUP.md](docs/SETUP.md) — local dev bootstrap, in order
- [docs/IOS_WIDGET_SETUP.md](docs/IOS_WIDGET_SETUP.md) — manual WidgetKit target setup
