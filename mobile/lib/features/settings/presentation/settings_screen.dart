import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../connections/data/connection_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _notificationsEnabled;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepositoryProvider).getNotificationsEnabled().then((enabled) {
      if (mounted) setState(() => _notificationsEnabled = enabled);
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await ref.read(settingsRepositoryProvider).setNotificationsEnabled(enabled);
    final pushService = ref.read(pushNotificationServiceProvider);
    if (enabled) {
      await pushService.subscribeToDailyPrompts();
    } else {
      await pushService.unsubscribeFromDailyPrompts();
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サインアウトしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('サインアウト')),
        ],
      ),
    );
    if (confirmed != true) return;
    // No explicit navigation after this — app_router.dart's redirect
    // reacts to authStateChanges() and sends us to /login on its own.
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '不明';
    final connectionRepo = ref.watch(connectionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _SectionHeader('アカウント'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('メールアドレス'),
            subtitle: Text(email),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('サインアウト', style: TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
          const Divider(),
          _SectionHeader('友達'),
          StreamBuilder<List<IncomingRequest>>(
            stream: connectionRepo.watchIncomingRequests(),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('友達リクエスト'),
                trailing: count > 0
                    ? Badge(label: Text('$count'), child: const Icon(Icons.chevron_right))
                    : const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.incomingRequests),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('友達一覧'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.connectionsList),
          ),
          const Divider(),
          _SectionHeader('通知'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('お題通知'),
            subtitle: const Text('1日3回のお題通知を受け取る'),
            value: _notificationsEnabled ?? true,
            onChanged: _notificationsEnabled == null ? null : _toggleNotifications,
          ),
          const Divider(),
          _SectionHeader('その他'),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('お題を提案する'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.suggest),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            subtitle: Text(_appVersion ?? '…'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
