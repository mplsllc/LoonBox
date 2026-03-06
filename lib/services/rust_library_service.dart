import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as rust;
import 'library_service.dart';

/// Concrete LibraryService backed by the Rust FFI bridge.
class RustLibraryService implements LibraryService {
  @override
  Stream<ScanEvent> scanDirectory(String path, {bool recursive = true}) async* {
    // The Rust scan is blocking, so run it and then stream results.
    final events = await rust.libraryScan(path: path, recursive: recursive);
    for (final event in events) {
      yield _convertScanEvent(event);
    }
  }

  @override
  Stream<FileChangeEvent> watchDirectory(String path) async* {
    final watcherId = await rust.watcherStart(path: path, recursive: true);
    try {
      while (true) {
        final events = await rust.watcherPollEvents(watcherId: watcherId);
        for (final event in events) {
          yield _convertFileChangeEvent(event);
        }
        // Poll every 500ms
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      await rust.watcherStop(watcherId: watcherId);
    }
  }

  /// Read metadata for a single file.
  Future<TrackMetadata> readMetadata(String path) async {
    final meta = await rust.metadataRead(path: path);
    return _convertMetadata(meta);
  }

  /// Read album art bytes for a track.
  Future<List<int>?> readAlbumArt(String path) async {
    return await rust.metadataReadAlbumArt(path: path);
  }

  /// Stop all active file watchers.
  Future<void> stopAllWatchers() async {
    await rust.watcherStopAll();
  }
}

ScanEvent _convertScanEvent(rust.ScanEvent event) {
  return switch (event) {
    rust.ScanEvent_Found(:final field0) => ScanFoundEvent(_convertMetadata(field0)),
    rust.ScanEvent_Progress(:final scanned, :final total) =>
      ScanProgressEvent(scanned: scanned, total: total),
    rust.ScanEvent_Complete(:final total, :final durationMs) =>
      ScanCompleteEvent(total: total, durationMs: durationMs.toInt()),
    rust.ScanEvent_Error(:final path, :final error) =>
      ScanErrorEvent(path: path, error: error),
  };
}

FileChangeEvent _convertFileChangeEvent(rust.FileChangeEvent event) {
  return switch (event) {
    rust.FileChangeEvent_Added(:final field0) => FileAddedEvent(field0),
    rust.FileChangeEvent_Removed(:final field0) => FileRemovedEvent(field0),
    rust.FileChangeEvent_Modified(:final field0) => FileModifiedEvent(field0),
    rust.FileChangeEvent_Renamed(:final oldPath, :final newPath) =>
      FileRenamedEvent(oldPath: oldPath, newPath: newPath),
  };
}

TrackMetadata _convertMetadata(rust.TrackMetadata meta) {
  return TrackMetadata(
    path: meta.path,
    title: meta.title,
    artist: meta.artist,
    albumArtist: meta.albumArtist,
    album: meta.album,
    trackNumber: meta.trackNumber,
    discNumber: meta.discNumber,
    year: meta.year,
    genre: meta.genre,
    durationMs: meta.durationMs?.toInt(),
    hasAlbumArt: meta.hasAlbumArt,
    fileSize: meta.fileSize.toInt(),
    sampleRate: meta.sampleRate,
    bitDepth: meta.bitDepth,
    channels: meta.channels,
    codec: meta.codec,
    musicbrainzTrackId: meta.musicbrainzTrackId,
    musicbrainzArtistId: meta.musicbrainzArtistId,
    replayGainTrack: meta.replayGainTrack,
    replayGainAlbum: meta.replayGainAlbum,
  );
}

/// Riverpod provider for the library service.
final libraryServiceProvider = Provider<RustLibraryService>((ref) {
  return RustLibraryService();
});
