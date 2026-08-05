import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Wraps firebase_auth. Email/password is the default sign-in method here
/// — the design doc doesn't specify one (flagged as an open product
/// decision in docs/ARCHITECTURE.md); this mirrors what the admin-panel's
/// /login already uses, and is easy to swap out later (Sign in with
/// Apple, phone auth, etc.) without touching call sites since they only
/// depend on this abstract interface.
abstract class AuthRepository {
  Stream<String?> authStateChanges(); // emits uid or null

  String? get currentUserId;

  Future<void> signInWithEmailAndPassword(String email, String password);

  Future<void> signOut();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl([fb_auth.FirebaseAuth? auth])
      : _auth = auth ?? fb_auth.FirebaseAuth.instance;

  final fb_auth.FirebaseAuth _auth;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
