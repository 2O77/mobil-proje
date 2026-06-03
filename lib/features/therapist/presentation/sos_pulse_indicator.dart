import 'package:flutter/material.dart';

class SosPulseIndicator extends StatefulWidget {
  const SosPulseIndicator({super.key, this.size = 14});

  final double size;

  @override
  State<SosPulseIndicator> createState() => _SosPulseIndicatorState();
}

class _SosPulseIndicatorState extends State<SosPulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final glow = 6 + (10 * t);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade700,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.35 + (0.45 * t)),
                blurRadius: glow,
                spreadRadius: 1 + (2 * t),
              ),
            ],
          ),
        );
      },
    );
  }
}
