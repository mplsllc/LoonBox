/// Mirrors Rust PlayerState enum.
enum PlaybackState { stopped, loading, playing, paused, error }

/// Mirrors Rust RepeatMode enum.
enum RepeatMode { off, one, all }

/// Mirrors Rust PlayerEvent enum.
sealed class PlayerEvent {
  const PlayerEvent();
}

class PositionEvent extends PlayerEvent {
  const PositionEvent(this.positionMs);
  final int positionMs;
}

class StateChangedEvent extends PlayerEvent {
  const StateChangedEvent(this.state);
  final PlaybackState state;
}

class TrackChangedEvent extends PlayerEvent {
  const TrackChangedEvent(this.trackInfo);
  final TrackInfo trackInfo;
}

class TrackFinishedEvent extends PlayerEvent {
  const TrackFinishedEvent();
}

class PlayerErrorEvent extends PlayerEvent {
  const PlayerErrorEvent(this.message);
  final String message;
}

class BufferProgressEvent extends PlayerEvent {
  const BufferProgressEvent(this.progress);
  final double progress;
}

/// Information about the currently loaded track from the Rust decoder.
class TrackInfo {
  const TrackInfo({
    required this.path,
    required this.durationMs,
    required this.sampleRate,
    required this.channels,
    this.bitDepth,
    required this.codec,
  });

  final String path;
  final int durationMs;
  final int sampleRate;
  final int channels;
  final int? bitDepth;
  final String codec;
}
