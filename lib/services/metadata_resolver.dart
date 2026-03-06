import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'musicbrainz_service.dart';

/// Metadata lookup service with tiered resolution.
///
/// Tier 1: Local DB — cached metadata from previous lookups.
/// Tier 2: LoonBox Community DB — shared metadata cache (stub, returns null).
/// Tier 3: MusicBrainz API — upstream source of truth.
///
/// All auto-tag and manual lookup calls go through this resolver.
/// [MusicBrainzService] is an internal detail of Tier 3.
class TieredMetadataResolver {
  final MusicBrainzService _mb;
  final LoonBoxDatabase _db;

  TieredMetadataResolver(this._mb, this._db);

  static const _cacheFreshnessDays = 30;

  // ─── Search (Tier 3 only — search is always upstream) ───────────

  Future<List<MusicBrainzRelease>> searchReleases({
    required String album,
    String? artist,
    int limit = 10,
  }) {
    return _mb.searchReleases(album: album, artist: artist, limit: limit);
  }

  Future<List<MusicBrainzRecording>> searchRecordings({
    required String title,
    String? artist,
    String? album,
    int limit = 10,
  }) {
    return _mb.searchRecordings(
      title: title,
      artist: artist,
      album: album,
      limit: limit,
    );
  }

  Future<MusicBrainzArtist?> searchArtist(String name) {
    return _mb.searchArtist(name);
  }

  // ─── Release detail (Tier 1 → Tier 2 → Tier 3) ─────────────────

  Future<MusicBrainzRelease> getRelease(String mbid) async {
    // Tier 1: check local cache
    final cached = await (_db.select(_db.metadataReleases)
          ..where((r) => r.mbReleaseId.equals(mbid)))
        .getSingleOrNull();

    if (cached != null) {
      final ageMs = DateTime.now().millisecondsSinceEpoch - cached.resolvedAt;
      if (ageMs < const Duration(days: _cacheFreshnessDays).inMilliseconds) {
        debugPrint('[MetadataResolver] Cache hit for release $mbid');
        return _releaseFromRow(cached);
      }
    }

    // Tier 2: LoonBox Community DB (stub)
    // TODO: when community DB is live, check data.loonbox.app/releases/{mbid}

    // Tier 3: MusicBrainz API
    final release = await _mb.getRelease(mbid);

    // Write-through: cache for future lookups
    await _cacheRelease(release);

    return release;
  }

  // ─── Cover art (Tier 1 → Tier 2 → Tier 3) ──────────────────────

  Future<List<int>?> resolveArt(String mbReleaseId) async {
    // Tier 1: check if we have a cached cover art path on disk
    final cached = await (_db.select(_db.metadataReleases)
          ..where((r) => r.mbReleaseId.equals(mbReleaseId)))
        .getSingleOrNull();

    if (cached?.coverArtPath != null) {
      final file = File(cached!.coverArtPath!);
      if (file.existsSync()) {
        debugPrint('[MetadataResolver] Art cache hit for $mbReleaseId');
        return file.readAsBytesSync();
      }
    }

    // Tier 2: LoonBox Community DB (stub)
    // TODO: when community DB is live, check img.loonbox.app/art/{mbReleaseId}.jpg

    // Tier 3: Cover Art Archive
    final artBytes = await _mb.downloadCoverArt(mbReleaseId);

    if (artBytes != null && artBytes.isNotEmpty) {
      debugPrint('[MetadataResolver] Art fetched from CAA for $mbReleaseId '
          '(${artBytes.length} bytes)');
      // TODO: on success, upload to community DB via Workers endpoint
    }

    return artBytes;
  }

  // ─── Album→Release mapping (for post-scan enrichment) ──────────

  /// Look up a cached release for a local album identity.
  /// Returns null if no mapping exists.
  Future<MusicBrainzRelease?> getCachedReleaseForAlbum(
    String albumName,
    String? artistName,
  ) async {
    final query = _db.select(_db.metadataReleaseMappings)
      ..where((m) => m.albumName.equals(albumName));

    if (artistName != null) {
      query.where((m) => m.artistName.equals(artistName));
    } else {
      query.where((m) => m.artistName.isNull());
    }

    final mapping = await query.getSingleOrNull();
    if (mapping == null) return null;

    final cached = await (_db.select(_db.metadataReleases)
          ..where((r) => r.mbReleaseId.equals(mapping.mbReleaseId)))
        .getSingleOrNull();

    if (cached == null) return null;
    return _releaseFromRow(cached);
  }

