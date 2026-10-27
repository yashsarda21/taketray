import 'package:drift/drift.dart';
import 'package:taketray/data/database/converters.dart';
import 'package:taketray/data/database/tables.dart';
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
    VnSessions,
    VnCopies,
    Settings,
    ZoneTimeline,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// Bump this with every schema change, then run
  /// `dart run drift_dev make-migrations` (docs/flow.md).
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Version 1 has nothing to upgrade from. From version 2 on, this becomes
    // the `stepByStep(from1To2: …)` that make-migrations generates in
    // app_database.steps.dart. Until then the only way here is a downgrade
    // (a database written by a newer TakeTray), and opening it would stamp a
    // newer schema as this version, so refuse.
    onUpgrade: (m, from, to) async {
      throw UnsupportedError(
        'Cannot open a version $from database with schema version $to',
      );
    },
    // SQLite leaves foreign keys off for every new connection; without this,
    // ON DELETE CASCADE would silently do nothing.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
