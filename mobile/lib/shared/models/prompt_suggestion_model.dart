import 'package:freezed_annotation/freezed_annotation.dart';
import 'post_model.dart' show TimestampConverter;

part 'prompt_suggestion_model.freezed.dart';
part 'prompt_suggestion_model.g.dart';

enum SuggestionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

/// Mirrors `PromptSuggestion['submitterInfo']` in
/// packages/shared-types/src/index.ts. Kept as a nested object (not
/// flattened) to match the actual Firestore document shape.
@freezed
class SubmitterInfo with _$SubmitterInfo {
  const factory SubmitterInfo({
    required String uid,
    required String displayName,
  }) = _SubmitterInfo;

  factory SubmitterInfo.fromJson(Map<String, dynamic> json) =>
      _$SubmitterInfoFromJson(json);
}

/// Mirrors `PromptSuggestion` in packages/shared-types/src/index.ts.
@freezed
class PromptSuggestionModel with _$PromptSuggestionModel {
  const factory PromptSuggestionModel({
    required String id,
    required String suggestionText,
    required SubmitterInfo submitterInfo,
    required SuggestionStatus status,
    @TimestampConverter() required DateTime createdAt,
  }) = _PromptSuggestionModel;

  factory PromptSuggestionModel.fromJson(Map<String, dynamic> json) =>
      _$PromptSuggestionModelFromJson(json);
}
