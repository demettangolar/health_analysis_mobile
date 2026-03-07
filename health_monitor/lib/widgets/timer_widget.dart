import 'dart:async';
import 'package:flutter/material.dart';

/// Displays a large countdown timer and notifies [onFinished] when it reaches 0.
class TimerWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback onFinished;

  const TimerWidget({
    super.key,
    required this.duration,
    required this.onFinished,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late int _remaining; // seconds
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer t) {
    if (_remaining <= 0) {
      t.cancel();
      widget.onFinished();
      return;
    }
    setState(() => _remaining--);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _timerColor(BuildContext context) {
    if (_remaining > 60) return Theme.of(context).colorScheme.primary;
    if (_remaining > 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _format(_remaining),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: _timerColor(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'remaining',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 1 - (_remaining / widget.duration.inSeconds),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: _timerColor(context),
          ),
        ),
      ],
    );
  }
}
