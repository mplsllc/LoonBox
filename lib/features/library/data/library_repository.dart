import 'dart:async';
import 'dart:io' show File;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../services/library_service.dart';
import '../../../services/metadata_resolver.dart';
import '../../../services/musicbrainz_service.dart';
import '../../../services/rust_library_service.dart';
import '../../../utils/string_utils.dart';

/// Scan progress state exposed to the UI.
class ScanProgress {
  const ScanProgress({
    this.isScanning = false,
    this.scanned = 0,
    this.total = 0,
    this.errors = const [],
    this.lastCompleteDurationMs,
  });

  final bool isScanning;
  final int scanned;
  final int total;
  final List<String> errors;
  final int? lastCompleteDurationMs;

  double get progress => total > 0 ? scanned / total : 0.0;
}

/// Repository that orchestrates scanning directories and writing to the DB.
class LibraryRepository {
  LibraryRepository(this._db, this._libraryService);

  final LoonBoxDatabase _db;
  final RustLibraryService _libraryService;

  /// Scan a directory and upsert all found tracks into the database.
  /// Returns a stream of progress updates.
  Stream<ScanProgress> scanDirectory(String path, {bool recursive = true}) async* {
    final errors = <String>[];
    var scanned = 0;
    var total = 0;

    yield const ScanProgress(isScanning: true);

    await for (final event in _libraryService.scanDirectory(path, recursive: recursive)) {
      switch (event) {
        case ScanFoundEvent(:final metadata):
          await _upsertTrack(metadata);
          scanned++;
          yield ScanProgress(
            isScanning: true,
            scanned: scanned,
            total: total,
            errors: errors,
          );

        case ScanProgressEvent(total: final t):
          total = t;
          yield ScanProgress(
            isScanning: true,
            scanned: scanned,
            total: total,
            errors: errors,
          );

        case ScanCompleteEvent(:final total, :final durationMs):
          yield ScanProgress(
            isScanning: false,
            scanned: total,
            total: total,
            errors: errors,
            lastCompleteDurationMs: durationMs,
          );

        case ScanErrorEvent(:final path, :final error):
          errors.add('$path: $error');
      }
    }
  }

