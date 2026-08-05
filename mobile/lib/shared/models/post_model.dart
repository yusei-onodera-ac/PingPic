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
    required String groupId,
    required String userId,
    /// "YYYY-MM-DD"
    required String date,
    /// 1, 2, or 3
    required int slotNumber,
    required String photoUrl,
    @TimestampConverter() required DateTime postedAt,
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
