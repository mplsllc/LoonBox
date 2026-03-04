import 'package:drift/drift.dart';

class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sortName => text().nullable()();
  TextColumn get artPath => text().nullable()();
  TextColumn get musicbrainzId => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, source},
      ];
}
