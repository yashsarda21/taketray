import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/data/backup/backup_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';

void main() {
  // First time SQLite runs on Android: this proves the sqlite3 native library
  // is packaged in the app and that the database file can be created in the
  // app's private storage. It runs in TakeTray Dev (D-52), never in TakeTray.
  patrolTest('opens the real database, saves a reel and exports it', ($) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final reels = container.read(reelsRepositoryProvider);
    final created = await reels.create('Goa trip 🌴');

    final readBack = await reels.getById(created.id);
    expect(readBack, isNotNull);
    expect(readBack!.name, 'Goa trip 🌴');

    final json = await container.read(backupServiceProvider).exportJson();
    final exported = jsonDecode(json) as Map<String, dynamic>;
    final names = [
      for (final r in exported['reels'] as List<dynamic>)
        (r as Map<String, dynamic>)['name'],
    ];
    expect(names, contains('Goa trip 🌴'));
  });
}
