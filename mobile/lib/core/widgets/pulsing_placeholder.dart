import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Gentle breathing/pulse placeholder for a slot nobody's posted to yet —
/// used in the following feed's per-user photo carousel. Not a literal
/// recreation of any specific app's animation (this session referenced
/// "セットログ" as a loose visual cue, but its exact motion isn't
/// something to guess at pixel-for-pixel) — this is PingPic's own
/// interpretation: a soft opacity pulse on a camera icon + "まだ投稿
/// されていません", conveying "waiting", not an error/empty state.
class PulsingPlaceholder extends StatefulWidget {
  const PulsingPlaceholder({super.key, this.label = 'まだ投稿されていません'});

  final String label;

  @override
  State<PulsingPlaceholder> createState() => _PulsingPlaceholderState();
}

class _PulsingPlaceholderState extends State<PulsingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      alignment: Alignment.center,
      child: FadeTransition(
        opacity: _opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(widget.label, style: AppTextStyles.body.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
