import 'dart:async';
import 'dart:io' show File;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../services/library_service.dart';
import '../../../services/rust_library_service.dart';

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
  Future<void> _upsertTrack(TrackMetadata meta) async {
    final track = meta.toTrack();

    // Upsert the track by file path (unique constraint)
    await _db.into(_db.tracks).insertOnConflictUpdate(
          TracksCompanion.insert(
            title: track.title,
            filePath: Value(track.filePath),
            fileSize: Value(track.fileSize),
            artist: Value(track.artist),
            albumArtist: Value(track.albumArtist),
            album: Value(track.album),
            genre: Value(track.genre),
            year: Value(track.year),
            trackNumber: Value(track.trackNumber),
            discNumber: Value(track.discNumber),
            durationMs: Value(track.durationMs),
            codec: Value(track.codec),
            sampleRate: Value(track.sampleRate),
            bitDepth: Value(track.bitDepth),
            channels: Value(track.channels),
            hasAlbumArt: Value(track.hasAlbumArt),
            musicbrainzTrackId: Value(track.musicbrainzTrackId),
            musicbrainzArtistId: Value(track.musicbrainzArtistId),
            replayGainTrack: Value(track.replayGainTrack),
            replayGainAlbum: Value(track.replayGainAlbum),
            dateAdded: DateTime.now().millisecondsSinceEpoch,
          ),
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
  Future<void> _ensureAlbum(String name, {String? artist, int? year}) async {
    final existing = await (_db.select(_db.albums)
          ..where((a) =>
              a.name.equals(name) &
              a.artist.equalsNullable(artist) &
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
