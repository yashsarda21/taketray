import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app/database_refresh.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';

/// Remembers the name of every provider that is built.
final class _BuiltProviders extends ProviderObserver {
  final List<String> names = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    names.add('${context.provider.name ?? context.provider.runtimeType}');
  }
}

/// The app goes to the background, then comes back to the front.
void _leaveAndResume(WidgetTester tester) {
  tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
    ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

/// Lets the database's update stream deliver (it runs outside fake time).
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

/// A database that records what each `notifyUpdates` call names.
class _RecordingDatabase extends AppDatabase {
  _RecordingDatabase() : super(NativeDatabase.memory());

  final List<Set<String>> notified = [];

  @override
  void notifyUpdates(Set<TableUpdate> updates) {
    notified.add({for (final u in updates) u.table});
    super.notifyUpdates(updates);
  }
}

void main() {
  late _RecordingDatabase db;
  late List<Set<String>> notified;

  setUp(() {
    db = _RecordingDatabase();
    notified = db.notified;
  });

  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    bool openDatabase = true,
    List<ProviderObserver> observers = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        observers: observers,
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: DatabaseRefresh(
          child: Consumer(
            builder: (context, ref, _) {
              // The engine's screens use the database, as Home does.
              if (openDatabase) ref.watch(appDatabaseProvider);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a resume re-reads exactly the reels and their references', (
    tester,
  ) async {
    await pump(tester);

    _leaveAndResume(tester);
    await _settle(tester);

    expect(notified, [
      {'reels', 'reel_references'},
    ]);
  });

  testWidgets('a watch on the reels runs again on resume', (tester) async {
    await pump(tester);
    final seen = <int>[];
    final watch = db
        .select(db.reels)
        .watch()
        .map((r) => r.length)
        .listen(seen.add);
    addTearDown(watch.cancel);
    await _settle(tester);
    final before = seen.length;

    _leaveAndResume(tester);
    await _settle(tester);

    expect(seen.length, before + 1);
  });

  testWidgets('nothing is re-read at start, only on resume', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    expect(notified, isEmpty);
  });

  testWidgets('every resume re-reads again', (tester) async {
    await pump(tester);

    _leaveAndResume(tester);
    await _settle(tester);
    _leaveAndResume(tester);
    await _settle(tester);

    expect(notified, hasLength(2));
  });

  testWidgets('a resume before anything opened the database opens nothing', (
    tester,
  ) async {
    final built = _BuiltProviders();
    await pump(tester, openDatabase: false, observers: [built]);

    _leaveAndResume(tester);
    await _settle(tester);

    expect(built.names, isNot(contains('appDatabaseProvider')));
    expect(notified, isEmpty);
  });

  testWidgets('once it is gone, a resume does nothing', (tester) async {
    await pump(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const SizedBox(),
      ),
    );

    _leaveAndResume(tester);
    await _settle(tester);

    expect(notified, isEmpty);
  });
}
