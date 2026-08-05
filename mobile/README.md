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
├── core/
│   ├── theme/            # AppColors, AppTextStyles, AppTheme — see docs/ARCHITECTURE.md
│   │                       "UI design system" for the design rationale
│   ├── widgets/           # CountdownText, EmptyState, StatusPill, PulsingPlaceholder,
│   │                       HomeShell (bottom-nav shell: フォロー中 / みんな)
│   ├── routing/app_router.dart  # real auth-based redirect
│   └── di/providers.dart
├── features/
│   ├── camera/           # in-app-only capture — real (camera package + Storage/Firestore upload),
│   │                       plus a per-photo public/private + caption choice at capture time
│   ├── feed/              # "フォロー中" — TikTok-style following feed (see below)
│   ├── connections/       # request/accept mutual connections + ConnectionButton + ProfileScreen
│   ├── public_feed/       # "みんなの投稿": public posts, likes, comments (Instagram-card style)
│   ├── settings/          # settings screen, notification toggle, requests inbox, connections list
│   ├── prompts/data/      # DailySchedule model, mirrors shared-types
│   ├── notifications/     # real (firebase_messaging + local notifications + tap deep-link)
│   ├── auth/               # real, email/password (method itself is an open product decision)
│   ├── suggestions/        # real (writes prompt_suggestions)
│   └── widget_bridge/      # real (home_widget <-> WidgetKit data bridge)
└── shared/models/          # Post, Comment, PromptSuggestion — mirror shared-types
```

### フォロー中 — the following feed

A TikTok-style full-screen vertical `PageView`, one page per mutual connection; swipe up/down
between people, swipe left/right within a page to move between that person's 3 daily slots
(Instagram-carousel style). A slot nobody's posted to yet shows `PulsingPlaceholder` instead of a
photo. See [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "Resolved: TikTok-style following
feed".

### 友達 — request/accept mutual connections (not a one-directional follow)

This went through two earlier shapes (group membership, then a plain follow graph) before landing
on request + accept — see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) "Resolved: groups →
mutual connections" for the full history and rationale. `ConnectionButton` handles all 4 states
(none / requested / incoming / connected); reachable from PostCard and ProfileScreen.

Still genuinely stubbed/TODO despite the above being "real":
- The native WidgetKit SwiftUI view itself and its Xcode target (manual step, see
  [docs/IOS_WIDGET_SETUP.md](../docs/IOS_WIDGET_SETUP.md))
- Image compression parameters (1600px / quality 80 in `CaptureController.capture`) are a
  starting guess, not tuned against real device photos
- Public feed pagination — `watchPublicPosts` caps at 50 posts, no infinite scroll yet
- Following feed pagination — one Firestore listener per connection, no upper bound (fine at
  friend-following scale, see its doc comment in `features/feed/data/feed_repository.dart`)

For the iOS home screen widget (WidgetKit extension, App Group setup), see
[docs/IOS_WIDGET_SETUP.md](../docs/IOS_WIDGET_SETUP.md) — it's a manual Xcode step performed
after `flutter create .`, using the pre-written Swift files in `ios-overrides/PingPicWidget/`.
