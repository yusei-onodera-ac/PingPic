import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';

enum PublicFeedSort {
  /// Default — "いいねが多い投稿が積極的に優先されて表示される" per this
  /// session's requirement.
  mostLiked,
  newest,
}

/// The "みんなの投稿" feed — a flat, group-independent stream of every
/// post any user has chosen to make public, deliberately mixing posts
/// from different prompts/dates/groups together rather than grouping by
/// prompt (per this session's direction). Each PostModel already carries
/// its own denormalized `promptText`, so cards can show what prompt they
/// were answering without extra reads.
abstract class PublicFeedRepository {
  Stream<List<PostModel>> watchPublicPosts({required PublicFeedSort sort});

  /// Whether the signed-in user has liked this post — one listener per
  /// visible card (cheap: a single-document snapshot each), rather than
  /// trying to batch "which of these N posts have I liked" into one
  /// query, which Firestore has no direct support for anyway.
  Stream<bool> watchIsLikedByMe(String postId);

  Future<void> setLiked(String postId, bool liked);

  Stream<List<CommentModel>> watchComments(String postId);

  Future<void> addComment(String postId, String text);
}

class PublicFeedRepositoryImpl implements PublicFeedRepository {
  PublicFeedRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<List<PostModel>> watchPublicPosts({required PublicFeedSort sort}) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('posts').where('isPublic', isEqualTo: true);
    query = switch (sort) {
      PublicFeedSort.mostLiked => query.orderBy('likeCount', descending: true),
      PublicFeedSort.newest => query.orderBy('postedAt', descending: true),
    };
    // A reasonable page size for a first pass — no pagination/infinite
    // scroll yet (TODO), just the top N by the chosen sort.
    query = query.limit(50);

    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => PostModel.fromJson({...d.data(), 'id': d.id}))
              .toList(growable: false),
        );
  }

  @override
  Stream<bool> watchIsLikedByMe(String postId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('setLiked: no authenticated user');

    final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(uid);
    if (liked) {
      // likeCount itself is NOT written here — the likes trigger
      // (functions/src/triggers/likes.ts) reacts to this doc's
      // existence server-side. See firestore.rules: posts' own
      // allow update stays admin-only.
      await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await likeRef.delete();
    }
  }

  @override
  Stream<List<CommentModel>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommentModel.fromJson({...d.data(), 'id': d.id}))
              .toList(growable: false),
        );
  }

  @override
  Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('addComment: no authenticated user');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'userId': user.uid,
      'displayName': user.displayName ?? user.email ?? '匿名ユーザー',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
