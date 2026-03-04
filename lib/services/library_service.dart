import '../features/library/domain/track.dart';

/// Scan events streamed from Rust during library import.
sealed class ScanEvent {
  const ScanEvent();
}

class ScanFoundEvent extends ScanEvent {
  const ScanFoundEvent(this.metadata);
  final TrackMetadata metadata;
}

class ScanProgressEvent extends ScanEvent {
  const ScanProgressEvent({required this.scanned, required this.total});
  final int scanned;
  final int total;
}

class ScanCompleteEvent extends ScanEvent {
  const ScanCompleteEvent({required this.total, required this.durationMs});
  final int total;
  final int durationMs;
}

class ScanErrorEvent extends ScanEvent {
  const ScanErrorEvent({required this.path, required this.error});
  final String path;
  final String error;
}

/// Metadata from the Rust scanner (mirrors Rust TrackMetadata).
class TrackMetadata {
  const TrackMetadata({
    required this.path,
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.durationMs,
    this.hasAlbumArt = false,
    this.fileSize = 0,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.codec,
    this.musicbrainzTrackId,
    this.musicbrainzArtistId,
    this.replayGainTrack,
    this.replayGainAlbum,
  });

  final String path;
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int? durationMs;
  final bool hasAlbumArt;
  final int fileSize;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;
  final String? codec;
  final String? musicbrainzTrackId;
  final String? musicbrainzArtistId;
  final double? replayGainTrack;
  final double? replayGainAlbum;

  /// Convert to a Track domain object for database insertion.
  Track toTrack() => Track(
        title: title ?? path.split('/').last.split('\\').last,
        filePath: path,
        fileSize: fileSize,
        artist: artist,
        albumArtist: albumArtist,
        album: album,
        trackNumber: trackNumber,
        discNumber: discNumber,
        year: year,
        genre: genre,
        durationMs: durationMs,
        hasAlbumArt: hasAlbumArt,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        channels: channels,
        codec: codec,
        musicbrainzTrackId: musicbrainzTrackId,
        musicbrainzArtistId: musicbrainzArtistId,
        replayGainTrack: replayGainTrack,
        replayGainAlbum: replayGainAlbum,
        dateAdded: DateTime.now(),
      );
}

/// Service for library scanning and watch folder management.
abstract class LibraryService {
  /// Scan a directory, streaming results back.
  Stream<ScanEvent> scanDirectory(String path, {bool recursive = true});

  /// Watch a directory for file changes.
  Stream<FileChangeEvent> watchDirectory(String path);
}

/// File change events from the watch folder.
sealed class FileChangeEvent {
  const FileChangeEvent();
}

class FileAddedEvent extends FileChangeEvent {
  const FileAddedEvent(this.path);
  final String path;
}

class FileRemovedEvent extends FileChangeEvent {
  const FileRemovedEvent(this.path);
  final String path;
}

class FileModifiedEvent extends FileChangeEvent {
  const FileModifiedEvent(this.path);
  final String path;
}

class FileRenamedEvent extends FileChangeEvent {
  const FileRenamedEvent({required this.oldPath, required this.newPath});
  final String oldPath;
  final String newPath;
}
