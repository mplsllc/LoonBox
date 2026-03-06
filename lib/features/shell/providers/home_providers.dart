import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';

/// Reasons a "Discover" album is surfaced.
enum DiscoverReason { forgotten, neverPlayed }

/// An album with a representative track path for album art.
class AlbumWithArt {
  const AlbumWithArt({required this.album, this.trackPath});
  final Album album;
  final String? trackPath;
}

/// Recently played album with timestamp.
class RecentAlbum {
  const RecentAlbum({required this.album, this.trackPath, required this.lastPlayedAt});
  final Album album;
  final String? trackPath;
  final int lastPlayedAt;
}

/// Top album by aggregate play count.
class TopAlbum {
  const TopAlbum({required this.album, this.trackPath, required this.totalPlayCount});
  final Album album;
  final String? trackPath;
  final int totalPlayCount;
}

/// Album surfaced for discovery with a reason.
class DiscoverAlbum {
  const DiscoverAlbum({required this.album, this.trackPath, required this.reason});
  final Album album;
  final String? trackPath;
  final DiscoverReason reason;
}

/// All data needed by the Home page, fetched in a single batched provider.
class HomeData {
  const HomeData({
    required this.totalTracks,
    required this.totalAlbums,
    required this.totalArtists,
    required this.totalDurationMs,
    required this.totalListeningTimeMs,
    required this.listeningTimeThisWeekMs,
    required this.listeningTimeLastWeekMs,
    required this.longestStreakDays,
    this.topArtistThisMonth,
    required this.topArtistThisMonthPlays,
    required this.recentlyPlayed,
    required this.recentlyAdded,
    required this.topAlbums,
    required this.jumpBackIn,
    required this.discover,
  });

  // Collection stats
  final int totalTracks;
  final int totalAlbums;
  final int totalArtists;
  final int totalDurationMs;

  // Listening insights
  final int totalListeningTimeMs;
  final int listeningTimeThisWeekMs;
  final int listeningTimeLastWeekMs;
  final int longestStreakDays;
  final String? topArtistThisMonth;
  final int topArtistThisMonthPlays;

  // Content sections
  final List<RecentAlbum> recentlyPlayed;
  final List<AlbumWithArt> recentlyAdded;
  final List<TopAlbum> topAlbums;
  final List<Track> jumpBackIn;
  final List<DiscoverAlbum> discover;

  bool get hasPlayHistory => totalListeningTimeMs > 0;
}

