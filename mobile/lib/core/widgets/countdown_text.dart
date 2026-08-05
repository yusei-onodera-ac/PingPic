import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Live "残り Xh Ym" countdown to a deadline — this is what the design
/// doc means by slot 3's "当日24:00まで(カウントダウン表示)" requirement,
/// which the rest of the scaffold had missed until this pass. Ticks every
/// 30s (not every second — an hours/minutes display doesn't need
/// per-second precision, and this avoids waking the widget tree that
/// often for no visible change).
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.deadline,
    this.style,
    this.expiredLabel = '締切',
  });

  final DateTime deadline;
  final TextStyle? style;
  final String expiredLabel;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.deadline.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _remaining = widget.deadline.difference(DateTime.now()));
    });
  }

  @override
  void didUpdateWidget(covariant CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      setState(() => _remaining = widget.deadline.difference(DateTime.now()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        AppTextStyles.monoAccent.copyWith(color: Theme.of(context).colorScheme.error);

    if (_remaining.isNegative) {
      return Text(widget.expiredLabel, style: style);
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final label = hours > 0 ? '残り ${hours}時間${minutes}分' : '残り ${minutes}分';
    return Text(label, style: style);
  }
}
