import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/editors/views/mark_status_dialog.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/test_app.dart';
import '../../support/vm_harness.dart';

void main() {
  late VmHarness h;
  late ReelsRepository reels;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// A page with one button that asks for the dialog on reel [id]. The
  /// dialog is built through [call] so a test can use either form.
  Future<void> openDialog(
    WidgetTester tester,
    int id,
    ReelStatus status, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => showMarkStatusDialog(context, ref, id, status),
            child: const Text('go'),
          ),
        ),
      ),
      overrides: h.appOverrides,
      textScale: textScale,
      brightness: brightness,
    );
    await tester.tap(find.text('go'));
    await settleApp(tester);
  }

  testApp('Ready to edit: the question, the explanation, the two buttons', (
    tester,
  ) async {
    final goa = await real(tester, () => reels.create('Goa'));

    await openDialog(tester, goa.id, ReelStatus.ready);

    expect(find.text('Mark Goa as Ready to edit?'), findsOneWidget);
    expect(
      find.text(
        'Helps you find it under Ready to edit. You can change this any time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Mark as Ready to edit'), findsOneWidget);
  });

  testApp('Published: its own question and explanation', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));

    await openDialog(tester, goa.id, ReelStatus.published);

    expect(find.text('Mark Goa as Published?'), findsOneWidget);
    expect(
      find.text(
        'It moves to the Published filter. You can change this any time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mark as Published'), findsOneWidget);
  });

  testApp('the confirm sets the status once and says "Marked as …"', (
    tester,
  ) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await openDialog(tester, goa.id, ReelStatus.ready);

    await tester.tap(find.text('Mark as Ready to edit'));
    await settleApp(tester);

    expect(
      (await real(tester, () => reels.getById(goa.id)))!.status,
      ReelStatus.ready,
    );
    expect(find.text('Marked as Ready to edit'), findsOneWidget);
    expect(find.text('Mark Goa as Ready to edit?'), findsNothing);
  });

  testApp('Published sets Published', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await openDialog(tester, goa.id, ReelStatus.published);

    await tester.tap(find.text('Mark as Published'));
    await settleApp(tester);

    expect(
      (await real(tester, () => reels.getById(goa.id)))!.status,
      ReelStatus.published,
    );
    expect(find.text('Marked as Published'), findsOneWidget);
  });

  testApp('Not now changes nothing and says nothing', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await openDialog(tester, goa.id, ReelStatus.ready);

    await tester.tap(find.text('Not now'));
    await settleApp(tester);

    expect(
      (await real(tester, () => reels.getById(goa.id)))!.status,
      ReelStatus.collecting,
    );
    expect(find.byType(TtSnack), findsNothing);
    expect(find.text('Mark Goa as Ready to edit?'), findsNothing);
  });

  testApp('a tap outside closes it and changes nothing', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await openDialog(tester, goa.id, ReelStatus.ready);

    await tester.tapAt(const Offset(4, 4));
    await settleApp(tester);

    expect(
      (await real(tester, () => reels.getById(goa.id)))!.status,
      ReelStatus.collecting,
    );
    expect(find.byType(TtSnack), findsNothing);
  });

  testApp('a reel that is gone shows no dialog', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await real(tester, () => reels.delete(goa.id));

    await openDialog(tester, goa.id, ReelStatus.ready);

    expect(find.textContaining('Mark '), findsNothing);
    expect(find.byType(TtDialog<bool>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testApp('the reel already has that status: no dialog', (tester) async {
    final goa = await real(tester, () => reels.create('Goa'));
    await real(tester, () => reels.setStatus(goa.id, ReelStatus.ready));

    await openDialog(tester, goa.id, ReelStatus.ready);

    expect(find.textContaining('Mark Goa'), findsNothing);
  });

  testApp('a long reel name wraps at 2x text, accessible, light and dark', (
    tester,
  ) async {
    final goa = await real(
      tester,
      () => reels.create('Summer road trip with the whole family'),
    );
    await openDialog(tester, goa.id, ReelStatus.ready, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Mark Summer road trip'), findsOneWidget);
    await expectTtAccessible(tester);
  });

  testApp('the container form works after the page that asked is gone', (
    tester,
  ) async {
    final goa = await real(tester, () => reels.create('Goa'));
    final pageShown = ValueNotifier<bool>(true);
    addTearDown(pageShown.dispose);
    late ProviderContainer container;
    late BuildContext overlay;
    await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          overlay = Navigator.of(context).overlay!.context;
          return ValueListenableBuilder<bool>(
            valueListenable: pageShown,
            builder: (_, shown, _) => shown
                ? const Scaffold(body: Text('page'))
                : const Scaffold(body: SizedBox()),
          );
        },
      ),
      overrides: h.appOverrides,
    );
    pageShown.value = false;
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);

    unawaited(
      showMarkStatusDialogIn(overlay, container, goa.id, ReelStatus.ready),
    );
    await settleApp(tester);

    expect(find.text('Mark Goa as Ready to edit?'), findsOneWidget);
    await tester.tap(find.text('Mark as Ready to edit'));
    await settleApp(tester);
    expect(
      (await real(tester, () => reels.getById(goa.id)))!.status,
      ReelStatus.ready,
    );
  });
}
