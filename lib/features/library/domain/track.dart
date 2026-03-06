/// A track in the LoonBox library.
class Track {
  const Track({
    this.id,
    this.source = 'local',
    this.sourceId,
    this.filePath,
    this.fileSize,
    this.fileModifiedAt,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.comment,
    this.composer,
    this.lyrics,
    this.codec,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.channels,
    this.hasAlbumArt = false,
    this.albumArtHash,
    this.playCount = 0,
    this.skipCount = 0,
    this.lastPlayedAt,
    this.lastSkippedAt,
    this.rating = 0,
    this.loved = false,
    this.dateAdded,
    this.musicbrainzTrackId,
    this.musicbrainzArtistId,
    this.musicbrainzReleaseId,
    this.replayGainTrack,
    this.replayGainAlbum,
    this.bpm,
    this.loudnessLufs,
    this.titleSort,
    this.artistSort,
    this.albumSort,
  });

  final int? id;
  final String source;
  final String? sourceId;
  final String? filePath;
  final int? fileSize;
  final DateTime? fileModifiedAt;
  final String title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final String? comment;
  final String? composer;
  final String? lyrics;
  final String? codec;
  final int? bitrate;
  final int? sampleRate;
  final int? bitDepth;
  final int? channels;
  final bool hasAlbumArt;
  final String? albumArtHash;
  final int playCount;
  final int skipCount;
  final DateTime? lastPlayedAt;
  final DateTime? lastSkippedAt;
  final int rating; // 0-5
  final bool loved;
  final DateTime? dateAdded;
  final String? musicbrainzTrackId;
  final String? musicbrainzArtistId;
  final String? musicbrainzReleaseId;
  final double? replayGainTrack;
  final double? replayGainAlbum;
  final double? bpm;
  final double? loudnessLufs;
  final String? titleSort;
  final String? artistSort;
  final String? albumSort;

  /// Human-readable duration string (mm:ss or h:mm:ss).
  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final total = Duration(milliseconds: durationMs!);
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    final s = total.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
