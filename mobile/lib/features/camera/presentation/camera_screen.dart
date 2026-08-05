import 'dart:typed_data';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../prompts/data/daily_schedule_model.dart';
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

DateTime _todayMidnightDeadlineJst(String dateId) {
  return DateTime.parse('${dateId}T00:00:00+09:00').add(const Duration(days: 1));
}

/// Bounds-checked index access — not using package:collection's
/// elementAtOrNull to avoid an extra dependency for one call site.
ScheduleSlot? _slotAt(List<ScheduleSlot?>? slots, int index) {
  if (slots == null || index < 0 || index >= slots.length) return null;
  return slots[index];
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
    final dateId = _todayDateIdJst();
    final feedRepo = ref.watch(feedRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: StreamBuilder<DailyScheduleModel?>(
          stream: feedRepo.watchTodaySchedule(dateId),
          builder: (context, scheduleSnap) {
            final promptText =
                _slotAt(scheduleSnap.data?.slots, effectiveSlot - 1)?.promptText;

            return Stack(
              children: [
                state.when(
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
                    onPost: (isPublic, caption) => notifier.confirmAndUpload(
                      photoBytes: bytes,
                      date: dateId,
                      slotNumber: effectiveSlot,
                      promptText: promptText ?? '',
                      isPublic: isPublic,
                      caption: caption,
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
                      child: Icon(Icons.check_circle, color: AppColors.success, size: 64),
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
                // Hidden once a photo's been captured — the top bar would
                // otherwise sit awkwardly over the public/caption sheet.
                if (state is CaptureStateInitializing ||
                    state is CaptureStateReady ||
                    state is CaptureStateCapturing)
                  _TopBar(dateId: dateId, slotNumber: effectiveSlot, promptText: promptText),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Gradient-scrim header showing the close button, which slot this is,
/// today's prompt text, and (slot 3 only) the countdown to 24:00 JST —
/// so the person framing their shot can actually see what they're
/// supposed to be photographing, instead of having to remember it from
/// the feed screen.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.dateId, required this.slotNumber, required this.promptText});

  final String dateId;
  final int slotNumber;
  final String? promptText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.feed),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'スロット $slotNumber',
                          style: AppTextStyles.caption.copyWith(color: Colors.white70),
                        ),
                        if (slotNumber == 3) ...[
                          const SizedBox(width: 8),
                          CountdownText(
                            deadline: _todayMidnightDeadlineJst(dateId),
                            style: AppTextStyles.caption.copyWith(color: AppColors.coral),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      promptText ?? '読み込み中…',
                      style: AppTextStyles.title.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          child: SafeArea(
            child: _RoundIconButton(icon: Icons.cameraswitch, onPressed: onSwitchLens),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(child: _ShutterButton(onTap: onCapture)),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 26),
        onPressed: onPressed,
      ),
    );
  }
}

/// Coral-ringed shutter with a press-down scale animation — the one
/// moment in the app worth a bit of tactile flourish, since it's the
/// entire point of a photo-of-the-moment app.
class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 4)),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.coral),
          ),
        ),
      ),
    );
  }
}

/// Post-capture review: retake/post, plus (per this session's added
/// requirement) a per-photo public/private choice and an optional
/// one-line caption — made HERE, at capture time, not toggleable
/// afterward (there's no post-editing flow, consistent with the rest of
/// the app's "no editing" posture).
class _CapturedPreviewView extends StatefulWidget {
  const _CapturedPreviewView({
    required this.bytes,
    required this.onRetake,
    required this.onPost,
  });

  final Uint8List bytes;
  final VoidCallback onRetake;
  final void Function(bool isPublic, String caption) onPost;

  @override
  State<_CapturedPreviewView> createState() => _CapturedPreviewViewState();
}

class _CapturedPreviewViewState extends State<_CapturedPreviewView> {
  bool _isPublic = false;
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(widget.bytes, fit: BoxFit.cover),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isPublic ? 'みんなの投稿に公開する' : '公開しない（グループのみ）',
                        style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeColor: AppColors.coral,
                    ),
                  ],
                ),
                if (_isPublic) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _captionController,
                    maxLength: 60,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '一言コメント（任意）',
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onRetake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        child: const Text('撮り直す'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => widget.onPost(_isPublic, _captionController.text.trim()),
                        child: const Text('投稿する'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
