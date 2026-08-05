import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';

/// Shown to a signed-in user who isn't in a group yet (FeedScreen routes
/// here rather than a hard router redirect — see app_router.dart's
/// comment on why group membership isn't part of the redirect logic).
/// Offers both halves of the invite-code flow: create a new group, or
/// join an existing one by code.
class GroupSetupScreen extends ConsumerStatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  ConsumerState<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends ConsumerState<GroupSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _createdInviteCode;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'グループ名を入力してください');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final group = await ref.read(groupRepositoryProvider).createGroup(_nameController.text);
      // Show the invite code before leaving — this is the only place the
      // creator can easily read it back out to share with friends.
      setState(() => _createdInviteCode = group.inviteCode);
    } catch (e) {
      setState(() => _error = '作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = '招待コードを入力してください');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(groupRepositoryProvider).joinGroupByInviteCode(_codeController.text);
      if (mounted) context.go(AppRoutes.feed);
    } catch (e) {
      setState(() => _error = '参加に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdInviteCode != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('グループを作成しました')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('この招待コードを友達に共有してください:'),
              const SizedBox(height: 12),
              Text(
                _createdInviteCode!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.feed),
                child: const Text('はじめる'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('グループに参加')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('新しいグループを作る', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'グループ名'),
            ),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: const Text('作成する'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text('招待コードで参加する', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '招待コード'),
            ),
            FilledButton.tonal(
              onPressed: _busy ? null : _join,
              child: const Text('参加する'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
