import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/repositories/reels_repository.dart';

void main() {
  // First time SQLite runs on Android: this proves the sqlite3 native library
  // is packaged in the app, that the database file can be created in the
  // app's private storage, and that a saved reel is still there after the
  // database is closed and opened again. It runs in TakeTray Dev (D-52),
  // never in TakeTray.
  patrolTest('saves a reel, reopens the database and exports it', ($) async {
    const name = 'Goa trip 🌴';

    // First open: save the reel, then close the database so the row has to be
    // in the file.
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final created = await first.read(reelsRepositoryProvider).create(name);
    await first.read(appDatabaseProvider).close();
    first.dispose();

    // Second open: a new container opens the same file from scratch.
    final second = ProviderContainer();
    addTearDown(second.dispose);

    final readBack = await second
        .read(reelsRepositoryProvider)
        .getById(created.id);
    expect(readBack, isNotNull);
    expect(readBack!.name, name);

    final json = await second.read(backupServiceProvider).exportJson();
    final exported = jsonDecode(json) as Map<String, dynamic>;
    final names = [
      for (final r in exported['reels'] as List<dynamic>)
        (r as Map<String, dynamic>)['name'],
    ];
    expect(names, contains(name));

    await second.read(appDatabaseProvider).close();
  });
}
