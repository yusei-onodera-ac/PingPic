import 'package:flutter_test/flutter_test.dart';
import 'package:pingpic/core/routing/app_router.dart';

void main() {
  // Smoke test only — proves the router config loads and route paths are
  // as expected. Does NOT pump the full app widget tree, since that
  // requires Firebase.initializeApp() to succeed (needs real config from
  // `flutterfire configure`, see main.dart / firebase_options.dart TODOs).
  test('AppRoutes paths are defined as expected', () {
    expect(AppRoutes.login, '/login');
    expect(AppRoutes.feed, '/');
    expect(AppRoutes.camera, '/camera');
    expect(AppRoutes.suggest, '/suggest');
  });
}
