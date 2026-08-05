import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../connections/data/connection_repository.dart';

/// Pending friend requests sent TO the signed-in user — accept/reject.
/// Accepting goes through ConnectionRepository.respond (the
/// respondToFriendRequest Cloud Function, see its doc comment for why).
class IncomingRequestsScreen extends ConsumerStatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  ConsumerState<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends ConsumerState<IncomingRequestsScreen> {
  final _busyIds = <String>{};

  Future<void> _respond(IncomingRequest req, bool accept) async {
    setState(() => _busyIds.add(req.requestId));
    try {
      await ref
          .read(connectionRepositoryProvider)
          .respond(requestId: req.requestId, accept: accept);
    } finally {
      if (mounted) setState(() => _busyIds.remove(req.requestId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(connectionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('友達リクエスト')),
      body: StreamBuilder<List<IncomingRequest>>(
        stream: repo.watchIncomingRequests(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snap.data ?? const <IncomingRequest>[];
          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.mail_outline,
              message: '届いているリクエストはありません',
            );
          }
          return ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final req = requests[index];
              final busy = _busyIds.contains(req.requestId);
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    req.fromDisplayName.isNotEmpty ? req.fromDisplayName.substring(0, 1) : '?',
                  ),
                ),
                title: Text(req.fromDisplayName),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            tooltip: '承認',
                            onPressed: () => _respond(req, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined),
                            tooltip: '拒否',
                            onPressed: () => _respond(req, false),
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
