import 'dart:typed_data';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../application/camera_controller.dart';
import '../application/capture_state.dart';

/// JST calendar-day id ("YYYY-MM-DD"), matching the convention used
/// server-side by functions/src/services/scheduleService.ts's
/// `todayDocId` — JST has no DST, so a fixed +9h offset from UTC is safe.
String _todayDateIdJst() {
  final jstNow = DateTime.now().toUtc().add(const Duration(hours: 9));
  return '${jstNow.year.toString().padLeft(4, '0')}-'
      '${jstNow.month.toString().padLeft(2, '0')}-'
      '${jstNow.day.toString().padLeft(2, '0')}';
}

class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key, this.slotNumber});

  /// Which of today's 3 slots this capture is for, from the deep-link
  /// that opened this screen (notification tap / widget tap). Falls back
  /// to slot 1 if opened without that context (e.g. manually from the
  /// feed) — TODO: the feed screen should let the user pick which
  /// not-yet-posted slot they're capturing for instead of assuming 1.
  final int? slotNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    final notifier = ref.read(captureControllerProvider.notifier);
    final effectiveSlot = slotNumber ?? 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: state.when(
          initializing: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          ready: () => _CameraPreviewView(
            controller: notifier.controller,
            onCapture: notifier.capture,
            onSwitchLens: notifier.switchLens,
          ),
          capturing: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          captured: (bytes) => _CapturedPreviewView(
            bytes: bytes,
            onRetake: notifier.retake,
            onPost: () => notifier.confirmAndUpload(
              photoBytes: bytes,
              date: _todayDateIdJst(),
              slotNumber: effectiveSlot,
            ),
          ),
          uploading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('アップロード中…', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          uploaded: () {
            // Post succeeded — return to the feed. Scheduling a
            // post-frame callback avoids calling context.go mid-build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(AppRoutes.feed);
            });
            return const Center(
              child: Icon(Icons.check_circle, color: Colors.green, size: 64),
            );
          },
          error: (message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewView extends StatelessWidget {
  const _CameraPreviewView({
    required this.controller,
    required this.onCapture,
    required this.onSwitchLens,
  });

  final camera_pkg.CameraController? controller;
  final VoidCallback onCapture;
  final VoidCallback onSwitchLens;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ctrl != null && ctrl.value.isInitialized)
          camera_pkg.CameraPreview(ctrl)
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          right: 16,
          top: 16,
          child: IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 32),
            onPressed: onSwitchLens,
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onCapture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CapturedPreviewView extends StatelessWidget {
  const _CapturedPreviewView({
    required this.bytes,
    required this.onRetake,
    required this.onPost,
  });

  final Uint8List bytes;
  final VoidCallback onRetake;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.tonal(onPressed: onRetake, child: const Text('撮り直す')),
              FilledButton(onPressed: onPost, child: const Text('投稿する')),
            ],
          ),
        ),
      ],
    );
  }
}
