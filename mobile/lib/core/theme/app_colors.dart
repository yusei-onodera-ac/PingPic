import 'package:flutter/material.dart';

/// PingPic's brand palette. Deliberately not a straight BeReal clone —
/// warm coral instead of BeReal's signature yellow/black, since PingPic's
/// "ping" concept is about an instant, energetic nudge rather than
/// BeReal's flatter graphic-design identity. Kept intentionally small
/// (a handful of hand-picked values, not a full 61-role Material 3
/// token set) — AppTheme builds a ColorScheme from these via
/// ColorScheme.fromSeed + targeted overrides rather than hand-specifying
/// every role.
abstract class AppColors {
  /// Primary brand accent — buttons, active states, the shutter ring.
  static const coral = Color(0xFFFF6452);

  /// "You've posted" / success states. A muted teal-green rather than a
  /// generic system green, to sit closer to the coral on the color wheel
  /// and avoid feeling like a bolted-on platform default.
  static const success = Color(0xFF2FB380);

  /// Camera screen / dark-surface background — near-black, not pure
  /// black, so photos and the shutter ring have something to sit against
  /// without a harsh true-black frame.
  static const ink = Color(0xFF15141A);
  static const inkSurface = Color(0xFF201F26);

  /// Light-mode background — warm off-white rather than clinical pure
  /// white, matching the coral's warmth.
  static const cream = Color(0xFFFBF7F2);
  static const creamSurface = Color(0xFFF3ECE3);

  static const mutedLight = Color(0xFF6B6873);
  static const mutedDark = Color(0xFF9C99A6);
}
