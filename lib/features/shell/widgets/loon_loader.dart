import 'dart:math';

import 'package:flutter/material.dart';

/// Animated loading indicator: the LoonBox loon swims across water.
class LoonLoader extends StatefulWidget {
  const LoonLoader({super.key, this.size = 64});

  final double size;

  @override
  State<LoonLoader> createState() => _LoonLoaderState();
}

class _LoonLoaderState extends State<LoonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loonSize = widget.size;
    final rippleWidth = loonSize * 2.5;

    return SizedBox(
      width: rippleWidth,
      height: loonSize + 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Gentle bobbing motion
          final bob = sin(_controller.value * 2 * pi) * 3.0;
          // Slight tilt with the bob
          final tilt = sin(_controller.value * 2 * pi) * 0.04;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Water ripples
              Positioned(
                bottom: 0,
                child: CustomPaint(
                  size: Size(rippleWidth, 12),
                  painter: _RipplePainter(
                    progress: _controller.value,
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // Loon
              Positioned(
                bottom: 6 + bob,
                child: Transform.rotate(
                  angle: tilt,
                  child: child,
                ),
              ),
            ],
          );
        },
        child: Image.asset(
          'assets/icons/darkloon.png',
          width: loonSize,
          height: loonSize,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw expanding elliptical ripples
    for (var i = 0; i < 3; i++) {
      final rippleProgress = (progress + i * 0.33) % 1.0;
      final opacity = (1.0 - rippleProgress).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity * 0.4);

      final rx = size.width * 0.15 + rippleProgress * size.width * 0.35;
      final ry = 2 + rippleProgress * 6;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: rx * 2,
          height: ry * 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
