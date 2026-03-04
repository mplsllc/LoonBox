import 'package:drift/drift.dart';

class StreamingAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text().unique()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get refreshToken => text().nullable()();
  IntColumn get expiresAt => integer().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get userName => text().nullable()();
}
