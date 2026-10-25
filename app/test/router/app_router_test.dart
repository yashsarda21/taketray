import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_placeholder_screen.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';

Future<(ProviderContainer, GoRouter)> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TakeTrayApp()),
  );
  await tester.pumpAndSettle();
  return (container, container.read(appRouterProvider));
}

void main() {
  testWidgets('go to a known location shows that tab', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    expect(find.byType(ToTagPlaceholderScreen), findsOneWidget);
  });

  testWidgets('unknown location redirects to Reels', (tester) async {
    final (_, router) = await _pumpApp(tester);

    router.go('/nope');
    await tester.pumpAndSettle();

    expect(find.byType(ReelsPlaceholderScreen), findsOneWidget);
  });

  testWidgets('system back on To tag selects Reels and keeps the app open', (
    tester,
  ) async {
    final (_, router) = await _pumpApp(tester);
    router.go(Routes.toTag);
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(ReelsPlaceholderScreen), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('each tab keeps its own navigation stack', (tester) async {
    final (_, router) = await _pumpApp(tester);

    Navigator.of(tester.element(find.byType(ReelsPlaceholderScreen))).push(
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