  // ─── Cache write methods (called by apply flows) ───────────────

  /// Cache an album→release mapping. Replaces any existing mapping for
  /// the same albumName + artistName.
  Future<void> cacheMapping({
    required String albumName,
    String? artistName,
    required String mbReleaseId,
    required int confidence,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Delete any existing mapping for this album identity, then insert.
    // Using raw SQL because Drift's insertOnConflictUpdate targets the PK,
    // not the unique key on {albumName, artistName}.
    await _db.customStatement(
      '''INSERT INTO metadata_release_mappings
         (album_name, artist_name, mb_release_id, confidence, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5)
         ON CONFLICT (album_name, artist_name) DO UPDATE SET
           mb_release_id = excluded.mb_release_id,
           confidence = excluded.confidence,
           created_at = excluded.created_at''',
      [albumName, artistName, mbReleaseId, confidence, now],
    );
  }

  /// Store the local cover art path for a cached release.
  Future<void> updateCoverArtPath(String mbReleaseId, String path) async {
    await (_db.update(_db.metadataReleases)
          ..where((r) => r.mbReleaseId.equals(mbReleaseId)))
        .write(MetadataReleasesCompanion(coverArtPath: Value(path)));
  }

  // ─── Artist detail (pass-through to Tier 3) ─────────────────────

  Future<MusicBrainzArtist> getArtist(String mbid) => _mb.getArtist(mbid);
  Future<ArtistBio?> getWikipediaBio(String url) => _mb.getWikipediaBio(url);
  Future<String?> getWikidataImage(String id) => _mb.getWikidataImage(id);

  void dispose() => _mb.dispose();

  // ─── Private helpers ────────────────────────────────────────────

  /// Serialize a MusicBrainzRelease into the cache table.
  Future<void> _cacheRelease(MusicBrainzRelease release) async {
    final tracksJson = jsonEncode(release.tracks.map((t) => {
          'mbRecordingId': t.id,
          'title': t.title,
          'artist': t.artist,
          'artistId': t.artistId,
          'trackNumber': t.trackNumber,
          'durationMs': t.durationMs,
        }).toList());

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.customStatement(
      '''INSERT INTO metadata_releases
         (mb_release_id, title, artist, mb_artist_id, year, track_count,
          tracks_json, resolved_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
         ON CONFLICT (mb_release_id) DO UPDATE SET
           title = excluded.title,
           artist = excluded.artist,
           mb_artist_id = excluded.mb_artist_id,
           year = excluded.year,
           track_count = excluded.track_count,
           tracks_json = excluded.tracks_json,
           resolved_at = excluded.resolved_at''',
      [
        release.id,
        release.title,
        release.artist,
        release.artistId,
        release.year,
        release.trackCount,
        tracksJson,
        now,
      ],
    );
  }

  /// Deserialize a cached row into a MusicBrainzRelease.
  MusicBrainzRelease _releaseFromRow(MetadataRelease row) {
    final tracksList =
        (jsonDecode(row.tracksJson) as List).map((t) {
      final m = t as Map<String, dynamic>;
      return MusicBrainzRecording(
        id: m['mbRecordingId'] as String,
        title: m['title'] as String,
        artist: m['artist'] as String?,
        artistId: m['artistId'] as String?,
        trackNumber: m['trackNumber'] as int?,
        durationMs: m['durationMs'] as int?,
        album: row.title,
        releaseId: row.mbReleaseId,
        score: 100,
      );
    }).toList();

    return MusicBrainzRelease(
      id: row.mbReleaseId,
      title: row.title,
      artist: row.artist,
      artistId: row.mbArtistId,
      year: row.year,
      trackCount: row.trackCount ?? tracksList.length,
      score: 100,
      tracks: tracksList,
    );
  }
}

final metadataResolverProvider = Provider<TieredMetadataResolver>((ref) {
  final mb = ref.read(musicBrainzServiceProvider);
  final db = ref.read(databaseProvider);
  final resolver = TieredMetadataResolver(mb, db);
  ref.onDispose(() => resolver.dispose());
  return resolver;
});
