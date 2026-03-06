import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/rust/api.dart' as api;
import 'visualization_provider.dart';

/// Main visualizer widget that renders the active visualizer style.
class VisualizerWidget extends ConsumerWidget {
  const VisualizerWidget({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(visualizationEnabledProvider);
    if (!enabled) return SizedBox(height: height);

    final style = ref.watch(visualizerStyleProvider);
    final dataAsync = ref.watch(visualizationDataProvider);

    return dataAsync.when(
      loading: () => SizedBox(height: height),
      error: (_, _) => SizedBox(height: height),
      data: (data) => GestureDetector(
        onTap: () {
          // Cycle through styles on tap
          const styles = VisualizerStyle.values;
          final next = styles[(style.index + 1) % styles.length];
          ref.read(visualizerStyleProvider.notifier).state = next;
        },
        child: SizedBox(
          height: height,
          child: switch (style) {
            VisualizerStyle.spectrum => _SpectrumBars(data: data),
            VisualizerStyle.waveform => _Waveform(data: data),
            VisualizerStyle.oscilloscope => _Oscilloscope(data: data),
            VisualizerStyle.vuMeter => _VuMeter(data: data),
          },
        ),
      ),
    );
  }
}

// ─── Spectrum Bars (Winamp-style) ───────────────────────────────────

class _SpectrumBars extends StatelessWidget {
  const _SpectrumBars({required this.data});
  final api.VisualizationData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SpectrumPainter(
        spectrum: data.spectrum,
        barColor: colorScheme.primary,
        peakColor: colorScheme.tertiary,
        bgColor: Colors.transparent,
      ),
      size: Size.infinite,
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.spectrum,
    required this.barColor,
    required this.peakColor,
    required this.bgColor,
  });

  final Float32List spectrum;
  final Color barColor;
  final Color peakColor;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = spectrum.length; // 64 bins
    final barWidth = size.width / barCount;
    final gap = barWidth * 0.2;
    final effectiveBarWidth = barWidth - gap;

    for (int i = 0; i < barCount; i++) {
      final value = spectrum[i].clamp(0.0, 1.0);
      final barHeight = value * size.height;
      final x = i * barWidth + gap / 2;

      // Gradient from bottom to top: primary → tertiary
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          barColor,
          Color.lerp(barColor, peakColor, 0.5)!,
          peakColor,
        ],
      );

      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        effectiveBarWidth,
        barHeight,
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(x, 0, effectiveBarWidth, size.height),
        );

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        paint,
      );

      // Peak indicator line
      if (value > 0.05) {
        final peakPaint = Paint()
          ..color = peakColor
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(x, size.height - barHeight),
          Offset(x + effectiveBarWidth, size.height - barHeight),
          peakPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) => true;
}

// ─── Waveform ───────────────────────────────────────────────────────

class _Waveform extends StatelessWidget {
  const _Waveform({required this.data});
  final api.VisualizationData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _WaveformPainter(
        waveform: data.waveform,
        color: colorScheme.primary,
        fillColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
      size: Size.infinite,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.waveform,
    required this.color,
    required this.fillColor,
  });

  final Float32List waveform;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final midY = size.height / 2;
    final stepX = size.width / (waveform.length - 1);

    // Filled area
    final fillPath = Path()..moveTo(0, midY);
    for (int i = 0; i < waveform.length; i++) {
      final x = i * stepX;
      final y = midY - (waveform[i].clamp(-1.0, 1.0) * midY * 0.9);
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo(size.width, midY);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Mirrored fill below center
    final mirrorPath = Path()..moveTo(0, midY);
    for (int i = 0; i < waveform.length; i++) {
      final x = i * stepX;
      final y = midY + (waveform[i].clamp(-1.0, 1.0).abs() * midY * 0.9);
      mirrorPath.lineTo(x, y);
    }
    mirrorPath.lineTo(size.width, midY);
    mirrorPath.close();

    canvas.drawPath(mirrorPath, Paint()..color = fillColor);

    // Stroke line
    final linePath = Path();
    for (int i = 0; i < waveform.length; i++) {
      final x = i * stepX;
      final y = midY - (waveform[i].clamp(-1.0, 1.0) * midY * 0.9);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Center line
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}

// ─── Oscilloscope ───────────────────────────────────────────────────

class _Oscilloscope extends StatelessWidget {
  const _Oscilloscope({required this.data});
  final api.VisualizationData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _OscilloscopePainter(
        waveform: data.waveform,
        color: colorScheme.tertiary,
        glowColor: colorScheme.tertiary.withValues(alpha: 0.3),
      ),
      size: Size.infinite,
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  _OscilloscopePainter({
    required this.waveform,
    required this.color,
    required this.glowColor,
  });

  final Float32List waveform;
  final Color color;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final midY = size.height / 2;
    final stepX = size.width / (waveform.length - 1);

    // Grid lines (oscilloscope style)
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Build path
    final path = Path();
    for (int i = 0; i < waveform.length; i++) {
      final x = i * stepX;
      final y = midY - (waveform[i].clamp(-1.0, 1.0) * midY * 0.85);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow effect (wider, semi-transparent)
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Main trace
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_OscilloscopePainter oldDelegate) => true;
}

// ─── VU Meter ───────────────────────────────────────────────────────

class _VuMeter extends StatelessWidget {
  const _VuMeter({required this.data});
  final api.VisualizationData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _VuMeterPainter(
        peakLeft: data.peakLeft,
        peakRight: data.peakRight,
        primaryColor: colorScheme.primary,
        warningColor: Colors.orange,
        clipColor: colorScheme.error,
      ),
      size: Size.infinite,
    );
  }
}

class _VuMeterPainter extends CustomPainter {
  _VuMeterPainter({
    required this.peakLeft,
    required this.peakRight,
    required this.primaryColor,
    required this.warningColor,
    required this.clipColor,
  });

  final double peakLeft;
  final double peakRight;
  final Color primaryColor;
  final Color warningColor;
  final Color clipColor;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 32;
    const gap = 2.0;
    final segmentWidth = (size.width - (segments - 1) * gap) / segments;
    final barHeight = (size.height - 24) / 2 - 8; // Two bars with labels

    _drawBar(canvas, size, 'L', peakLeft, 16, segmentWidth, barHeight, gap,
        segments);
    _drawBar(canvas, size, 'R', peakRight, 16 + barHeight + 16, segmentWidth,
        barHeight, gap, segments);
  }

  void _drawBar(Canvas canvas, Size size, String label, double level,
      double top, double segWidth, double barHeight, double gap, int segments) {
    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: primaryColor.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(4, top + (barHeight - 12) / 2));

    final startX = 24.0;
    final availWidth = size.width - startX - 8;
    final actualSegWidth = (availWidth - (segments - 1) * gap) / segments;

    for (int i = 0; i < segments; i++) {
      final t = i / segments;
      final x = startX + i * (actualSegWidth + gap);
      final isLit = t < level;

      Color segColor;
      if (t > 0.9) {
        segColor = clipColor;
      } else if (t > 0.7) {
        segColor = warningColor;
      } else {
        segColor = primaryColor;
      }

      if (!isLit) {
        segColor = segColor.withValues(alpha: 0.15);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, actualSegWidth, barHeight),
          const Radius.circular(1),
        ),
        Paint()..color = segColor,
      );
    }
  }

  @override
  bool shouldRepaint(_VuMeterPainter oldDelegate) => true;
}
