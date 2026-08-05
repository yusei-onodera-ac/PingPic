import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'capture_state.freezed.dart';

/// State for the in-app camera capture flow. Using freezed (public
/// generated subclasses + `.when()`) rather than a hand-rolled sealed
/// class here deliberately — a hand-rolled sealed class needs its variant
/// subclasses to be *public* to pattern-match on from another file
/// (camera_screen.dart), and freezed's `.when()` sidesteps that instead
/// of exporting variant classes we'd otherwise have no other use for.
@freezed
class CaptureState with _$CaptureState {
  const factory CaptureState.initializing() = CaptureStateInitializing;
  const factory CaptureState.ready() = CaptureStateReady;
  const factory CaptureState.capturing() = CaptureStateCapturing;
  const factory CaptureState.captured(Uint8List bytes) = CaptureStateCaptured;
  const factory CaptureState.uploading() = CaptureStateUploading;
  const factory CaptureState.uploaded() = CaptureStateUploaded;
  const factory CaptureState.error(String message) = CaptureStateError;
}
