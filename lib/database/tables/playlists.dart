import 'package:drift/drift.dart';

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  TextColumn get smartRules => text().nullable()(); // JSON
  TextColumn get sortField => text().nullable()();
  TextColumn get sortOrder => text().nullable()(); // 'asc' or 'desc'
  IntColumn get limitCount => integer().nullable()();
  TextColumn get limitUnit => text().nullable()(); // 'tracks', 'minutes', 'mb'
  BoolColumn get liveUpdate => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get trackCount => integer().withDefault(const Constant(0))();
}

class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get trackId => integer()();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {playlistId, trackId, position},
      ];
}
