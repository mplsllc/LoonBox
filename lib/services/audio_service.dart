import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/player/domain/player_state.dart';

/// Global provider for the audio service, overridden in main.dart with the
/// concrete [RustAudioService] instance.
final audioServiceProvider = Provider<AudioService>(
  (ref) => throw UnimplementedError('AudioService not initialized'),
);

/// Interface to the Rust audio engine via flutter_rust_bridge.
///
/// All methods here will call into the Rust loonbox_bridge crate.
/// For Phase 1, these are stubs that will be wired up once
/// flutter_rust_bridge generates the bindings.
abstract class AudioService {
  // Playback
  Future<TrackInfo> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(int positionMs);
  Future<void> setVolume(double volume);
  Future<int> getPosition();
  Future<PlaybackState> getState();

  // EQ
  Future<void> setEq(List<double> bands);

  // Queue
  Future<void> queueSet(List<String> paths, int startIndex);
  Future<void> queueNext();
  Future<void> queuePrevious();
  Future<void> queueShuffle(bool enabled);
  Future<void> queueRepeat(RepeatMode mode);

  // Gapless & crossfade
  Future<void> setCrossfade(int durationMs);
  Future<void> setGapless(bool enabled);
  Future<void> preloadNext(String path);

  // Event stream
  Stream<PlayerEvent> get eventStream;
}
