import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/di/providers.dart';
import '../../groups/data/group_repository.dart';
import '../../widget_bridge/home_widget_service.dart';
import '../data/camera_repository.dart';
import 'capture_state.dart';

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  return CameraRepositoryImpl();
});

/// Owns the `camera` package's controller lifecycle for a single in-app
/// capture session (init/dispose, front/back toggle, capture -> upload).
///
/// Named `CaptureController` rather than `CameraController` deliberately —
/// `package:camera` already exports a class called `CameraController`
/// (imported here as `camera_pkg.CameraController`), and reusing that name
/// for this StateNotifier would shadow/collide with it everywhere this
/// file's symbol is imported unqualified.
///
/// Only ever requests `Permission.camera` — never `Permission.photos` —
/// which is how "in-app camera only, no gallery import" is enforced at
/// the OS permission layer. See pubspec.yaml and docs/DATA_MODEL.md.
class CaptureController extends StateNotifier<CaptureState> {
  CaptureController(this._repository, this._groupRepository, this._homeWidgetService)
      : super(const CaptureState.initializing()) {
    _init();
  }

  final CameraRepository _repository;
  final GroupRepository _groupRepository;
  final HomeWidgetService _homeWidgetService;
  camera_pkg.CameraController? _controller;
  List<camera_pkg.CameraDescription> _cameras = [];
  int _lensIndex = 0;

  // This notifier is `autoDispose` (see captureControllerProvider below) —
  // the user can navigate away mid-async-op (during _init, switchLens, or
  // confirmAndUpload's network round trip), which disposes this notifier
  // while an `await` is still pending. Assigning `state = ...` after
  // dispose() throws, so every async gap below checks this first.
  bool _disposed = false;

  /// Exposed so CameraScreen can build a `CameraPreview(controller)`.
  camera_pkg.CameraController? get controller => _controller;

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (_disposed) return;
    if (!status.isGranted) {
      state = const CaptureState.error('カメラへのアクセスが許可されていません');
      return;
    }

    try {
      _cameras = await camera_pkg.availableCameras();
      if (_disposed) return;
      if (_cameras.isEmpty) {
        state = const CaptureState.error('カメラが見つかりません');
        return;
      }
      await _openCamera(_cameras[_lensIndex]);
    } catch (e) {
      if (!_disposed) state = CaptureState.error('カメラの初期化に失敗しました: $e');
    }
  }

  Future<void> _openCamera(camera_pkg.CameraDescription description) async {
    final previous = _controller;
    final next = camera_pkg.CameraController(
      description,
      camera_pkg.ResolutionPreset.high,
      enableAudio: false,
    );
    await next.initialize();
    if (_disposed) {
      // Lost the race with dispose() while initializing — release the
      // controller we just created instead of leaking it, and don't touch
      // `previous` (dispose() already handles the one that was live).
      await next.dispose();
      return;
    }
    await previous?.dispose();
    _controller = next;
    state = const CaptureState.ready();
  }

  /// Front/back toggle. No-op on devices with only one camera.
  Future<void> switchLens() async {
    if (_cameras.length < 2) return;
    _lensIndex = (_lensIndex + 1) % _cameras.length;
    state = const CaptureState.initializing();
    await _openCamera(_cameras[_lensIndex]);
  }

  Future<void> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    state = const CaptureState.capturing();
    try {
      final file = await controller.takePicture();
      final rawBytes = await file.readAsBytes();
      if (_disposed) return;

      // Client-side half of the Storage-egress cost guardrail described
      // in docs/ARCHITECTURE.md "Cost design" — CameraRepositoryImpl's
      // 8MB check is just a backstop, this is what actually keeps
      // uploads small day to day. 1600px / quality 80 is a starting
      // point, not a carefully tuned value — revisit once real photos
      // from real devices are available to eyeball.
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 1600,
        minHeight: 1600,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (_disposed) return;

      state = CaptureState.captured(compressed);
    } catch (e) {
      if (!_disposed) state = CaptureState.error('撮影に失敗しました: $e');
    }
  }

  /// Per the design doc: no editing/filters, only retake-or-post. This
  /// just discards the captured bytes and returns to the live preview.
  void retake() {
    state = const CaptureState.ready();
  }

  /// Resolves the caller's current group itself (rather than requiring it
  /// as a param) so this works regardless of how CameraScreen was
  /// reached — a notification tap only carries `slotNumber` in its deep
  /// link, not a groupId, so the screen layer can't always supply one.
  Future<void> confirmAndUpload({
    required Uint8List photoBytes,
    required String date,
    required int slotNumber,
    required String promptText,
    required bool isPublic,
    required String caption,
  }) async {
    state = const CaptureState.uploading();
    try {
      final groupId = await _groupRepository.currentGroupId();
      if (_disposed) return;
      if (groupId == null) {
        state = const CaptureState.error('グループに参加してから投稿してください');
        return;
      }
      await _repository.uploadPost(
        photoBytes: photoBytes,
        groupId: groupId,
        date: date,
        slotNumber: slotNumber,
        promptText: promptText,
        isPublic: isPublic,
        caption: caption,
      );
      // Best-effort — a widget update failure shouldn't surface as an
      // upload failure to the user, the post itself already succeeded.
      unawaited(_homeWidgetService.markPostedToday());
      if (!_disposed) state = const CaptureState.uploaded();
    } catch (e) {
      if (!_disposed) state = CaptureState.error('アップロードに失敗しました: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    super.dispose();
  }
}

final captureControllerProvider =
    StateNotifierProvider.autoDispose<CaptureController, CaptureState>((ref) {
  return CaptureController(
    ref.watch(cameraRepositoryProvider),
    ref.watch(groupRepositoryProvider),
    ref.watch(homeWidgetServiceProvider),
  );
});
