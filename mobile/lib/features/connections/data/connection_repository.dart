import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A mutual connection, as listed for the following feed / settings — a
/// uid + the display name captured on the `connections` doc at accept
/// time (see Connection.displayNames' doc comment in shared-types for
/// why this is denormalized instead of looked up from a user-profile
/// collection that doesn't exist).
class ConnectionUser {
  const ConnectionUser({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}

class IncomingRequest {
  const IncomingRequest({
    required this.requestId,
    required this.fromUid,
    required this.fromDisplayName,
  });

  final String requestId;
  final String fromUid;
  final String fromDisplayName;
}

/// friend_requests (doc id `{fromUid}_{toUid}`, deterministic — one
/// pending request per direction per pair) and connections (doc id is
/// the two uids sorted, see shared-types' connectionId()). See the
/// design note on FriendRequest/Connection in
/// packages/shared-types/src/index.ts for the full rationale — request
/// creation/cancellation are plain client writes, but ACCEPTING a
/// request goes through the respondToFriendRequest Cloud Function (needs
/// to atomically create the connection + delete the request).
abstract class ConnectionRepository {
  Stream<bool> watchIsConnected(String otherUid);

  /// Do I have a pending outgoing request to [otherUid]?
  Stream<bool> watchOutgoingRequestPending(String otherUid);

  /// Has [otherUid] sent ME a pending request? Non-null means yes, with
  /// enough info to respond to it.
  Stream<IncomingRequest?> watchIncomingRequestFrom(String otherUid);

  /// All pending incoming requests — SettingsScreen's request inbox.
  Stream<List<IncomingRequest>> watchIncomingRequests();

  /// [myDisplayName] is denormalized onto the request as `fromDisplayName`
  /// — pass the signed-in user's own best-known display name (same
  /// `displayName ?? email ?? '匿名ユーザー'` fallback used elsewhere).
  Future<void> sendRequest(String toUid, String myDisplayName);
  Future<void> cancelRequest(String toUid);
  Future<void> respond({required String requestId, required bool accept});

  /// Everyone the signed-in user is connected to — what the following
  /// feed builds its per-user pages from, and what SettingsScreen lists
  /// for management (unfriend).
  Stream<List<ConnectionUser>> watchConnections();
  Future<void> removeConnection(String otherUid);
}

class ConnectionRepositoryImpl implements ConnectionRepository {
  ConnectionRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String? get _myUid => _auth.currentUser?.uid;

  String _connectionId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  @override
  Stream<bool> watchIsConnected(String otherUid) {
    final myUid = _myUid;
    if (myUid == null) return Stream.value(false);
    return _firestore
        .collection('connections')
        .doc(_connectionId(myUid, otherUid))
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Stream<bool> watchOutgoingRequestPending(String otherUid) {
    final myUid = _myUid;
    if (myUid == null) return Stream.value(false);
    return _firestore
        .collection('friend_requests')
        .doc('${myUid}_$otherUid')
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Stream<IncomingRequest?> watchIncomingRequestFrom(String otherUid) {
    final myUid = _myUid;
    if (myUid == null) return Stream.value(null);
    return _firestore
        .collection('friend_requests')
        .doc('${otherUid}_$myUid')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data()!;
      return IncomingRequest(
        requestId: snap.id,
        fromUid: data['fromUid'] as String,
        fromDisplayName: data['fromDisplayName'] as String? ?? '匿名ユーザー',
      );
    });
  }

  @override
  Stream<List<IncomingRequest>> watchIncomingRequests() {
    final myUid = _myUid;
    if (myUid == null) return Stream.value(const []);
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => IncomingRequest(
                  requestId: d.id,
                  fromUid: d.data()['fromUid'] as String,
                  fromDisplayName: d.data()['fromDisplayName'] as String? ?? '匿名ユーザー',
                ))
            .toList(growable: false));
  }

  @override
  Future<void> sendRequest(String toUid, String myDisplayName) async {
    final myUid = _myUid;
    if (myUid == null) throw StateError('sendRequest: no authenticated user');
    if (myUid == toUid) throw ArgumentError('sendRequest: cannot request yourself');

    await _firestore.collection('friend_requests').doc('${myUid}_$toUid').set({
      'fromUid': myUid,
      'toUid': toUid,
      'fromDisplayName': myDisplayName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cancelRequest(String toUid) async {
    final myUid = _myUid;
    if (myUid == null) throw StateError('cancelRequest: no authenticated user');
    await _firestore.collection('friend_requests').doc('${myUid}_$toUid').delete();
  }

  @override
  Future<void> respond({required String requestId, required bool accept}) async {
    final myDisplayName = _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? '匿名ユーザー';
    await _functions.httpsCallable('respondToFriendRequest').call({
      'requestId': requestId,
      'accept': accept,
      'myDisplayName': myDisplayName,
    });
  }

  @override
  Stream<List<ConnectionUser>> watchConnections() {
    final myUid = _myUid;
    if (myUid == null) return Stream.value(const []);
    return _firestore
        .collection('connections')
        .where('uids', arrayContains: myUid)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final uids = List<String>.from(data['uids'] as List);
              final otherUid = uids.firstWhere((u) => u != myUid, orElse: () => myUid);
              final displayNames = Map<String, dynamic>.from(data['displayNames'] as Map);
              return ConnectionUser(
                uid: otherUid,
                displayName: displayNames[otherUid] as String? ?? '匿名ユーザー',
              );
            }).toList(growable: false));
  }

  @override
  Future<void> removeConnection(String otherUid) async {
    final myUid = _myUid;
    if (myUid == null) throw StateError('removeConnection: no authenticated user');
    await _firestore.collection('connections').doc(_connectionId(myUid, otherUid)).delete();
  }
}
