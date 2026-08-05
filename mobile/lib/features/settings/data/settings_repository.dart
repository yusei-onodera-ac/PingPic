import 'package:shared_preferences/shared_preferences.dart';

/// Purely local, device-side settings — nothing here touches Firestore.
/// Currently just the notification toggle; FCM has no client API to
/// query "am I subscribed to topic X", so this is the source of truth
/// for what the Switch on SettingsScreen should show, kept in sync with
/// actual subscribe/unsubscribe calls (see
/// features/notifications/data/push_notification_service.dart).
abstract class SettingsRepository {
  Future<bool> getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);
}

class SettingsRepositoryImpl implements SettingsRepository {
  static const _notificationsEnabledKey = 'notifications_enabled';

  @override
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default true — PushNotificationService.initialize() already
    // subscribes on first launch, so the toggle should read as "on"
    // until the user explicitly turns it off.
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }
}
