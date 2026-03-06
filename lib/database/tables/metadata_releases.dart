import 'package:drift/drift.dart';

/// Cached MusicBrainz release data for Tier 1 local metadata resolution.
/// tracksJson stores the full tracklist as a JSON array to avoid a junction table.
class MetadataReleases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mbReleaseId => text().unique()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get mbArtistId => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackCount => integer().nullable()();
  TextColumn get tracksJson => text()();
  TextColumn get coverArtPath => text().nullable()();
  IntColumn get resolvedAt => integer()();
}