/// Batched provider that fetches all home page data via Future.wait.
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  final weekAgo = now - const Duration(days: 7).inMilliseconds;
  final twoWeeksAgo = now - const Duration(days: 14).inMilliseconds;
  final monthAgo = now - const Duration(days: 30).inMilliseconds;

  final results = await Future.wait([
    // 0: Collection stats
    db.customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM tracks) AS track_count, '
      '(SELECT COUNT(*) FROM albums) AS album_count, '
      '(SELECT COUNT(*) FROM artists) AS artist_count, '
      '(SELECT COALESCE(SUM(duration_ms), 0) FROM tracks) AS total_duration',
    ).getSingle(),

    // 1: Total listening time (all-time)
    db.customSelect(
      'SELECT COALESCE(SUM(duration_listened_ms), 0) AS total '
      'FROM play_history',
    ).getSingle(),

    // 2: Listening time this week
    db.customSelect(
      'SELECT COALESCE(SUM(duration_listened_ms), 0) AS total '
      'FROM play_history WHERE played_at >= ?',
      variables: [Variable.withInt(weekAgo)],
    ).getSingle(),

    // 3: Listening time last week
    db.customSelect(
      'SELECT COALESCE(SUM(duration_listened_ms), 0) AS total '
      'FROM play_history WHERE played_at >= ? AND played_at < ?',
      variables: [Variable.withInt(twoWeeksAgo), Variable.withInt(weekAgo)],
    ).getSingle(),

    // 4: Distinct play dates for streak calculation
    db.customSelect(
      "SELECT DISTINCT date(played_at / 1000, 'unixepoch') AS d "
      'FROM play_history WHERE completed = 1 ORDER BY d',
    ).get(),

    // 5: Top artist this month
    db.customSelect(
      'SELECT t.artist, COUNT(*) AS plays '
      'FROM play_history ph JOIN tracks t ON ph.track_id = t.id '
      'WHERE ph.played_at >= ? AND t.artist IS NOT NULL '
      'GROUP BY t.artist ORDER BY plays DESC LIMIT 1',
      variables: [Variable.withInt(monthAgo)],
    ).get(),

    // 6: Recently played albums (from play_history)
    db.customSelect(
      'SELECT a.*, MAX(ph.played_at) AS last_played, '
      '(SELECT t2.file_path FROM tracks t2 WHERE t2.album = a.name LIMIT 1) AS track_path '
      'FROM play_history ph '
      'JOIN tracks t ON ph.track_id = t.id '
      'JOIN albums a ON a.name = t.album '
      'GROUP BY a.id ORDER BY last_played DESC LIMIT 10',
    ).get(),

    // 7: Recently added albums
    db.customSelect(
      'SELECT a.*, '
      '(SELECT t2.file_path FROM tracks t2 WHERE t2.album = a.name LIMIT 1) AS track_path '
      'FROM albums a WHERE a.date_added IS NOT NULL '
      'ORDER BY a.date_added DESC LIMIT 10',
    ).get(),

    // 8: Top albums by aggregate play count
    db.customSelect(
      'SELECT a.*, SUM(t.play_count) AS total_plays, '
      '(SELECT t2.file_path FROM tracks t2 WHERE t2.album = a.name LIMIT 1) AS track_path '
      'FROM albums a JOIN tracks t ON t.album = a.name '
      'WHERE t.play_count > 0 '
      'GROUP BY a.id ORDER BY total_plays DESC LIMIT 10',
    ).get(),

    // 9: Jump back in — recent individual tracks
    db.customSelect(
      'SELECT t.* FROM play_history ph '
      'JOIN tracks t ON ph.track_id = t.id '
      'GROUP BY t.id ORDER BY MAX(ph.played_at) DESC LIMIT 10',
    ).get(),

    // 10: Discover — forgotten albums (last played > 6 months ago, has plays)
    db.customSelect(
      'SELECT a.*, MAX(t.last_played_at) AS lp, '
      '(SELECT t2.file_path FROM tracks t2 WHERE t2.album = a.name LIMIT 1) AS track_path '
      'FROM albums a JOIN tracks t ON t.album = a.name '
      'WHERE t.play_count > 0 AND t.last_played_at < ? '
      'GROUP BY a.id ORDER BY lp ASC LIMIT 3',
      variables: [Variable.withInt(now - const Duration(days: 180).inMilliseconds)],
    ).get(),

    // 11: Discover — never played albums
    db.customSelect(
      'SELECT a.*, '
      '(SELECT t2.file_path FROM tracks t2 WHERE t2.album = a.name LIMIT 1) AS track_path '
      'FROM albums a WHERE NOT EXISTS ('
      '  SELECT 1 FROM tracks t WHERE t.album = a.name AND t.play_count > 0'
      ') AND EXISTS ('
      '  SELECT 1 FROM tracks t WHERE t.album = a.name'
      ') ORDER BY RANDOM() LIMIT 3',
    ).get(),
  ]);

  // Parse collection stats
  final stats = results[0] as QueryRow;
  final totalTracks = stats.read<int>('track_count');
  final totalAlbums = stats.read<int>('album_count');
  final totalArtists = stats.read<int>('artist_count');
  final totalDurationMs = stats.read<int>('total_duration');

  // Parse listening times
  final totalListening = (results[1] as QueryRow).read<int>('total');
  final thisWeekListening = (results[2] as QueryRow).read<int>('total');
  final lastWeekListening = (results[3] as QueryRow).read<int>('total');

  // Calculate longest streak
  final dateRows = results[4] as List<QueryRow>;
  final longestStreak = _calculateLongestStreak(dateRows);

  // Top artist
  final topArtistRows = results[5] as List<QueryRow>;
  String? topArtist;
  int topArtistPlays = 0;
  if (topArtistRows.isNotEmpty) {
    topArtist = topArtistRows.first.read<String>('artist');
    topArtistPlays = topArtistRows.first.read<int>('plays');
  }

  // Recently played albums
  final recentPlayedRows = results[6] as List<QueryRow>;
  final recentlyPlayed = recentPlayedRows.map((r) => RecentAlbum(
    album: _albumFromRow(r),
    trackPath: r.readNullable<String>('track_path'),
    lastPlayedAt: r.read<int>('last_played'),
  )).toList();

  // Recently added albums
  final recentAddedRows = results[7] as List<QueryRow>;
  final recentlyAdded = recentAddedRows.map((r) => AlbumWithArt(
    album: _albumFromRow(r),
    trackPath: r.readNullable<String>('track_path'),
  )).toList();

  // Top albums
  final topAlbumRows = results[8] as List<QueryRow>;
  final topAlbums = topAlbumRows.map((r) => TopAlbum(
    album: _albumFromRow(r),
    trackPath: r.readNullable<String>('track_path'),
    totalPlayCount: r.read<int>('total_plays'),
  )).toList();

  // Jump back in tracks
  final jumpBackInRows = results[9] as List<QueryRow>;
  final jumpBackIn = jumpBackInRows.map((r) => _trackFromRow(r)).toList();

  // Discover albums
  final forgottenRows = results[10] as List<QueryRow>;
  final neverPlayedRows = results[11] as List<QueryRow>;
  final discover = <DiscoverAlbum>[
    ...forgottenRows.map((r) => DiscoverAlbum(
      album: _albumFromRow(r),
      trackPath: r.readNullable<String>('track_path'),
      reason: DiscoverReason.forgotten,
    )),
    ...neverPlayedRows.map((r) => DiscoverAlbum(
      album: _albumFromRow(r),
      trackPath: r.readNullable<String>('track_path'),
      reason: DiscoverReason.neverPlayed,
    )),
  ];

  return HomeData(
    totalTracks: totalTracks,
    totalAlbums: totalAlbums,
    totalArtists: totalArtists,
    totalDurationMs: totalDurationMs,
    totalListeningTimeMs: totalListening,
    listeningTimeThisWeekMs: thisWeekListening,
    listeningTimeLastWeekMs: lastWeekListening,
    longestStreakDays: longestStreak,
    topArtistThisMonth: topArtist,
    topArtistThisMonthPlays: topArtistPlays,
    recentlyPlayed: recentlyPlayed,
    recentlyAdded: recentlyAdded,
    topAlbums: topAlbums,
    jumpBackIn: jumpBackIn,
    discover: discover,
  );
});

