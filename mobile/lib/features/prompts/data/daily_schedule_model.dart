import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../shared/models/post_model.dart' show TimestampConverter;

part 'daily_schedule_model.freezed.dart';
part 'daily_schedule_model.g.dart';

/// Mirrors `PromptCredit` in packages/shared-types/src/index.ts.
///
/// `unionKey: 'type'` makes json_serializable read/write a `"type"` field
/// as the discriminator ("admin" | "user") — matching the TS union's shape
/// exactly, instead of freezed's default `runtimeType` key name.
@Freezed(unionKey: 'type')
class PromptCredit with _$PromptCredit {
  const factory PromptCredit.admin() = _PromptCreditAdmin;
  const factory PromptCredit.user({
    required String uid,
    required String displayName,
  }) = _PromptCreditUser;

  factory PromptCredit.fromJson(Map<String, dynamic> json) =>
      _$PromptCreditFromJson(json);
}

/// Mirrors `ScheduleSlot` in packages/shared-types/src/index.ts.
@freezed
class ScheduleSlot with _$ScheduleSlot {
  const factory ScheduleSlot({
    @TimestampConverter() required DateTime sendTime,
    required String promptText,
    required PromptCredit credit,
  }) = _ScheduleSlot;

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) =>
      _$ScheduleSlotFromJson(json);
}

/// Mirrors `DailySchedule` in packages/shared-types/src/index.ts. Always
/// length 3 (T1, T2, T3) — a null entry means that slot hasn't been
/// configured by an admin yet (normal before the 00:00 batch job runs).
@freezed
class DailyScheduleModel with _$DailyScheduleModel {
  const factory DailyScheduleModel({
    required String date, // doc id, "YYYY-MM-DD"
    required List<ScheduleSlot?> slots, // length 3, entries may be null
  }) = _DailyScheduleModel;

  factory DailyScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$DailyScheduleModelFromJson(json);
}
