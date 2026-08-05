import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

/// Mirrors `Post` in packages/shared-types/src/index.ts. Keep these two in
/// sync by hand — see docs/ARCHITECTURE.md "Known duplication".
@freezed
class PostModel with _$PostModel {
  const factory PostModel({
    required String id,
    required String userId,
    /// Denormalized at post time — no separate user-profile collection
    /// exists in this app (yet). See the field's doc comment in
    /// shared-types for the fallback convention.
    required String authorDisplayName,
    /// "YYYY-MM-DD"
    required String date,
    /// 1, 2, or 3
    required int slotNumber,
    required String photoUrl,
    @TimestampConverter() required DateTime postedAt,
    /// Denormalized copy of the slot's prompt at post time — see the
    /// field's doc comment in shared-types for why (avoids an extra
    /// daily_schedules read per post in the public feed).
    required String promptText,
    /// Chosen once at capture time — see CapturedPreviewView. Mutual
    /// connections can always see this post regardless; this flag
    /// additionally surfaces it in the "みんなの投稿" feed to everyone.
    required bool isPublic,
    required String caption,
    /// Maintained server-side by functions/src/triggers/likes.ts —
    /// never written directly by the client.
    required int likeCount,
  }) = _PostModel;

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);
}

/// Converts between Firestore's Timestamp and DateTime for json_serializable.
class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp json) => json.toDate();

  @override
  Timestamp toJson(DateTime object) => Timestamp.fromDate(object);
}
