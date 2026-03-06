import 'package:drift/drift.dart';

class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get artist => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get trackCount => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artPath => text().nullable()();
  IntColumn get dateAdded => integer().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  TextColumn get sourceId => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, source},
      ];
}