  /// Upsert a single track from scan metadata.
  ///
  /// Uses raw SQL with CASE WHEN to preserve overlay metadata fields
  /// when the track has a MusicBrainz ID (meaning auto-tag has matched it).
  /// File-intrinsic fields (codec, duration, sample rate, etc.) are always
  /// updated from the file. dateAdded is only set on INSERT (never reset).
  Future<void> _upsertTrack(TrackMetadata meta) async {
    final track = meta.toTrack();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.customStatement(
      '''INSERT INTO tracks (
        title, file_path, file_size, artist, album_artist, album, genre,
        year, track_number, disc_number, duration_ms, codec, sample_rate,
        bit_depth, channels, has_album_art, musicbrainz_track_id,
        musicbrainz_artist_id, replay_gain_track, replay_gain_album,
        date_added, source
      ) VALUES (
        ?1, ?2, ?3, ?4, ?5, ?6, ?7,
        ?8, ?9, ?10, ?11, ?12, ?13,
        ?14, ?15, ?16, ?17,
        ?18, ?19, ?20,
        ?21, 'local'
      )
      ON CONFLICT (file_path) DO UPDATE SET
        -- File-intrinsic fields: always update from file
        file_size = excluded.file_size,
        codec = excluded.codec,
        sample_rate = excluded.sample_rate,
        bit_depth = excluded.bit_depth,
        channels = excluded.channels,
        duration_ms = excluded.duration_ms,
        has_album_art = excluded.has_album_art,
        replay_gain_track = excluded.replay_gain_track,
        replay_gain_album = excluded.replay_gain_album,
        -- MB IDs from file: keep whichever is non-null (file or existing DB)
        musicbrainz_track_id = COALESCE(excluded.musicbrainz_track_id, tracks.musicbrainz_track_id),
        musicbrainz_artist_id = COALESCE(excluded.musicbrainz_artist_id, tracks.musicbrainz_artist_id),
        -- Metadata fields: preserve if MB-flagged, otherwise update from file
        title = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                THEN tracks.title ELSE excluded.title END,
        artist = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                 THEN tracks.artist ELSE excluded.artist END,
        album_artist = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                       THEN tracks.album_artist ELSE excluded.album_artist END,
        album = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                THEN tracks.album ELSE excluded.album END,
        genre = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                THEN tracks.genre ELSE excluded.genre END,
        year = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
               THEN tracks.year ELSE excluded.year END,
        track_number = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                       THEN tracks.track_number ELSE excluded.track_number END,
        disc_number = CASE WHEN tracks.musicbrainz_track_id IS NOT NULL
                      THEN tracks.disc_number ELSE excluded.disc_number END
        -- date_added: intentionally excluded — only set on INSERT
      ''',
      [
        track.title,         // ?1
        track.filePath,      // ?2
        track.fileSize,      // ?3
        track.artist,        // ?4
        track.albumArtist,   // ?5
        track.album,         // ?6
        track.genre,         // ?7
        track.year,          // ?8
        track.trackNumber,   // ?9
        track.discNumber,    // ?10
        track.durationMs,    // ?11
        track.codec,         // ?12
        track.sampleRate,    // ?13
        track.bitDepth,      // ?14
        track.channels,      // ?15
        track.hasAlbumArt ? 1 : 0, // ?16
        track.musicbrainzTrackId,  // ?17
        track.musicbrainzArtistId, // ?18
        track.replayGainTrack,     // ?19
        track.replayGainAlbum,     // ?20
        now,                       // ?21
      ],
    );

    // Ensure artist exists
    if (track.artist != null) {
      await _ensureArtist(track.artist!);
    }
    if (track.albumArtist != null && track.albumArtist != track.artist) {
      await _ensureArtist(track.albumArtist!);
    }

    // Ensure album exists
    if (track.album != null) {
      await _ensureAlbum(
        track.album!,
        artist: track.albumArtist ?? track.artist,
        year: track.year,
      );
    }
  }

