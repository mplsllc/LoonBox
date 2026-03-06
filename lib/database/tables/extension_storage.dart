import 'package:drift/drift.dart';

class ExtensionStorage extends Table {
  TextColumn get extensionId => text()();
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {extensionId, key};
}