/// Calculate longest streak of consecutive days from date strings.
int _calculateLongestStreak(List<QueryRow> dateRows) {
  if (dateRows.isEmpty) return 0;

  final dates = dateRows
      .map((r) => r.read<String>('d'))
      .map((s) => DateTime.parse(s))
      .toList();

  int maxStreak = 1;
  int currentStreak = 1;

  for (int i = 1; i < dates.length; i++) {
    final diff = dates[i].difference(dates[i - 1]).inDays;
    if (diff == 1) {
      currentStreak++;
      if (currentStreak > maxStreak) maxStreak = currentStreak;
    } else {
      currentStreak = 1;
    }
  }

  return maxStreak;
}

/// Reconstruct an Album from a custom query row.
Album _albumFromRow(QueryRow r) {
  return Album(
    id: r.read<int>('id'),
    name: r.read<String>('name'),
    artist: r.readNullable<String>('artist'),
    year: r.readNullable<int>('year'),
    trackCount: r.readNullable<int>('track_count'),
    durationMs: r.readNullable<int>('duration_ms'),
    artPath: r.readNullable<String>('art_path'),
    dateAdded: r.readNullable<int>('date_added'),
    source: r.read<String>('source'),
    sourceId: r.readNullable<String>('source_id'),
  );
}

/// Reconstruct a Track from a custom query row.
Track _trackFromRow(QueryRow r) {
  return Track(
    id: r.read<int>('id'),
    source: r.read<String>('source'),
    sourceId: r.readNullable<String>('source_id'),
    filePath: r.readNullable<String>('file_path'),
    fileSize: r.readNullable<int>('file_size'),
    fileModifiedAt: r.readNullable<int>('file_modified_at'),
    title: r.read<String>('title'),
    artist: r.readNullable<String>('artist'),
    albumArtist: r.readNullable<String>('album_artist'),
    album: r.readNullable<String>('album'),
    genre: r.readNullable<String>('genre'),
    year: r.readNullable<int>('year'),
    trackNumber: r.readNullable<int>('track_number'),
    discNumber: r.readNullable<int>('disc_number'),
    durationMs: r.readNullable<int>('duration_ms'),
    comment: r.readNullable<String>('comment'),
    composer: r.readNullable<String>('composer'),
    lyrics: r.readNullable<String>('lyrics'),
    codec: r.readNullable<String>('codec'),
    bitrate: r.readNullable<int>('bitrate'),
    sampleRate: r.readNullable<int>('sample_rate'),
    bitDepth: r.readNullable<int>('bit_depth'),
    channels: r.readNullable<int>('channels'),
    hasAlbumArt: r.read<bool>('has_album_art'),
    albumArtHash: r.readNullable<String>('album_art_hash'),
    playCount: r.read<int>('play_count'),
    skipCount: r.read<int>('skip_count'),
    lastPlayedAt: r.readNullable<int>('last_played_at'),
    lastSkippedAt: r.readNullable<int>('last_skipped_at'),
    rating: r.read<int>('rating'),
    loved: r.read<bool>('loved'),
    dateAdded: r.read<int>('date_added'),
    musicbrainzTrackId: r.readNullable<String>('musicbrainz_track_id'),
    musicbrainzArtistId: r.readNullable<String>('musicbrainz_artist_id'),
    musicbrainzReleaseId: r.readNullable<String>('musicbrainz_release_id'),
    replayGainTrack: r.readNullable<double>('replay_gain_track'),
    replayGainAlbum: r.readNullable<double>('replay_gain_album'),
    bpm: r.readNullable<double>('bpm'),
    loudnessLufs: r.readNullable<double>('loudness_lufs'),
    titleSort: r.readNullable<String>('title_sort'),
    artistSort: r.readNullable<String>('artist_sort'),
    albumSort: r.readNullable<String>('album_sort'),
  );
}
