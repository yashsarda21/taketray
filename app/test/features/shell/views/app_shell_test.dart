import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/shell/views/app_shell.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/clips.dart';

/// The shell on its own: three marker tabs behind the nav pill, with the
/// pending clips fed by hand, for the badge on the To tag tab (D-184).
void main() {
  late StreamController<List<Clip>> pending;

  setUp(() {
    pending = StreamController<List<Clip>>();
    // Not awaited: close() on a controller nobody listens to any more
    // never completes.
    addTearDown(() => unawaited(pending.close()));
  });

  List<Clip> clips(int count) => [for (var i = 1; i <= count; i++) testClip(i)];

  Future<void> pumpShell(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: Routes.reels,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final (path, marker) in [
              (Routes.reels, 'the Reels tab'),
              (Routes.toTag, 'the To tag tab'),
              (Routes.settings, 'the Settings tab'),
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => Center(child: Text(marker)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pendingClipsProvider.overrideWith((ref) => pending.stream)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: TakeTrayTheme.light(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Sends [clips] as the next pending list, and shows it.
  Future<void> emit(WidgetTester tester, List<Clip> list) async {
    pending.add(list);
    await tester.pumpAndSettle();
  }

  /// The counts of the badges in the nav pill (one per item).
  List<int> badgeCounts(WidgetTester tester) => [
    for (final badge in tester.widgetList<TtCountBadge>(
      find.descendant(
        of: find.byType(TtNavPill),
        matching: find.byType(TtCountBadge),
      ),
    ))
      badge.count,
  ];

  Finder inPill(String text) =>
      find.descendant(of: find.byType(TtNavPill), matching: find.text(text));

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(inPill(label));
    await tester.pumpAndSettle();
  }

  String toTagSemantics() {
    // The To tag item is the one whose label starts with "To tag".
    final nodes = find.semantics.byLabel(RegExp('^To tag'));
    return nodes.evaluate().single.label;
  }

  testWidgets('no clips waiting: no badge, and the tab reads "To tag"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);
    await emit(tester, const []);

    expect(badgeCounts(tester), everyElement(0));
    expect(inPill('0'), findsNothing);
    expect(toTagSemantics(), 'To tag');
    semantics.dispose();
  });

  testWidgets('7 clips waiting: the To tag tab shows 7', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);
    await emit(tester, clips(7));

    expect(inPill('7'), findsOneWidget);
    expect(badgeCounts(tester), [0, 7, 0]);
    expect(toTagSemantics(), 'To tag, 7 clips');
    semantics.dispose();
  });

  testWidgets('one clip waiting reads "1 clip" to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);
    await emit(tester, clips(1));

    expect(inPill('1'), findsOneWidget);
    expect(toTagSemantics(), 'To tag, 1 clip');
    semantics.dispose();
  });

  testWidgets('the badge follows the stream: 3, 1, then gone', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);
    final shell = tester.element(find.byType(AppShell));

    await emit(tester, clips(3));
    expect(inPill('3'), findsOneWidget);

    await emit(tester, clips(1));
    expect(inPill('3'), findsNothing);
    expect(inPill('1'), findsOneWidget);
    expect(toTagSemantics(), 'To tag, 1 clip');

    await emit(tester, const []);
    expect(inPill('1'), findsNothing);
    expect(badgeCounts(tester), everyElement(0));
    expect(toTagSemantics(), 'To tag');

    // The same shell element all along: nothing was rebuilt from scratch.
    expect(tester.element(find.byType(AppShell)), same(shell));
    semantics.dispose();
  });

  testWidgets('the badge is on every tab', (tester) async {
    await pumpShell(tester);
    await emit(tester, clips(2));

    expect(find.text('the Reels tab'), findsOneWidget);
    expect(inPill('2'), findsOneWidget);

    await goTo(tester, 'To tag');
    expect(find.text('the To tag tab'), findsOneWidget);
    expect(inPill('2'), findsOneWidget);

    await goTo(tester, 'Settings');
    expect(find.text('the Settings tab'), findsOneWidget);
    expect(inPill('2'), findsOneWidget);

    await goTo(tester, 'Reels');
    expect(find.text('the Reels tab'), findsOneWidget);
    expect(inPill('2'), findsOneWidget);
    expect(badgeCounts(tester), [0, 2, 0]);
  });

  testWidgets('before the first event there is no badge and the pill works', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(badgeCounts(tester), everyElement(0));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await goTo(tester, 'Settings');
    expect(find.text('the Settings tab'), findsOneWidget);
    expect(badgeCounts(tester), everyElement(0));
  });

  testWidgets('after an error there is no badge, no error widget, and the '
      'pill works', (tester) async {
    await pumpShell(tester);
    pending.addError(StateError('the database failed'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(badgeCounts(tester), everyElement(0));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('rror'), findsNothing);
    expect(find.textContaining('failed'), findsNothing);

    await goTo(tester, 'To tag');
    expect(find.text('the To tag tab'), findsOneWidget);
    expect(badgeCounts(tester), everyElement(0));
  });

  testWidgets('an error after a first count keeps the last count (D-184)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);
    await emit(tester, clips(4));
    expect(badgeCounts(tester), [0, 4, 0]);

    pending.addError(StateError('the database failed'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(badgeCounts(tester), [0, 4, 0]);
    expect(inPill('4'), findsOneWidget);
    expect(toTagSemantics(), 'To tag, 4 clips');
    expect(find.textContaining('rror'), findsNothing);

    // And the next answer replaces it as usual.
    await emit(tester, clips(2));
    expect(badgeCounts(tester), [0, 2, 0]);
    semantics.dispose();
  });

  testWidgets('over 99 clips the badge says 99+', (tester) async {
    await pumpShell(tester);
    await emit(tester, clips(120));

    expect(inPill('99+'), findsOneWidget);
    expect(inPill('120'), findsNothing);
  });
}
