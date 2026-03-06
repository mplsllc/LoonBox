import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart' hide EqPreset;
import '../../../services/audio_service.dart';
import '../../../services/media_controls_service.dart';
import '../domain/player_state.dart';
import '../domain/eq_preset.dart';
import 'queue_provider.dart';

/// Current playback state.
final playbackStateProvider = StateNotifierProvider<PlaybackStateNotifier, PlaybackSnapshot>(
  (ref) => PlaybackStateNotifier(),
);

/// Listens to the audio engine event stream and updates the playback state.
/// Also keeps OS media controls (SMTC) in sync.
/// Must be watched (e.g. in the app shell) to activate.
final audioEventListenerProvider = Provider<void>((ref) {
  final audio = ref.watch(audioServiceProvider);
  final notifier = ref.read(playbackStateProvider.notifier);
  final mediaControls = ref.watch(mediaControlsServiceProvider);

  final sub = audio.eventStream.listen((event) {
    switch (event) {
      case PositionEvent(:final positionMs):
        notifier.updatePosition(positionMs);
        final durationMs = ref.read(playbackStateProvider).durationMs;
        mediaControls.updatePosition(positionMs, durationMs);
      case StateChangedEvent(:final state):
        notifier.updateState(state);
        mediaControls.updatePlaybackState(state);
      case TrackChangedEvent(:final trackInfo):
        // Record skip if previous track was playing and position < 80% of duration
        final prev = ref.read(playbackStateProvider);
        if (prev.currentTrack != null && prev.state == PlaybackState.playing) {
          final queue = ref.read(queueProvider);
          final prevTrack = queue.currentTrack;
          if (prevTrack != null &&
              prev.durationMs > 0 &&
              prev.positionMs < prev.durationMs * 0.8) {
            final db = ref.read(databaseProvider);
            final now = DateTime.now().millisecondsSinceEpoch;
            // Record partial play in history
            db.into(db.playHistory).insert(PlayHistoryCompanion.insert(
              trackId: prevTrack.id,
              playedAt: now,
              durationListenedMs: Value(prev.positionMs),
              completed: const Value(false),
            ));
            // Update skip stats
            db.customStatement(
              'UPDATE tracks SET skip_count = skip_count + 1, last_skipped_at = ? WHERE id = ?',
              [now, prevTrack.id],
            );
          }
        }
        notifier.updateTrack(trackInfo);
        final queueTrack = ref.read(queueProvider).currentTrack;
        mediaControls.updateTrack(
          title: queueTrack?.title ?? trackInfo.path.split('/').last.split('\\').last,
          artist: queueTrack?.artist,
          album: queueTrack?.album,
          filePath: trackInfo.path,
          durationMs: trackInfo.durationMs,
        );
      case TrackFinishedEvent():
        notifier.updateState(PlaybackState.stopped);
        // Record completed play in history + update track stats
        final queue = ref.read(queueProvider);
        final track = queue.currentTrack;
        if (track != null) {
          final db = ref.read(databaseProvider);
          final now = DateTime.now().millisecondsSinceEpoch;
          final listenedMs = ref.read(playbackStateProvider).positionMs;
          db.into(db.playHistory).insert(PlayHistoryCompanion.insert(
            trackId: track.id,
            playedAt: now,
            durationListenedMs: Value(listenedMs),
            completed: const Value(true),
          ));
          db.customStatement(
            'UPDATE tracks SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
            [now, track.id],
          );
        }
        // Auto-advance to next track in queue
        ref.read(queueProvider.notifier).next();
      case PlayerErrorEvent():
        notifier.updateState(PlaybackState.error);
      case BufferProgressEvent():
        break;
    }
  });

  ref.onDispose(() => sub.cancel());
});

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.state = PlaybackState.stopped,
    this.currentTrack,
    this.positionMs = 0,
    this.durationMs = 0,
    this.volume = 1.0,
    this.isMuted = false,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.gapless = true,
    this.crossfadeMs = 0,
  });

  final PlaybackState state;
  final TrackInfo? currentTrack;
  final int positionMs;
  final int durationMs;
  final double volume;
  final bool isMuted;
  final bool shuffle;
  final RepeatMode repeat;
  final bool gapless;
  final int crossfadeMs;

  PlaybackSnapshot copyWith({
    PlaybackState? state,
    TrackInfo? currentTrack,
    int? positionMs,
    int? durationMs,
    double? volume,
    bool? isMuted,
    bool? shuffle,
    RepeatMode? repeat,
    bool? gapless,
    int? crossfadeMs,
  }) {
    return PlaybackSnapshot(
      state: state ?? this.state,
      currentTrack: currentTrack ?? this.currentTrack,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      gapless: gapless ?? this.gapless,
      crossfadeMs: crossfadeMs ?? this.crossfadeMs,
    );
  }
}

class PlaybackStateNotifier extends StateNotifier<PlaybackSnapshot> {
  PlaybackStateNotifier() : super(const PlaybackSnapshot());

  void updatePosition(int ms) => state = state.copyWith(positionMs: ms);
  void updateState(PlaybackState s) => state = state.copyWith(state: s);
  void updateTrack(TrackInfo t) => state = state.copyWith(
        currentTrack: t,
        durationMs: t.durationMs,
        positionMs: 0,
      );
  void setVolume(double v) => state = state.copyWith(volume: v);
  void toggleMute() => state = state.copyWith(isMuted: !state.isMuted);
  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);
  void cycleRepeat() {
    final next = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeat: next);
  }
}

/// Current EQ preset.
final eqPresetProvider = StateProvider<EqPreset>(
  (ref) => EqPreset.builtInPresets.first,
);

/// EQ enabled state.
final eqEnabledProvider = StateProvider<bool>((ref) => false);
