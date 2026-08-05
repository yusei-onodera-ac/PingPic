# PingPic — Flutter app (mobile/)

iOS-first. See [docs/SETUP.md](../docs/SETUP.md) at the repo root for the full bootstrap flow —
this directory currently contains **only** `lib/`, `pubspec.yaml`, `analysis_options.yaml`, and
`test/`. The `ios/`/`android/` platform folders are intentionally not checked in yet; they must
be generated locally with `flutter create .` (see SETUP.md §5) since hand-authoring Xcode/Gradle
project files is unsafe.

```bash
flutter create --org com.pingpic --project-name pingpic .   # generates ios/, android/ in place
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # generates *.freezed.dart / *.g.dart
dart pub global activate flutterfire_cli && flutterfire configure  # real firebase_options.dart
flutter analyze
flutter test
flutter run -d <ios-simulator-id>
```

## Structure (feature-first)

```
lib/
├── main.dart, app.dart, firebase_options.dart (placeholder — needs `flutterfire configure`)
├── core/{theme, routing/app_router.dart (real auth-based redirect), di/providers.dart}
├── features/
│   ├── camera/          # in-app-only capture — real (camera package + Storage/Firestore upload)
│   ├── feed/             # real group feed — posts hidden per-slot until you post your own
│   ├── prompts/data/     # DailySchedule model, mirrors shared-types
│   ├── notifications/    # real (firebase_messaging + local notifications + tap deep-link)
│   ├── auth/              # real, email/password (method itself is an open product decision)
│   ├── suggestions/       # real (writes prompt_suggestions)
│   ├── groups/             # real (invite-code create/join via Cloud Functions callables)
│   └── widget_bridge/     # real (home_widget <-> WidgetKit data bridge)
└── shared/models/         # Group, Post, PromptSuggestion — mirror shared-types
```

Still genuinely stubbed/TODO despite the above being "real":
- `FirebaseMessaging.onBackgroundMessage` — the widget only updates while the app process is
  alive (foreground, or backgrounded-but-not-killed); a prompt arriving while fully terminated
  won't reach the widget until the app is next opened. See
  `features/widget_bridge/home_widget_service.dart`'s TODO.
- The native WidgetKit SwiftUI view itself and its Xcode target (manual step, see
  [docs/IOS_WIDGET_SETUP.md](../docs/IOS_WIDGET_SETUP.md))
- "Leave group" / belonging to more than one group (MVP is intentionally one group per user)
- Image compression parameters (1600px / quality 80 in `CaptureController.capture`) are a
  starting guess, not tuned against real device photos

For the iOS home screen widget (WidgetKit extension, App Group setup), see
[docs/IOS_WIDGET_SETUP.md](../docs/IOS_WIDGET_SETUP.md) — it's a manual Xcode step performed
after `flutter create .`, using the pre-written Swift files in `ios-overrides/PingPicWidget/`.
