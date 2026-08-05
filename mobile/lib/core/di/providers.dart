import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/suggestions/data/suggestion_repository.dart';
import '../../features/notifications/data/push_notification_service.dart';
import '../../features/widget_bridge/home_widget_service.dart';
import '../../features/feed/data/feed_repository.dart';
import '../../features/groups/data/group_repository.dart';

/// Root DI wiring. Feature-local providers (e.g. cameraRepositoryProvider
/// in features/camera/application/camera_controller.dart) live next to
/// their feature instead of here — this file only holds cross-cutting
/// singletons used by more than one feature.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepositoryImpl();
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationServiceImpl(homeWidgetService: ref.watch(homeWidgetServiceProvider));
});

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetServiceImpl();
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepositoryImpl();
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl();
});
