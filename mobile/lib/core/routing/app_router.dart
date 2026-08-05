import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/suggestions/presentation/suggestion_form_screen.dart';
import '../../features/groups/presentation/group_setup_screen.dart';
import '../di/providers.dart';

/// Route names/paths. The `/camera` route is the deep-link target for both
/// notification taps and home-screen-widget taps — see
/// push_notification_service.dart and docs/IOS_WIDGET_SETUP.md.
abstract class AppRoutes {
  static const login = '/login';
  static const feed = '/';
  static const camera = '/camera';
  static const suggest = '/suggest';
  static const groupSetup = '/group-setup';
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
    // Only auth state gates routes here — group membership deliberately
    // does NOT (that would need an async Firestore read inside redirect,
    // which is possible with go_router but adds real complexity for a
    // single soft gate). Instead FeedScreen itself shows a "join a group"
    // prompt when GroupRepository.watchMyGroup() is null, linking to
    // AppRoutes.groupSetup.
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
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupSetup,
        builder: (context, state) => const GroupSetupScreen(),
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
    ],
  );
});
