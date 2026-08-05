import 'package:freezed_annotation/freezed_annotation.dart';
import 'post_model.dart' show TimestampConverter;

part 'group_model.freezed.dart';
part 'group_model.g.dart';

/// Mirrors `Group` in packages/shared-types/src/index.ts. See that file's
/// doc comment for the invite-code create/join design (not in the
/// original design doc — added when implementing this feature).
/// Mutated only via GroupRepository's Cloud Functions calls, never
/// written directly from the client.
@freezed
class GroupModel with _$GroupModel {
  const factory GroupModel({
    required String id,
    required String name,
    required List<String> memberIds,
    required String inviteCode,
    required String createdBy,
    @TimestampConverter() required DateTime createdAt,
  }) = _GroupModel;

  factory GroupModel.fromJson(Map<String, dynamic> json) =>
      _$GroupModelFromJson(json);
}
