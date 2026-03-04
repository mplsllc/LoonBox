import 'package:drift/drift.dart';

class EqPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  TextColumn get bands => text()(); // JSON array of 10 floats
}
