import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../services/audio_service.dart';
import '../domain/player_state.dart';
import 'player_provider.dart';

/// Queue state: ordered list of tracks with current index.
class QueueState {
  const QueueState({
    this.tracks = const [],
    this.currentIndex = -1,
    this.originalOrder = const [],
    this.isShuffled = false,
  });

  final List<Track> tracks;
  final int currentIndex;
  final List<Track> originalOrder;
  final bool isShuffled;

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < tracks.length ? tracks[currentIndex] : null;

  bool get hasNext => currentIndex < tracks.length - 1;
  bool get hasPrevious => currentIndex > 0;
  bool get isEmpty => tracks.isEmpty;
  int get length => tracks.length;

  QueueState copyWith({
    List<Track>? tracks,
    int? currentIndex,
    List<Track>? originalOrder,
    bool? isShuffled,
  }) {
    return QueueState(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      originalOrder: originalOrder ?? this.originalOrder,
      isShuffled: isShuffled ?? this.isShuffled,
    );
  }
}

/// Manages the playback queue.
class QueueNotifier extends StateNotifier<QueueState> {
  QueueNotifier(this._audioService, this._playbackNotifier) : super(const QueueState());

  final AudioService _audioService;
  final PlaybackStateNotifier _playbackNotifier;
  final _random = Random();

  /// Set the queue and start playing at the given index.
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    state = QueueState(
      tracks: tracks,
      currentIndex: startIndex,
      originalOrder: List.of(tracks),
    );
    await _playCurrentTrack();
  }

  /// Add a track to play next (after current).
  void playNext(Track track) {
    final newTracks = List<Track>.of(state.tracks);
    final insertAt = state.currentIndex + 1;
    newTracks.insert(insertAt.clamp(0, newTracks.length), track);
    state = state.copyWith(tracks: newTracks);
  }

  /// Add a track to the end of the queue.
  void playLater(Track track) {
    state = state.copyWith(tracks: [...state.tracks, track]);
  }

  /// Skip to the next track.
  Future<void> next() async {
    if (!state.hasNext) {
      // Check repeat mode
      final repeat = _playbackNotifier.state.repeat;
      if (repeat == RepeatMode.all && state.tracks.isNotEmpty) {
        state = state.copyWith(currentIndex: 0);
        await _playCurrentTrack();
      }
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
    await _playCurrentTrack();
  }

  /// Go to the previous track.
  Future<void> previous() async {
    // If we're more than 3 seconds in, restart the current track
    if (_playbackNotifier.state.positionMs > 3000) {
      await _audioService.seek(0);
      return;
    }
    if (!state.hasPrevious) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
    await _playCurrentTrack();
  }

  /// Jump to a specific index in the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.tracks.length) return;
    state = state.copyWith(currentIndex: index);
    await _playCurrentTrack();
  }

  /// Remove a track from the queue by index.
  void removeAt(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    final newTracks = List<Track>.of(state.tracks)..removeAt(index);
    var newIndex = state.currentIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex) {
      // Current track removed — stay at same index (next track slides in)
      newIndex = newIndex.clamp(0, newTracks.length - 1);
    }
    state = state.copyWith(tracks: newTracks, currentIndex: newIndex);
  }

  /// Reorder a track in the queue (drag-and-drop).
  void reorder(int oldIndex, int newIndex) {
    final newTracks = List<Track>.of(state.tracks);
    final track = newTracks.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex--;
    newTracks.insert(newIndex, track);

    // Adjust current index
    var idx = state.currentIndex;
    if (oldIndex == idx) {
      idx = newIndex;
    } else {
      if (oldIndex < idx) idx--;
      if (newIndex <= idx) idx++;
    }

    state = state.copyWith(tracks: newTracks, currentIndex: idx);
  }

  /// Toggle shuffle. Fisher-Yates shuffle, keeping current track at index 0.
  void toggleShuffle() {
    if (state.isShuffled) {
      // Unshuffle: restore original order
      final current = state.currentTrack;
      final originalIndex = current != null
          ? state.originalOrder.indexWhere((t) => t.filePath == current.filePath)
          : 0;
      state = state.copyWith(
        tracks: List.of(state.originalOrder),
        currentIndex: originalIndex.clamp(0, state.originalOrder.length - 1),
        isShuffled: false,
      );
    } else {
      // Shuffle: Fisher-Yates, pin current track to front
      final shuffled = List<Track>.of(state.tracks);
      final current = state.currentTrack;

      // Remove current track, shuffle the rest, put current at front
      if (current != null && shuffled.isNotEmpty) {
        shuffled.removeAt(state.currentIndex);
        for (var i = shuffled.length - 1; i > 0; i--) {
          final j = _random.nextInt(i + 1);
          final temp = shuffled[i];
          shuffled[i] = shuffled[j];
          shuffled[j] = temp;
        }
        shuffled.insert(0, current);
      }

      state = state.copyWith(
        tracks: shuffled,
        currentIndex: 0,
        isShuffled: true,
      );
    }
    _playbackNotifier.toggleShuffle();
  }

  /// Clear the queue.
  void clear() {
    state = const QueueState();
  }

  Future<void> _playCurrentTrack() async {
    final track = state.currentTrack;
    if (track?.filePath == null) return;
    final info = await _audioService.load(track!.filePath!);
    _playbackNotifier.updateTrack(info);

    // Preload next for gapless
    if (state.hasNext) {
      final nextTrack = state.tracks[state.currentIndex + 1];
      if (nextTrack.filePath != null) {
        await _audioService.preloadNext(nextTrack.filePath!);
      }
    }
  }
}

final queueProvider = StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  return QueueNotifier(
    ref.watch(audioServiceProvider),
    ref.read(playbackStateProvider.notifier),
  );
});
