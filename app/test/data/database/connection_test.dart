import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../drift/taketray/generated/schema_v1.dart' as v1;

// The app and the share screen each run their own Flutter engine, and each
// builds its own `appDatabaseProvider`: two connections to one file (D-164).
// Two provider containers stand in for the two engines here; each opens its
// own background connection, exactly as each engine does on the phone.

final DateTime _t0 = DateTime.utc(2026, 11, 20, 9);

ReelsCompanion _reel(String name) => ReelsCompanion.insert(
  name: name,
  status: ReelStatus.collecting,
  createdAt: _t0,
  updatedAt: _t0,
);

/// The number of reels, as a `watch` stream sees it.
Stream<int> _watchCount(AppDatabase db) =>
    db.select(db.reels).watch().map((rows) => rows.length);

/// The number of reels, from a fresh query.
Future<int> _count(AppDatabase db) async =>
    (await db.select(db.reels).get()).length;

/// What a pragma reads back on [db]'s connection.
Future<Object?> _pragma(AppDatabase db, String name) async =>
    (await db.customSelect('PRAGMA $name').getSingle()).data.values.single;

/// Opens a raw connection: no migrations, no version.
class _RawUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) =>
      Future.value();
}

void main() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  late Directory temp;
  late List<ProviderContainer> engines;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('taketray_docs_');
    temp = Directory.systemTemp.createTempSync('taketray_tmp_');
    engines = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' => docs.path,
            'getTemporaryDirectory' => temp.path,
            _ => throw UnimplementedError(call.method),
          };
        });
  });

  /// Closes an engine's database and waits until it really is closed.
  Future<void> close(ProviderContainer engine) async {
    if (!engines.remove(engine)) return;
    final db = engine.read(appDatabaseProvider);
    engine.dispose();
    await db.close();
  }

  tearDown(() async {
    for (final engine in [...engines]) {
      await close(engine);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    docs.deleteSync(recursive: true);
    temp.deleteSync(recursive: true);
  });

  /// One engine: a container with its own `appDatabaseProvider`.
  AppDatabase open() {
    final engine = ProviderContainer();
    engines.add(engine);
    return engine.read(appDatabaseProvider);
  }

  test('the database is taketray.sqlite in the documents folder', () async {
    final db = open();
    await db.into(db.reels).insert(_reel('one'));

    expect(File('${docs.path}/taketray.sqlite').existsSync(), isTrue);
  });

  test('each engine opens its connection in WAL mode with a 5 s busy '
      'timeout', () async {
    final app = open();
    final share = open();

    for (final db in [app, share]) {
      expect(await _pragma(db, 'journal_mode'), 'wal');
      expect(await _pragma(db, 'busy_timeout'), 5000);
    }
  });

  test("a write in one engine is in the other's next query", () async {
    final app = open();
    final share = open();
    expect(await _count(app), 0);

    await share.into(share.reels).insert(_reel('from the share'));
    expect(await _count(app), 1);

    await app.into(app.reels).insert(_reel('from the app'));
    expect(await _count(share), 2);
  });

  test("the other engine's watch stream re-reads after notifyUpdates, and "
      'not before', () async {
    final app = open();
    final share = open();
    final seen = <int>[];
    final sub = _watchCount(app).listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, [0]);

    await share.into(share.reels).insert(_reel('from the share'));
    // Two connections: the app's stream learns nothing of the share's write.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(seen, [0]);

    app.notifyUpdates({
      TableUpdate.onTable(app.reels),
      TableUpdate.onTable(app.reelReferences),
    });
    await _watchCount(app)
        .firstWhere((n) => n == 1)
        .timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, [0, 1]);
  });

  test('both engines writing at once: no "database is locked" and no lost '
      'write', () async {
    final app = open();
    final share = open();
    // Both connections open (and the schema made) before the race.
    expect(await _count(app), 0);
    expect(await _count(share), 0);

    await Future.wait([
      for (var i = 0; i < 40; i++)
        if (i.isEven)
          app.transaction(() => app.into(app.reels).insert(_reel('app $i')))
        else
          share.transaction(
            () => share.into(share.reels).insert(_reel('share $i')),
          ),
    ]);

    expect(await _count(app), 40);
    expect(await _count(share), 40);
  });

  test("a write waits for the other engine's open transaction instead of "
      'failing', () async {
    final app = open();
    final share = open();
    // Both connections open (and the schema made) before the race.
    expect(await _count(app), 0);
    expect(await _count(share), 0);

    final holding = Completer<void>();
    final appWrite = app.transaction(() async {
      await app.into(app.reels).insert(_reel('app, slow'));
      holding.complete();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await holding.future;

    await share.into(share.reels).insert(_reel('share, waiting'));
    await appWrite;

    expect(await _count(share), 2);
  });

  test('the app closed first: the share still reads and writes', () async {
    final app = open();
    final share = open();
    await app.into(app.reels).insert(_reel('before'));
    expect(await _count(share), 1);

    await close(engines.first);

    await share.into(share.reels).insert(_reel('after the app closed'));
    expect(await _count(share), 2);
  });

  test('the share closed first: the app still reads and writes', () async {
    final app = open();
    final share = open();
    await share.into(share.reels).insert(_reel('from the share'));
    expect(await _count(app), 1);

    await close(engines.last);

    await app.into(app.reels).insert(_reel('after the share closed'));
    expect(await _count(app), 2);
  });

  test('both closed, then opened again: the reels are still there', () async {
    final app = open();
    final share = open();
    await app.into(app.reels).insert(_reel('app'));
    await share.into(share.reels).insert(_reel('share'));
    for (final engine in [...engines]) {
      await close(engine);
    }

    final again = open();
    expect(await _count(again), 2);
  });
  group('two engines opening the file at the same moment', () {
    // A third connection holds the write lock while both engines open: both
    // read the stored version before either can change the schema, the way
    // two engines starting together could. Then the lock goes.
    Future<QueryExecutor> holdWriteLock() async {
      final holder = NativeDatabase(
        File('${docs.path}/taketray.sqlite'),
        setup: appDatabaseOptions.setup,
        // It must not touch the stored version.
        enableMigrations: false,
      );
      await holder.ensureOpen(_RawUser());
      await holder.runCustom('BEGIN IMMEDIATE');
      return holder;
    }

    Future<void> release(QueryExecutor holder) async {
      await holder.runCustom('COMMIT');
      await holder.close();
    }

    test('a new file: the schema is made once and both engines work', () async {
      final holder = await holdWriteLock();
      final app = open();
      final share = open();
      final counts = Future.wait([_count(app), _count(share)]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await release(holder);

      expect(await counts, [0, 0]);
      await share.into(share.reels).insert(_reel('from the share'));
      expect(await _count(app), 1);
      expect(await _pragma(app, 'user_version'), 2);
    });

    test('a v1 file: it is upgraded once and both engines work', () async {
      final old = v1.DatabaseAtV1(
        NativeDatabase(File('${docs.path}/taketray.sqlite')),
      );
      await old.customSelect('SELECT 1').get();
      expect((await old.customSelect('PRAGMA user_version').getSingle()).data, {
        'user_version': 1,
      });
      await old.close();

      final holder = await holdWriteLock();
      final app = open();
      final share = open();
      final counts = Future.wait([_count(app), _count(share)]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await release(holder);

      expect(await counts, [0, 0]);
      expect(await _pragma(share, 'user_version'), 2);
      // A v2 table, on both connections.
      expect(await app.select(app.sentClips).get(), isEmpty);
      expect(await share.select(share.sentClips).get(), isEmpty);
    });

    test('a newer version written meanwhile is refused, not stamped back '
        '(D-54)', () async {
      final old = v1.DatabaseAtV1(
        NativeDatabase(File('${docs.path}/taketray.sqlite')),
      );
      await old.customSelect('SELECT 1').get();
      await old.close();

      final holder = await holdWriteLock();
      final app = open();
      final count = _count(app);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await holder.runCustom('PRAGMA user_version = 3');
      await release(holder);

      // The refusal comes from the connection's own isolate.
      await expectLater(
        count,
        throwsA(
          isA<Object>().having(
            (e) => '$e',
            'cause',
            contains('Cannot open a version 3 database with schema version 2'),
          ),
        ),
      );
      final check = NativeDatabase(
        File('${docs.path}/taketray.sqlite'),
        enableMigrations: false,
      );
      await check.ensureOpen(_RawUser());
      final rows = await check.runSelect('PRAGMA user_version', []);
      await check.close();
      expect(rows.single['user_version'], 3);
    });
  });
}
