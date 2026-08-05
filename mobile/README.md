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
├── main.dart, app.dart, firebase_options.dart (placeholder)
├── core/{theme, routing/app_router.dart, di/providers.dart}
├── features/
│   ├── camera/          # in-app-only capture — STUB
│   ├── feed/             # STUB
│   ├── prompts/data/     # DailySchedule model, mirrors shared-types
│   ├── notifications/    # push + deep-link routing — STUB
│   ├── auth/              # STUB — auth method not decided in design doc
│   ├── suggestions/       # user-submitted prompt form — STUB
│   └── widget_bridge/     # home_widget <-> WidgetKit data bridge — STUB
└── shared/models/         # Group, Post, PromptSuggestion — mirror shared-types
```

Everything marked STUB throws `UnimplementedError` with a clear message — that's intentional for
this scaffold pass; see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "stub vs real" split.

For the iOS home screen widget (WidgetKit extension, App Group setup), see
[docs/IOS_WIDGET_SETUP.md](../docs/IOS_WIDGET_SETUP.md) — it's a manual Xcode step performed
after `flutter create .`, using the pre-written Swift files in `ios-overrides/PingPicWidget/`.
