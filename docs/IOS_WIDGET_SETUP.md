# iOS Home Screen Widget (WidgetKit) — Manual Setup

WidgetKit extensions are a second Xcode **target**, not something `flutter create` or any script
can safely generate — hand-editing `project.pbxproj` to add a target is fragile and easy to
corrupt. This is a one-time manual checklist to run **after** `flutter create .` has generated
`mobile/ios/`.

## Why this can't be scaffolded automatically

`flutter create` produces a single `Runner` target inside `mobile/ios/Runner.xcworkspace`. Adding
a Widget Extension target requires Xcode's project-file writer (via its GUI or `xcodebuild`
project-generation tooling), which correctly updates `project.pbxproj`'s target graph,
build phases, and scheme — something not safe to author by hand outside Xcode.

## Steps

1. Run `flutter create --org com.pingpic --project-name pingpic .` inside `mobile/` first (see
   [SETUP.md](./SETUP.md)) if you haven't already.
2. Open `mobile/ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`).
3. **File → New → Target… → Widget Extension.** Name it `PingPicWidget`. Uncheck "Include
   Configuration Intent" (static timeline is enough for v1).
4. This scaffolds `mobile/ios/PingPicWidget/{PingPicWidget.swift, PingPicWidgetBundle.swift,
   Info.plist}` from Xcode's template. **Replace them** with the pre-written stubs in
   `mobile/ios-overrides/PingPicWidget/` in this repo (they already assume the App Group +
   shared-container data shape `home_widget` writes) — copy over `PingPicWidget.swift` and
   `PingPicWidgetBundle.swift`.
5. **Enable App Groups** capability on **both** the `Runner` and `PingPicWidget` targets
   (Signing & Capabilities tab → + Capability → App Groups). Create/select the group id
   `group.com.pingpic.app` in both. This must also be registered under your team in the
   [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list/applicationGroup).
6. Copy `mobile/ios-overrides/Runner.entitlements` content into (or merge with) the
   auto-generated `mobile/ios/Runner/Runner.entitlements` so the App Group id is present there
   too.
7. Merge the additions from `mobile/ios-overrides/Info.plist.additions.md` into
   `mobile/ios/Runner/Info.plist` — specifically `NSCameraUsageDescription`. **Do not** add
   `NSPhotoLibraryUsageDescription` — its absence is what makes it impossible for the app to even
   prompt for gallery access, enforcing the in-app-camera-only requirement at the OS permission
   layer.
8. In Dart, `mobile/lib/features/widget_bridge/home_widget_service.dart` writes the current
   prompt + group post status into the shared container via the `home_widget` package
   (`HomeWidget.saveWidgetData` + `HomeWidget.updateWidget`), using the same App Group id.
9. Build & run once from Xcode to confirm the widget target compiles and can be added to the iOS
   Simulator's home screen (long-press home screen → + → search "PingPic").

## What's still a TODO after this checklist

- The actual SwiftUI view inside `PingPicWidget.swift` (currently a placeholder `Text`) — real
  layout showing the current prompt + blurred/unblurred group post thumbnails.
- Calling `WidgetCenter.shared.reloadTimelines(ofKind:)` from the Flutter side at the right
  moments (after a new prompt notification arrives, after the user posts).
- Deep link from tapping the widget back into the app (`widgetURL` / `Link` in SwiftUI →
  `go_router` deep link handling in `mobile/lib/core/routing/app_router.dart`).
