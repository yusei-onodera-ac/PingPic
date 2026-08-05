import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Writes to prompt_suggestions with status "pending" — read by the
/// admin-panel's suggestion queue (admin-panel/src/lib/hooks/
/// usePendingSuggestions.ts). firestore.rules independently enforces that
/// submitterInfo.uid must match the authenticated user and status must
/// start "pending"; this repository just needs to satisfy that shape,
/// which the rule is the real source of truth for either way.
abstract class SuggestionRepository {
  Future<void> submitSuggestion(String suggestionText);
}

class SuggestionRepositoryImpl implements SuggestionRepository {
  SuggestionRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<void> submitSuggestion(String suggestionText) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('submitSuggestion: no authenticated user');
    }
    final text = suggestionText.trim();
    if (text.isEmpty) {
      throw ArgumentError('submitSuggestion: suggestionText must not be empty');
    }

    // Matches PromptSuggestion in packages/shared-types/src/index.ts
    // field-for-field (camelCase, nested submitterInfo) — see
    // docs/DATA_MODEL.md.
    await _firestore.collection('prompt_suggestions').add({
      'suggestionText': text,
      'submitterInfo': {
        'uid': user.uid,
        'displayName': user.displayName ?? user.email ?? '匿名ユーザー',
      },
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
