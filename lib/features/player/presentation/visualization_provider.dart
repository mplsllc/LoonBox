import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/rust/api.dart' as api;

/// Whether visualization is currently enabled (toggled by user).
final visualizationEnabledProvider = StateProvider<bool>((ref) => false);

/// Which visualizer style is active.
enum VisualizerStyle { spectrum, waveform, oscilloscope, vuMeter }

final visualizerStyleProvider =
    StateProvider<VisualizerStyle>((ref) => VisualizerStyle.spectrum);

/// Streams visualization data at ~30fps when enabled.
final visualizationDataProvider =
    StreamProvider.autoDispose<api.VisualizationData>((ref) {
  final enabled = ref.watch(visualizationEnabledProvider);
  if (!enabled) {
    return Stream.value(api.VisualizationData(
      waveform: Float32List(256),
      spectrum: Float32List(64),
      peakLeft: 0.0,
      peakRight: 0.0,
    ));
  }

  // Enable visualization in the engine
  api.playerSetVisualizationEnabled(enabled: true);

  ref.onDispose(() {
    api.playerSetVisualizationEnabled(enabled: false);
  });

  // Poll at ~30fps
  return Stream.periodic(const Duration(milliseconds: 33), (_) => null)
      .asyncMap((_) => api.playerGetVisualizationData());
});
