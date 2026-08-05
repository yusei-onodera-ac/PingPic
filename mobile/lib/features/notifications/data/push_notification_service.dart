import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/routing/app_router.dart';
import '../../../firebase_options.dart';
import '../../widget_bridge/home_widget_service.dart';

/// FCM topic every device subscribes to for daily prompt pushes — must
/// match DAILY_PROMPTS_TOPIC in
/// functions/src/services/notificationService.ts exactly. A single
/// global topic (not per-user) is the deliberate cost-minimal choice
/// described there: prompt content is identical for every user.
const _dailyPromptsTopic = 'daily_prompts';

/// Must match the constants in
/// features/widget_bridge/home_widget_service.dart — duplicated rather
/// than imported because this function runs in its own background
/// isolate (see its doc comment) and keeping it self-contained avoids
/// any temptation to reach into that class's non-static state, which
/// wouldn't exist in this isolate anyway.
const _appGroupId = 'group.com.pingpic.app';
const _iosWidgetName = 'PingPicWidget';

/// Registered via `FirebaseMessaging.onBackgroundMessage` in main.dart,
/// BEFORE runApp — this is what finally closes the gap noted in
/// HomeWidgetService's TODO: a prompt notification arriving while the
/// app is fully terminated now still updates the widget, not just
/// foreground/background-but-alive delivery.
///
/// Must be a top-level (or static) function — FCM runs it in a separate
/// background isolate with no access to any state from the main isolate
/// (including Riverpod's ProviderContainer), so it re-initializes Firebase
/// and talks to `home_widget` directly rather than going through
/// HomeWidgetServiceImpl. `@pragma('vm:entry-point')` stops Dart's
/// tree-shaker from removing it in release builds, since nothing in the
/// main isolate appears to call it directly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final promptText = message.notification?.body;
  if (promptText == null) return;

  await HomeWidget.setAppGroupId(_appGroupId);
  await HomeWidget.saveWidgetData<String>('promptText', promptText);
  await HomeWidget.saveWidgetData<bool>('hasPostedToday', false);
  await HomeWidget.updateWidget(iOSName: _iosWidgetName);
}

abstract class PushNotificationService {
  /// Requests notification permission, registers foreground/background/
  /// terminated tap handlers, and subscribes to the daily-prompt topic.
  /// Call once after sign-in (or at launch, if already signed in).
  Future<void> initialize(GoRouter router);

  Future<void> subscribeToDailyPrompts();
  Future<void> unsubscribeFromDailyPrompts();
}

class PushNotificationServiceImpl implements PushNotificationService {
  PushNotificationServiceImpl({
    required HomeWidgetService homeWidgetService,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _homeWidgetService = homeWidgetService,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  final HomeWidgetService _homeWidgetService;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  @override
  Future<void> initialize(GoRouter router) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // iOS: without this, foreground pushes are silently swallowed instead
    // of shown as a banner — required for a notification that arrives
    // while the user already has PingPic open.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) => _handleTapPayload(response.payload, router),
    );

    // Terminated -> tapped-to-launch.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _routeToSlot(initialMessage.data, router);
      _updateWidgetFromMessage(initialMessage);
    }

    // Background (app backgrounded, not terminated) -> tapped.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _routeToSlot(message.data, router);
      _updateWidgetFromMessage(message);
    });

    // Foreground -> show a local banner (FCM alone won't display a
    // system banner while the app is in the foreground) and refresh the
    // widget immediately, since there's no notification tap to hang that
    // off of in this case.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('daily_prompts', 'お題通知'),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['slotNumber'],
      );
      _updateWidgetFromMessage(message);
    });

    await subscribeToDailyPrompts();
  }

  /// Refreshes the home-screen widget with the new prompt, resetting
  /// hasPostedToday to false (it's a new slot). Covers the
  /// foreground/backgrounded-but-alive cases; `firebaseMessagingBackgroundHandler`
  /// above covers the fully-terminated case separately (different isolate,
  /// can't share this instance method).
  void _updateWidgetFromMessage(RemoteMessage message) {
    final promptText = message.notification?.body;
    if (promptText == null) return;
    _homeWidgetService.updateWidgetData(promptText: promptText, hasPostedToday: false);
  }

  void _handleTapPayload(String? payload, GoRouter router) {
    if (payload == null) return;
    router.go('${AppRoutes.camera}?slot=$payload');
  }

  void _routeToSlot(Map<String, dynamic> data, GoRouter router) {
    final slot = data['slotNumber'];
    if (slot == null) {
      router.go(AppRoutes.camera);
      return;
    }
    router.go('${AppRoutes.camera}?slot=$slot');
  }

  @override
  Future<void> subscribeToDailyPrompts() => _messaging.subscribeToTopic(_dailyPromptsTopic);

  @override
  Future<void> unsubscribeFromDailyPrompts() =>
      _messaging.unsubscribeFromTopic(_dailyPromptsTopic);
}
