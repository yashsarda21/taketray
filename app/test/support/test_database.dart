import 'package:drift/native.dart';
import 'package:taketray/data/database/app_database.dart';

/// A fresh, empty database that lives only in memory.
///
/// It opens through [AppDatabase]'s own migration strategy, so foreign keys
/// are on (`PRAGMA foreign_keys = ON` in `beforeOpen`) exactly as on the
/// phone. Close it when the test ends: `addTearDown(db.close)`.
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());
