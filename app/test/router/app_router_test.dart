import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reel_detail_placeholder.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/test_app.dart';
import '../support/vm_harness.dart';

Future<(ProviderContainer, GoRouter)> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer(overrides: VmHarness().appOverrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return (container, container.read(appRouterProvider));
}

void main() {
  testApp('go to a known location shows that tab', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    expect(find.byType(ToTagScreen), findsOneWidget);
  });

  testApp('unknown location redirects to Reels', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go('/nope');
    await tester.pumpAndSettle();

    expect(find.byType(ReelsScreen), findsOneWidget);
  });

  for (final location in ['/reels/unknown', '/to-tag/a/b', '/settings/x']) {
    testApp('unknown location below a tab root ($location) lands on Reels', (
      tester,
    ) async {
      final (_, router) = await _pumpApp(tester);
      router.go(Routes.toTag);
      await tester.pumpAndSettle();

      final logged = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(logged.add);
      addTearDown(sub.cancel);

      router.go(location);
      await tester.pumpAndSettle();

      expect(logged.map((r) => r.loggerName), contains('router'));
      expect(logged.map((r) => r.message).join(), isNot(contains(location)));

      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.textContaining('Page Not Found'), findsNothing);
      final bar = tester.widget<TtNavPill>(find.byType(TtNavPill));
      expect(bar.currentIndex, 0);
    });
  }

  testApp('a reel location shows the reel page and back goes to Reels', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);

    router.go(Routes.reel(7));
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailPlaceholder), findsOneWidget);
    expect(
      tester
          .widget<ReelDetailPlaceholder>(find.byType(ReelDetailPlaceholder))
          .reelId,
      7,
    );
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReelsScreen), findsOneWidget);
  });

  for (final id in ['abc', '1.5', '0', '-3', '99999999999999999999']) {
    testApp('a reel location with the id "$id" lands on Reels', (tester) async {
      final (_, router) = await _pumpApp(tester);
      router.go(Routes.toTag);
      await tester.pumpAndSettle();

      router.go('/reels/$id');
      await tester.pumpAndSettle();

      expect(find.byType(ReelDetailPlaceholder), findsNothing);
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
    });
  }

  testApp('system back on Reels is not intercepted', (tester) async {
    await _pumpApp(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isFalse);
  });

  testApp('system back on To tag selects Reels and keeps the app open', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(ReelsScreen), findsOneWidget);
    final bar = tester.widget<TtNavPill>(find.byType(TtNavPill));
    expect(bar.currentIndex, 0);
  });

  testApp('each tab keeps its own navigation stack', (tester) async {
    final (_, router) = await _pumpApp(tester);

    Navigator.of(tester.element(find.byType(ReelsScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('dummy-pushed')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsOneWidget);

    router.go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsNothing);

    router.go(Routes.reels);
    await tester.pumpAndSettle();
    expect(find.text('dummy-pushed'), findsOneWidget);
  });
}
