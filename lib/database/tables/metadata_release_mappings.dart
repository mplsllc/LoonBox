import 'package:drift/drift.dart';

/// Maps a local album identity (name + artist) to a cached MusicBrainz release.
/// Used by post-scan enrichment to auto-apply MB IDs without network calls.
class MetadataReleaseMappings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get albumName => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get mbReleaseId => text()();
  IntColumn get confidence => integer()();
  IntColumn get createdAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {albumName, artistName},
      ];
}
