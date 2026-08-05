import 'package:flutter/material.dart';

/// Hand-picked type scale (system fonts, no google_fonts dependency —
/// every string in this app is Japanese, and Flutter/OS already pick a
/// solid system Japanese face; adding a Latin-only display font would do
/// nothing for the copy that actually needs it and adds an unverified
/// dependency). The "こだわり" here is in weight/size/spacing choices,
/// not a custom typeface.
///
/// `letterSpacing` is deliberately left at 0 (or omitted) everywhere
/// EXCEPT `displayHeavy`, which is only ever used for Latin/numeric
/// content (invite codes, countdown timers, slot numbers) — negative
/// tracking looks intentional there but visibly breaks CJK character
/// spacing if applied to Japanese text.
abstract class AppTextStyles {
  static const displayHeavy = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Countdown / invite-code digit style — same intent as displayHeavy
  /// but sized for inline use rather than a full display headline.
  static const monoAccent = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
