import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/connection_repository.dart';

/// 4-state 友達 button — none (send request) / outgoing pending (cancel) /
/// incoming pending (accept) / connected (remove). Nests 3 StreamBuilders
/// (connected -> outgoing -> incoming) rather than combining them into
/// one stream — avoids pulling in a stream-combining dependency
/// (rxdart's CombineLatest) for what's only ever 3 single-document
/// listeners. Used on PostCard, ProfileScreen, and nowhere else.
class ConnectionButton extends ConsumerStatefulWidget {
  const ConnectionButton({
    super.key,
    required this.targetUid,
    required this.targetDisplayName,
    this.compact = false,
  });

  final String targetUid;
  final String targetDisplayName;

  /// Smaller footprint for inline use on PostCard's header row; the
  /// default (larger) size suits ProfileScreen's header.
  final bool compact;

  @override
  ConsumerState<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends ConsumerState<ConnectionButton> {
  bool _busy = false;

  /// AuthRepository only exposes the uid, not the display name — read
  /// straight from FirebaseAuth here rather than widening
  /// AuthRepository's interface for this one call site. Same fallback
  /// convention used everywhere else in the app.
  String get _myDisplayName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email ?? '匿名ユーザー';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(connectionRepositoryProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUserId;
    if (myUid == null || myUid == widget.targetUid) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: repo.watchIsConnected(widget.targetUid),
      builder: (context, connectedSnap) {
        if (connectedSnap.data == true) {
          return _button(
            label: '友達',
            outlined: true,
            onPressed: () async {
              final confirmed = await _confirmRemove(context);
              if (confirmed != true) return;
              setState(() => _busy = true);
              try {
                await repo.removeConnection(widget.targetUid);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          );
        }

        return StreamBuilder<bool>(
          stream: repo.watchOutgoingRequestPending(widget.targetUid),
          builder: (context, outgoingSnap) {
            if (outgoingSnap.data == true) {
              return _button(
                label: 'リクエスト済み',
                outlined: true,
                onPressed: () async {
                  setState(() => _busy = true);
                  try {
                    await repo.cancelRequest(widget.targetUid);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              );
            }

            return StreamBuilder<IncomingRequest?>(
              stream: repo.watchIncomingRequestFrom(widget.targetUid),
              builder: (context, incomingSnap) {
                final incoming = incomingSnap.data;
                if (incoming != null) {
                  return _button(
                    label: '承認する',
                    outlined: false,
                    onPressed: () async {
                      setState(() => _busy = true);
                      try {
                        await repo.respond(requestId: incoming.requestId, accept: true);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
                  );
                }

                return _button(
                  label: '友達になる',
                  outlined: false,
                  onPressed: () async {
                    setState(() => _busy = true);
                    try {
                      await repo.sendRequest(widget.targetUid, _myDisplayName);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmRemove(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('友達を解除しますか？'),
        content: Text('${widget.targetDisplayName}さんとの友達関係を解除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('解除する')),
        ],
      ),
    );
  }

  Widget _button({required String label, required bool outlined, required VoidCallback onPressed}) {
    final child = Text(label, style: widget.compact ? const TextStyle(fontSize: 12) : null);
    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    final button = outlined
        ? OutlinedButton(
            onPressed: _busy ? null : onPressed,
            style: OutlinedButton.styleFrom(padding: padding),
            child: child,
          )
        : FilledButton(
            onPressed: _busy ? null : onPressed,
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral, padding: padding),
            child: child,
          );
    return widget.compact ? SizedBox(height: 30, child: button) : button;
  }
}
