import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../src/rust/api.dart' as rust;

/// Caches album art extracted from audio files to disk.
class AlbumArtService {
  String? _cacheDir;

  Future<String> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'album_art'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir.path;
    return _cacheDir!;
  }

  /// Get album art for a track. Returns the cached file path, or null.
  ///
  /// Lookup order:
  /// 1. Already cached on disk (by hash of track path)
  /// 2. Embedded in audio file tags
  /// 3. File-based art in the same directory (cover.jpg, folder.png, etc.)
  Future<String?> getArtPath(String trackPath) async {
    final cacheDir = await _ensureCacheDir();
    final hash = trackPath.hashCode.toRadixString(16);
    final cachedPath = p.join(cacheDir, '$hash.jpg');

    // 1. Already cached
    if (File(cachedPath).existsSync()) {
      return cachedPath;
    }

    // 2. Try embedded art
    final embeddedBytes = await rust.metadataReadAlbumArt(path: trackPath);
    if (embeddedBytes != null && embeddedBytes.isNotEmpty) {
      await File(cachedPath).writeAsBytes(embeddedBytes);
      return cachedPath;
    }

    // 3. Try file-based art
    final fileArt = await rust.metadataFindFileArt(trackPath: trackPath);
    if (fileArt != null) {
      // Copy to cache (or just return the path directly)
      return fileArt;
    }

    return null;
  }

  /// Get album art bytes directly (for display without caching).
  Future<Uint8List?> getArtBytes(String trackPath) async {
    return await rust.metadataReadAlbumArt(path: trackPath);
  }

  /// Clear the album art cache.
  Future<void> clearCache() async {
    final cacheDir = await _ensureCacheDir();
    final dir = Directory(cacheDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
  }
}

final albumArtServiceProvider = Provider<AlbumArtService>((ref) {
  return AlbumArtService();
});
