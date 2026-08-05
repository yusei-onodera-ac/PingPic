import 'package:cloud_firestore/cloud_firestore.dart';
import '../../prompts/data/daily_schedule_model.dart';
import '../../../shared/models/post_model.dart';

abstract class FeedRepository {
  /// Emits null if today's daily_schedules doc doesn't exist yet.
  Stream<DailyScheduleModel?> watchTodaySchedule(String dateId);

  /// Every post any member of the group made on this date, across all 3
  /// slots — the client derives "have I posted for slot N" and "who else
  /// has" from this single stream rather than issuing a second query, to
  /// keep this to one Firestore listener per feed view (see
  /// docs/ARCHITECTURE.md "Cost design"). Two equality filters
  /// (groupId + date) don't need a composite index — Firestore serves
  /// pure-equality compound queries from the automatic single-field
  /// indexes.
  Stream<List<PostModel>> watchGroupPosts(String groupId, String dateId);
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
  Stream<List<PostModel>> watchGroupPosts(String groupId, String dateId) {
    return _firestore
        .collection('posts')
        .where('groupId', isEqualTo: groupId)
        .where('date', isEqualTo: dateId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PostModel.fromJson({...d.data(), 'id': d.id}))
            .toList(growable: false));
  }
}
