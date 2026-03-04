import 'package:drift/drift.dart';

class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer()();
  IntColumn get playedAt => integer()();
  IntColumn get durationListenedMs => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().nullable()();
}
