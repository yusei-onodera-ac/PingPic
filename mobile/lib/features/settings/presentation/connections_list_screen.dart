import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../connections/data/connection_repository.dart';

/// Everyone the signed-in user is connected to, with an unfriend action
/// per row — the management counterpart to the following feed, which
/// just shows their posts.
class ConnectionsListScreen extends ConsumerStatefulWidget {
  const ConnectionsListScreen({super.key});

  @override
  ConsumerState<ConnectionsListScreen> createState() => _ConnectionsListScreenState();
}

class _ConnectionsListScreenState extends ConsumerState<ConnectionsListScreen> {
  final _busyUids = <String>{};

  Future<void> _remove(ConnectionUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('友達を解除しますか？'),
        content: Text('${user.displayName}さんとの友達関係を解除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('解除する')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUids.add(user.uid));
    try {
      await ref.read(connectionRepositoryProvider).removeConnection(user.uid);
    } finally {
      if (mounted) setState(() => _busyUids.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(connectionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('友達一覧')),
      body: StreamBuilder<List<ConnectionUser>>(
        stream: repo.watchConnections(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final connections = snap.data ?? const <ConnectionUser>[];
          if (connections.isEmpty) {
            return const EmptyState(icon: Icons.people_outline, message: 'まだ友達がいません');
          }
          return ListView.separated(
            itemCount: connections.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = connections[index];
              final busy = _busyUids.contains(user.uid);
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user.displayName.isNotEmpty ? user.displayName.substring(0, 1) : '?'),
                ),
                title: Text(user.displayName),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _remove(user),
                        child: const Text('解除'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
