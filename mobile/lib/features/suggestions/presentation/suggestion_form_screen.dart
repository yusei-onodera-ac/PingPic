import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';

/// Simple text-input form submitting to SuggestionRepository. Per the
/// design doc, when a user-submitted prompt is later used (via the
/// admin-panel's adopt flow) it's credited "○○さん考案" — no further UI
/// is implied here beyond submission itself.
class SuggestionFormScreen extends ConsumerStatefulWidget {
  const SuggestionFormScreen({super.key});

  @override
  ConsumerState<SuggestionFormScreen> createState() => _SuggestionFormScreenState();
}

class _SuggestionFormScreenState extends ConsumerState<SuggestionFormScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'お題を入力してください');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(suggestionRepositoryProvider).submitSuggestion(_controller.text);
      setState(() {
        _submitted = true;
        _controller.clear();
      });
    } catch (e) {
      setState(() => _error = '送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お題を提案する')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'お題のアイデア'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_submitted) const Text('提案を送信しました。運営の審査をお待ちください。'),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '送信中…' : '送信する'),
            ),
          ],
        ),
      ),
    );
  }
}
