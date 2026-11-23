import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/busy_wait.dart';

part 'connection.g.dart';

/// How each engine opens `taketray.sqlite` (D-164).
///
/// The app and the share screen run in two Flutter engines in one process
/// (D-163), and each opens its own connection to the one file. Every
/// connection, as it opens:
/// - waits up to 5 s of real time for the other engine's write to finish
///   ([busyWait], a busy handler), instead of failing at once with
///   "database is locked". Drift starts every transaction with
///   `BEGIN IMMEDIATE`, so a transaction waits too, rather than failing half
///   way. It comes first: the switch to WAL needs the file to itself. Not
///   `PRAGMA busy_timeout`: signals cut SQLite's own sleeps short on Linux
///   and Android, and its 5 s were over in about 60 ms (D-164);
/// - turns on WAL, so a reader never waits for the other engine's write.
///
/// The two connections do not see each other's writes in their `watch`
/// streams; `DatabaseRefresh` re-reads the shared tables when an engine
/// comes back to the front. drift_flutter's `shareAcrossIsolates` (one
/// server isolate for both) does not work across independent engines, by
/// its own docs.
final DriftNativeOptions appDatabaseOptions = DriftNativeOptions(
  setup: (db) => db
    ..busyHandler = busyWait()
    ..execute('PRAGMA journal_mode = WAL'),
);

/// The engine's database, `taketray.sqlite` in the app's private storage.
///
/// It stays open for the engine's lifetime and is closed when the provider
/// container is disposed. Tests use `testDatabase()` instead.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(
    driftDatabase(name: 'taketray', native: appDatabaseOptions),
  );
  ref.onDispose(db.close);
  return db;
}
