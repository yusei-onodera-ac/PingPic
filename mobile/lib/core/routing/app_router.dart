import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/suggestions/presentation/suggestion_form_screen.dart';
import '../../features/public_feed/presentation/post_detail_screen.dart';
import '../../features/connections/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/incoming_requests_screen.dart';
import '../../features/settings/presentation/connections_list_screen.dart';
import '../di/providers.dart';
import '../widgets/home_shell.dart';

/// Route names/paths. The `/camera` route is the deep-link target for both
/// notification taps and home-screen-widget taps — see
/// push_notification_service.dart and docs/IOS_WIDGET_SETUP.md.
abstract class AppRoutes {
  static const login = '/login';
  /// HomeShell — the two-tab (フォロー中/みんな) bottom-nav shell.
  static const feed = '/';
  static const camera = '/camera';
  static const suggest = '/suggest';
  static const publicPostDetail = '/public-post';
  static const profile = '/profile';
  static const settings = '/settings';
  static const incomingRequests = '/settings/requests';
  static const connectionsList = '/settings/connections';
}

/// Bridges a Stream (authRepository.authStateChanges()) to the Listenable
/// go_router's `refreshListenable` expects, so the router re-evaluates its
/// `redirect` callback whenever sign-in state changes — the standard
/// go_router + stream-based-auth pattern.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.feed,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges()),
    redirect: (context, state) {
      final signedIn = authRepository.currentUserId != null;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      if (!signedIn && !goingToLogin) return AppRoutes.login;
      if (signedIn && goingToLogin) return AppRoutes.feed;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.feed,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) {
          final slotParam = state.uri.queryParameters['slot'];
          return CameraScreen(slotNumber: slotParam != null ? int.tryParse(slotParam) : null);
        },
      ),
      GoRoute(
        path: AppRoutes.suggest,
        builder: (context, state) => const SuggestionFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.publicPostDetail}/:postId',
        builder: (context, state) =>
            PostDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '${AppRoutes.profile}/:uid',
        builder: (context, state) => ProfileScreen(
          uid: state.pathParameters['uid']!,
          displayName: state.uri.queryParameters['name'] ?? '匿名ユーザー',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.incomingRequests,
        builder: (context, state) => const IncomingRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.connectionsList,
        builder: (context, state) => const ConnectionsListScreen(),
      ),
    ],
  );
});
