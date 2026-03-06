import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smtc_windows/smtc_windows.dart';

import '../features/player/domain/player_state.dart';
import 'album_art_service.dart';
import 'audio_service.dart';

/// Integrates with OS media controls (Windows SMTC).
/// Handles media key presses and displays track info in the OS overlay.
class MediaControlsService {
  MediaControlsService(this._audio, this._albumArt);

  final AudioService _audio;
  final AlbumArtService _albumArt;
  SMTCWindows? _smtc;

  Future<void> init(
    void Function() onNext,
    void Function() onPrevious,
  ) async {
    if (!Platform.isWindows) return;

    _smtc = SMTCWindows(
      metadata: const MusicMetadata(
        title: '',
        album: '',
        albumArtist: '',
        artist: '',
      ),
      timeline: const PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: 0,
        positionMs: 0,
        minSeekTimeMs: 0,
        maxSeekTimeMs: 0,
      ),
    );

    _smtc!.buttonPressStream.listen((event) {
      switch (event) {
        case PressedButton.play:
          _audio.play();
        case PressedButton.pause:
          _audio.pause();
        case PressedButton.next:
          onNext();
        case PressedButton.previous:
          onPrevious();
        case PressedButton.stop:
          _audio.stop();
          _smtc?.setPlaybackStatus(PlaybackStatus.stopped);
        default:
          break;
      }
    });
  }

  /// Update the OS media overlay with current track info.
  Future<void> updateTrack({
    required String title,
    String? artist,
    String? album,
    String? filePath,
    int durationMs = 0,
  }) async {
    if (_smtc == null) return;

    String? thumbnailPath;
    if (filePath != null) {
      thumbnailPath = await _albumArt.getArtPath(filePath);
    }

    _smtc!.updateMetadata(MusicMetadata(
      title: title,
      artist: artist ?? '',
      album: album ?? '',
      albumArtist: artist ?? '',
      thumbnail: thumbnailPath != null ? 'file://$thumbnailPath' : null,
    ));

    _smtc!.updateTimeline(PlaybackTimeline(
      startTimeMs: 0,
      endTimeMs: durationMs,
      positionMs: 0,
      minSeekTimeMs: 0,
      maxSeekTimeMs: durationMs,
    ));
  }

  void updatePlaybackState(PlaybackState state) {
    if (_smtc == null) return;
    switch (state) {
      case PlaybackState.playing:
        _smtc!.setPlaybackStatus(PlaybackStatus.playing);
      case PlaybackState.paused:
        _smtc!.setPlaybackStatus(PlaybackStatus.paused);
      case PlaybackState.stopped:
      case PlaybackState.error:
        _smtc!.setPlaybackStatus(PlaybackStatus.stopped);
      case PlaybackState.loading:
        break;
    }
  }

  void updatePosition(int positionMs, int durationMs) {
    if (_smtc == null) return;
    _smtc!.updateTimeline(PlaybackTimeline(
      startTimeMs: 0,
      endTimeMs: durationMs,
      positionMs: positionMs,
      minSeekTimeMs: 0,
      maxSeekTimeMs: durationMs,
    ));
  }

  void dispose() {
    _smtc?.dispose();
  }
}

final mediaControlsServiceProvider = Provider<MediaControlsService>((ref) {
  final audio = ref.watch(audioServiceProvider);
  final albumArt = ref.watch(albumArtServiceProvider);
  final service = MediaControlsService(audio, albumArt);
  ref.onDispose(() => service.dispose());
  return service;
});
