/// System notification and media control integration.
/// Handles SMTC (Windows), MPRIS (Linux), MPNowPlayingInfoCenter (macOS).
abstract class NotificationService {
  Future<void> updateNowPlaying({
    required String title,
    required String artist,
    String? album,
    String? artPath,
    int? durationMs,
    int? positionMs,
    bool isPlaying = false,
  });

  Future<void> clearNowPlaying();

  /// Stream of transport commands from the OS (play, pause, next, prev).
  Stream<MediaCommand> get commands;
}

enum MediaCommand {
  play,
  pause,
  togglePlayPause,
  next,
  previous,
  stop,
}
