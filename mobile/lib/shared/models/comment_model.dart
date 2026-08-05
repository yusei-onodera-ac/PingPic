import 'package:freezed_annotation/freezed_annotation.dart';
import 'post_model.dart' show TimestampConverter;

part 'comment_model.freezed.dart';
part 'comment_model.g.dart';

/// Mirrors `Comment` in packages/shared-types/src/index.ts
/// (posts/{postId}/comments/{commentId}).
@freezed
class CommentModel with _$CommentModel {
  const factory CommentModel({
    required String id,
    required String userId,
    required String displayName,
    required String text,
    @TimestampConverter() required DateTime createdAt,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);
}
