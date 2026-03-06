import 'package:drift/drift.dart';

class WatchDirectories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  BoolColumn get recursive => boolean().withDefault(const Constant(true))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get lastScannedAt => integer().nullable()();
}
