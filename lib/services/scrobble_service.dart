/// Scrobbling service interface (Last.fm, ListenBrainz).
abstract class ScrobbleService {
  Future<bool> authenticate(String provider);
  Future<void> logout(String provider);
  Future<void> scrobble({
    required String title,
    required String artist,
    String? album,
    int? durationMs,
  });
  Future<void> updateNowPlaying({
    required String title,
    required String artist,
    String? album,
  });
  bool isAuthenticated(String provider);
}
