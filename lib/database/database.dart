import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/tracks.dart';
import 'tables/albums.dart';
import 'tables/artists.dart';
import 'tables/playlists.dart';
import 'tables/watch_directories.dart';
import 'tables/play_history.dart';
import 'tables/eq_presets.dart';
import 'tables/settings.dart';
import 'tables/extension_storage.dart';
import 'tables/streaming_accounts.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Tracks,
  Albums,
  Artists,
  Playlists,
  PlaylistTracks,
  WatchDirectories,
  PlayHistory,
  EqPresets,
  Settings,
  ExtensionStorage,
  StreamingAccounts,
])
class LoonBoxDatabase extends _$LoonBoxDatabase {
  LoonBoxDatabase() : super(_openConnection());

  LoonBoxDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedEqPresets();
        },
        onUpgrade: (m, from, to) async {
          // Step-by-step migrations. Each version bump gets its own block.
          // This ensures users upgrading from any version reach the latest schema.
          //
          // Example for future use (uncomment when schemaVersion bumps to 2):
          // if (from < 2) {
          //   await m.addColumn(tracks, tracks.someNewColumn);
          // }
          // if (from < 3) {
          //   await m.createTable(someNewTable);
          // }
        },
        beforeOpen: (details) async {
          // Enable foreign keys for referential integrity
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedEqPresets() async {
    const presets = [
      ('Flat', '[0,0,0,0,0,0,0,0,0,0]'),
      ('Classical', '[0,0,0,0,0,0,-0.2,-0.2,-0.2,-0.4]'),
      ('Club', '[0,0,0.15,0.2,0.2,0.2,0.15,0,0,0]'),
      ('Dance', '[0.5,0.25,0.05,0,0,-0.2,-0.3,-0.3,0,0]'),
      ('Full Bass', '[0.4,0.4,0.4,0.2,0,-0.2,-0.3,-0.35,-0.4,-0.4]'),
      ('Full Treble', '[-0.4,-0.4,-0.4,-0.15,0.1,0.4,0.8,0.8,0.8,0.8]'),
      ('Small Speakers', '[0.2,0.4,0.2,-0.2,-0.15,0,0.2,0.4,0.6,0.7]'),
      ('Large Hall', '[0.45,0.45,0.2,0.2,0,-0.2,-0.2,-0.2,0,0]'),
      ('Live', '[-0.2,0,0.15,0.2,0.2,0.2,0.1,0.05,0.05,0]'),
      ('Party', '[0.25,0.25,0,0,0,0,0,0,0.25,0.25]'),
      ('Pop', '[-0.15,0.15,0.2,0.25,0.15,-0.15,-0.15,-0.15,-0.1,-0.1]'),
      ('Reggae', '[0,0,-0.1,-0.2,0,0.2,0.2,0,0,0]'),
      ('Rock', '[0.3,0.15,-0.2,-0.3,-0.1,0.15,0.3,0.35,0.35,0.35]'),
      ('Ska', '[-0.1,-0.15,-0.12,-0.05,0.15,0.2,0.3,0.3,0.4,0.3]'),
      ('Soft', '[0.2,0,-0.1,-0.15,-0.1,0.2,0.3,0.35,0.4,0.5]'),
      ('Soft Rock', '[0.2,0.2,0,-0.1,-0.2,-0.3,-0.2,-0.1,0.2,0.4]'),
      ('Techno', '[0.3,0.25,0,-0.25,-0.2,0,0.3,0.35,0.35,0.3]'),
    ];

    for (final (name, bands) in presets) {
      await into(eqPresets).insert(EqPresetsCompanion.insert(
        name: name,
        isBuiltin: const Value(true),
        bands: bands,
      ));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'loonbox.db'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Global database provider.
final databaseProvider = Provider<LoonBoxDatabase>((ref) {
  final db = LoonBoxDatabase();
  ref.onDispose(() => db.close());
  return db;
});
