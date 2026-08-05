import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class PingPicApp extends ConsumerStatefulWidget {
  const PingPicApp({super.key});

  @override
  ConsumerState<PingPicApp> createState() => _PingPicAppState();
}

class _PingPicAppState extends ConsumerState<PingPicApp> {
  bool _pushInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // One-time push notification init once we have a live router to hand
    // it (needed for notification-tap deep-linking) — guarded so
    // rebuilds (e.g. from auth state changes refreshing the router) don't
    // re-subscribe repeatedly. Real initialize() also requests
    // permission + subscribes to the daily_prompts topic; TODO: move this
    // to fire specifically on sign-in rather than app start, once
    // sign-out should also unsubscribe (see PushNotificationService).
    if (!_pushInitialized) {
      _pushInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pushNotificationServiceProvider).initialize(router);
      });
    }

    return MaterialApp.router(
      title: 'PingPic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
