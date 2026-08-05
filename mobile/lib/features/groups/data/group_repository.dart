import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/group_model.dart';

/// MVP simplification: one group per user (see the design note on
/// createGroup/joinGroupByInviteCode in
/// functions/src/callable/groups.ts) — there's no "my groups" list, just
/// "my group, if any".
abstract class GroupRepository {
  /// Null if the signed-in user isn't in any group yet.
  Stream<GroupModel?> watchMyGroup();

  /// One-shot fetch, for call sites (like posting a photo) that need the
  /// id right now rather than a live stream.
  Future<String?> currentGroupId();

  Future<GroupModel> createGroup(String name);

  Future<GroupModel> joinGroupByInviteCode(String inviteCode);

  Future<void> leaveGroup(String groupId);
}

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// `where('memberIds', array-contains: uid)` is the standard Firestore
  /// pattern for "list documents I'm a member of" — firestore.rules'
  /// `allow read: if request.auth.uid in resource.data.memberIds` permits
  /// this query directly (Firestore evaluates list queries against the
  /// rule per matching document).
  Query<Map<String, dynamic>>? _myGroupQuery() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('groups').where('memberIds', arrayContains: uid).limit(1);
  }

  @override
  Stream<GroupModel?> watchMyGroup() {
    final query = _myGroupQuery();
    if (query == null) return Stream.value(null);
    return query.snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return GroupModel.fromJson({...doc.data(), 'id': doc.id});
    });
  }

  @override
  Future<String?> currentGroupId() async {
    final query = _myGroupQuery();
    if (query == null) return null;
    final snap = await query.get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  @override
  Future<GroupModel> createGroup(String name) async {
    // Deliberately not typing `.call<Map<String, dynamic>>` — the plugin's
    // platform-channel codec can hand back a `Map<Object?, Object?>` at
    // runtime regardless of the generic requested, which throws a cast
    // error if asserted too strictly. `Map<String, dynamic>.from(...)`
    // normalizes it safely either way.
    final result = await _functions.httpsCallable('createGroup').call({'name': name});
    final groupId = Map<String, dynamic>.from(result.data as Map)['groupId'] as String;
    return _fetchGroup(groupId);
  }

  @override
  Future<GroupModel> joinGroupByInviteCode(String inviteCode) async {
    final result = await _functions
        .httpsCallable('joinGroupByInviteCode')
        .call({'inviteCode': inviteCode});
    final groupId = Map<String, dynamic>.from(result.data as Map)['groupId'] as String;
    return _fetchGroup(groupId);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await _functions.httpsCallable('leaveGroup').call({'groupId': groupId});
  }

  Future<GroupModel> _fetchGroup(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    final data = doc.data();
    if (data == null) {
      throw StateError('_fetchGroup: group $groupId not found after create/join');
    }
    return GroupModel.fromJson({...data, 'id': doc.id});
  }
}
