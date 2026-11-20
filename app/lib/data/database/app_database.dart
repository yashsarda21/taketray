import 'package:drift/drift.dart';
import 'package:taketray/data/database/app_database.steps.dart';
import 'package:taketray/data/database/converters.dart';
import 'package:taketray/data/database/tables.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';

part 'app_database.g.dart';

/// TakeTray's database: one SQLite file in the app's private storage (D-54).
///
/// Open it through `appDatabaseProvider` in the app, or `testDatabase()` in
/// tests. Feature code never uses it directly: it goes through the
/// repositories in `data/repositories/`.
@DriftDatabase(
  tables: [
    Reels,
    Clips,
    ClipReels,
    Inbox,
    ReelReferences,
    EditSessions,
    EditCopies,
    SentClips,
    Settings,
    ZoneTimeline,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// Bump this with every schema change, run
  /// `dart run drift_dev make-migrations` and add the step to
  /// [migration] (docs/flow.md).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // The app and the share screen open the file on two connections, and
    // both can find it empty at the same moment (D-164). The transaction
    // makes the second wait; it then reads the version again and finds the
    // schema made, instead of failing on "already exists". The version is
    // written inside, so the second never sees tables without it.
    onCreate: (m) => transaction(() async {
      if (await _storedVersion() != 0) return;
      await m.createAll();
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (m, from, to) async {
      // A database written by a newer TakeTray (a downgrade): opening it
      // would stamp a newer schema as this version, so refuse. Drift writes
      // the new `user_version` only after this returns, so the file is left
      // untouched (D-54).
      if (from > to) {
        throw UnsupportedError(
          'Cannot open a version $from database with schema version $to',
        );
      }
      // All the steps run in one transaction. Drift's runMigrationSteps
      // writes `user_version` after each step on this same connection, so
      // inside it: a failure part way rolls the file back to exactly the old
      // version, and a phone killed after the commit does not run a step
      // twice on the next open, because the version was written inside the
      // transaction. The write Drift makes after `beforeOpen` is then a
      // second, equal one (D-120).
      //
      // The steps run from the version read again inside the transaction:
      // the other engine may have upgraded the file since this connection
      // read `from` (D-164), and a step must not run twice.
      await transaction(() async {
        final stored = await _storedVersion();
        if (stored > to) {
          throw UnsupportedError(
            'Cannot open a version $stored database with schema version $to',
          );
        }
        // Already at `to`: no step runs.
        await m.runMigrationSteps(
          from: stored,
          to: to,
          steps: migrationSteps(from1To2: _from1To2),
        );
      });
    },
    // SQLite leaves foreign keys off for every new connection; without this,
    // ON DELETE CASCADE would silently do nothing.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );

  /// The schema version stored in the file now (`PRAGMA user_version`).
  Future<int> _storedVersion() async => (await customSelect(
    'PRAGMA user_version',
  ).getSingle()).read<int>('user_version');

  /// v2 (D-120): which editor a session is in, when each copy was made, and
  /// which clips were sent. The SQL names `vn_sessions` and `vn_copies` stay.
  static Future<void> _from1To2(Migrator m, Schema2 schema) async {
    await m.addColumn(schema.vnSessions, schema.vnSessions.editor);
    await m.addColumn(schema.vnCopies, schema.vnCopies.copiedAt);
    // v1 never recorded when a copy was made; its session's start is the
    // closest known time. A copy row with no session (only possible if
    // foreign keys were ever off) keeps 0 rather than failing the upgrade.
    await m.database.customStatement('''
      UPDATE vn_copies SET copied_at = COALESCE(
        (SELECT created_at FROM vn_sessions s
          WHERE s.reel_id = vn_copies.reel_id),
        0)
    ''');
    await m.createTable(schema.sentClips);
    await m.createIndex(schema.sentClipsClipId);
  }
}
