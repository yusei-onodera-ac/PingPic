import 'package:home_widget/home_widget.dart';

/// Must match the App Group id configured on both the Runner and
/// PingPicWidget Xcode targets — see docs/IOS_WIDGET_SETUP.md.
const _appGroupId = 'group.com.pingpic.app';

/// Must match `PingPicWidget`'s `kind` in
/// mobile/ios-overrides/PingPicWidget/PingPicWidget.swift.
const _iosWidgetName = 'PingPicWidget';

/// Writes the current prompt + this device's group post status into the
/// shared App Group container that the native WidgetKit extension reads
/// from (mobile/ios-overrides/PingPicWidget/PingPicWidget.swift), then
/// asks WidgetKit to reload. Key names ("promptText", "hasPostedToday")
/// must stay in sync with that Swift file's UserDefaults reads.
///
/// Wired from: PushNotificationService's foreground/tap handlers (new
/// prompt arrives -> updateWidgetData) and
/// CaptureController.confirmAndUpload's success path (-> markPostedToday).
///
/// Fully-terminated delivery is covered too, but NOT through this class —
/// `firebaseMessagingBackgroundHandler` in push_notification_service.dart
/// (registered in main.dart via `FirebaseMessaging.onBackgroundMessage`)
/// runs in its own isolate with no access to this class's instance state,
/// so it talks to the `home_widget` package directly instead. Keep that
/// function's App Group id / widget name / key names in sync with the
/// constants at the top of this file if either changes.
abstract class HomeWidgetService {
  Future<void> updateWidgetData({
    required String promptText,
    required bool hasPostedToday,
  });

  /// Convenience for call sites (CaptureController) that know the user
  /// just posted but not the current prompt text — reads whatever was
  /// last saved and re-saves it with hasPostedToday flipped to true,
  /// rather than requiring every caller to plumb promptText through.
  Future<void> markPostedToday();
}

class HomeWidgetServiceImpl implements HomeWidgetService {
  bool _groupIdSet = false;

  Future<void> _ensureAppGroupId() async {
    if (_groupIdSet) return;
    await HomeWidget.setAppGroupId(_appGroupId);
    _groupIdSet = true;
  }

  @override
  Future<void> updateWidgetData({
    required String promptText,
    required bool hasPostedToday,
  }) async {
    await _ensureAppGroupId();
    await HomeWidget.saveWidgetData<String>('promptText', promptText);
    await HomeWidget.saveWidgetData<bool>('hasPostedToday', hasPostedToday);
    await HomeWidget.updateWidget(iOSName: _iosWidgetName);
  }

  @override
  Future<void> markPostedToday() async {
    await _ensureAppGroupId();
    final promptText = await HomeWidget.getWidgetData<String>('promptText') ?? '';
    await updateWidgetData(promptText: promptText, hasPostedToday: true);
  }
}