  /// Create artist if not already in DB.
  Future<void> _ensureArtist(String name) async {
    final existing = await (_db.select(_db.artists)
          ..where((a) => a.name.equals(name) & a.source.equals('local')))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.artists).insert(
            ArtistsCompanion.insert(name: name),
          );
    }
  }

  /// Create album if not already in DB.
  /// Matches by name + source only — different track artists on the same album
  /// won't create duplicate entries.
  Future<void> _ensureAlbum(String name, {String? artist, int? year}) async {
    final existing = await (_db.select(_db.albums)
          ..where((a) =>
              a.name.equals(name) &
              a.source.equals('local')))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.albums).insert(
            AlbumsCompanion.insert(
              name: name,
              artist: Value(artist),
              year: Value(year),
              dateAdded: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
    } else if (existing.artist == null && artist != null) {
      // Fill in artist if it was missing on the existing entry
      await (_db.update(_db.albums)..where((a) => a.id.equals(existing.id)))
          .write(AlbumsCompanion(artist: Value(artist)));
    }
  }

  /// Add a watch directory to the database.
  Future<void> addWatchDirectory(String path, {bool recursive = true}) async {
    await _db.into(_db.watchDirectories).insertOnConflictUpdate(
          WatchDirectoriesCompanion.insert(
            path: path,
            recursive: Value(recursive),
          ),
        );
  }

  /// Remove a watch directory.
  Future<void> removeWatchDirectory(int id) async {
    await (_db.delete(_db.watchDirectories)..where((d) => d.id.equals(id))).go();
  }

  /// Get all watch directories.
  Future<List<WatchDirectory>> getWatchDirectories() {
    return _db.select(_db.watchDirectories).get();
  }

  /// Get all watch directories as a live stream.
  Stream<List<WatchDirectory>> watchWatchDirectories() {
    return _db.select(_db.watchDirectories).watch();
  }

  /// Remove tracks whose files no longer exist on disk.
  Future<int> cleanMissingTracks() async {
    final allTracks = await (_db.select(_db.tracks)
          ..where((t) => t.source.equals('local')))
        .get();

    var removed = 0;
    for (final track in allTracks) {
      if (track.filePath != null && !File(track.filePath!).existsSync()) {
        await (_db.delete(_db.tracks)..where((t) => t.id.equals(track.id))).go();
        removed++;
      }
    }
    return removed;
  }

  /// Apply cached MB metadata to albums that lack MB IDs.
  /// Runs after library scan — no network calls, only local cache lookups.
  /// Uses strict matching: position match requires title confirmation,
  /// otherwise falls back to title-only match.
  Future<int> enrichFromCache(TieredMetadataResolver resolver) async {
    var enriched = 0;

    final albums = await _db.select(_db.albums).get();

    for (final album in albums) {
      // Find tracks in this album that lack MB IDs
      final tracks = await (_db.select(_db.tracks)
            ..where((t) => t.album.equals(album.name))
            ..where((t) => t.musicbrainzTrackId.isNull())
            ..where((t) => t.musicbrainzReleaseId.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.discNumber),
              (t) => OrderingTerm.asc(t.trackNumber),
            ]))
          .get();

      if (tracks.isEmpty) continue;

      final cachedRelease = await resolver.getCachedReleaseForAlbum(
        album.name,
        album.artist,
      );
      if (cachedRelease == null) continue;

      final mbTracks = List<MusicBrainzRecording>.from(cachedRelease.tracks);
      final matched = <MusicBrainzRecording>{};
      var matchedAny = false;

      await _db.transaction(() async {
        for (final track in tracks) {
          MusicBrainzRecording? best;
          final localNorm = normalizeTitle(track.title);

          // Strategy 1: Position match with title verification
          if (track.trackNumber != null) {
            final positional = mbTracks.where(
              (mb) => mb.trackNumber == track.trackNumber && !matched.contains(mb),
            );
            if (positional.isNotEmpty) {
              final candidate = positional.first;
              // Require title agreement — skip if position matches but title doesn't
              if (normalizeTitle(candidate.title) == localNorm) {
                best = candidate;
              }
              // Position matched but title disagreed → do NOT fall through to
              // title-only search. This prevents cross-matching on multi-disc
              // releases where track numbers repeat.
            }
          }

          // Strategy 2: Title-only match (only if no position match was attempted)
          if (best == null && track.trackNumber == null) {
            for (final mb in mbTracks) {
              if (matched.contains(mb)) continue;
              if (normalizeTitle(mb.title) == localNorm) {
                best = mb;
                break;
              }
            }
          }

          if (best == null) continue;
          matched.add(best);

          // Write MB IDs only — no metadata overlay (conservative)
          await (_db.update(_db.tracks)..where((t) => t.id.equals(track.id)))
              .write(TracksCompanion(
            musicbrainzTrackId: Value(best.id),
            musicbrainzArtistId: Value(best.artistId),
            musicbrainzReleaseId: Value(best.releaseId),
          ));
          matchedAny = true;
        }
      });

      if (matchedAny) {
        enriched++;
        debugPrint('[Enrichment] Applied cached MB IDs to '
            '${matched.length}/${tracks.length} tracks in "${album.name}"');
      }
    }

    return enriched;
  }

  /// Re-scan all watch directories.
  Stream<ScanProgress> rescanAll() async* {
    final dirs = await getWatchDirectories();
    for (final dir in dirs) {
      if (!dir.enabled) continue;
      yield* scanDirectory(dir.path, recursive: dir.recursive);
      // Update lastScannedAt
      await (_db.update(_db.watchDirectories)
            ..where((d) => d.id.equals(dir.id)))
          .write(WatchDirectoriesCompanion(
            lastScannedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(libraryServiceProvider),
  );
});
