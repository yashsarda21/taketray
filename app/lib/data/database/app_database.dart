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
    onCreate: (m) => m.createAll(),
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
      // version, and a phone killed after the commit (before Drift's own
      // version write once `beforeOpen` is done) does not run a step twice
      // on the next open (D-120).
      await transaction(
        () => m.runMigrationSteps(
          from: from,
          to: to,
          steps: migrationSteps(from1To2: _from1To2),
        ),
      );
    },
    // SQLite leaves foreign keys off for every new connection; without this,
    // ON DELETE CASCADE would silently do nothing.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );

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
