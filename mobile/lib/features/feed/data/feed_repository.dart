import 'package:cloud_firestore/cloud_firestore.dart';
import '../../prompts/data/daily_schedule_model.dart';
import '../../../shared/models/post_model.dart';

abstract class FeedRepository {
  /// Emits null if today's daily_schedules doc doesn't exist yet.
  Stream<DailyScheduleModel?> watchTodaySchedule(String dateId);

  /// A single followed user's posts for one date (0-3 of them, one per
  /// slot) — the following feed (features/feed/presentation/) calls this
  /// once per followed uid to build that user's swipeable photo set.
  ///
  /// Cost/scale note: this is N separate single-user listeners (one per
  /// followed uid), not one batched query — Firestore's `where(field,
  /// 'in', [...])` could combine these into fewer round trips for larger
  /// following lists, but two plain equality filters (userId + date) are
  /// simpler to reason about and don't need a composite index, unlike an
  /// `in` + `==` compound query. Fine at friend-following scale; revisit
  /// with pagination/batching if a user follows hundreds of people.
  Stream<List<PostModel>> watchUserPosts(String uid, String dateId);
}

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<DailyScheduleModel?> watchTodaySchedule(String dateId) {
    return _firestore.collection('daily_schedules').doc(dateId).snapshots().map((snap) {
      if (!snap.exists) return null;
      // The doc itself only stores `slots` (the doc id IS the date, per
      // packages/shared-types/src/index.ts's DailySchedule) — inject
      // dateId so it satisfies DailyScheduleModel's `date` field, which
      // exists as a Dart-side convenience the Firestore shape doesn't
      // literally have.
      return DailyScheduleModel.fromJson({...snap.data()!, 'date': dateId});
    });
  }

  @override
  Stream<List<PostModel>> watchUserPosts(String uid, String dateId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .where('date', isEqualTo: dateId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PostModel.fromJson({...d.data(), 'id': d.id}))
            .toList(growable: false));
  }
}
