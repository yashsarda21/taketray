import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/database/app_database.dart';

part 'connection.g.dart';

/// The app's database, `taketray.sqlite` in the app's private storage.
///
/// It stays open for the app's lifetime and is closed when the provider
/// container is disposed. Tests use `testDatabase()` instead.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(driftDatabase(name: 'taketray'));
  ref.onDispose(db.close);
  return db;
}
