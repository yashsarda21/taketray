import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/reels/views/open_once.dart';

void main() {
  group('OpenOnce.openSlow', () {
    testWidgets('shuts the window for the whole wait, and a window after the '
        'push', (tester) async {
      final once = OpenOnce();
      addTearDown(once.dispose);
      var started = 0;
      late void Function() pushing;
      void start() => once.openSlow((p) async {
        started++;
        pushing = p;
        await Future<void>.delayed(const Duration(seconds: 10));
      });

      start();
      await tester.pump(const Duration(seconds: 5));
      start();
      expect(started, 1, reason: 'much longer than a window, still waiting');
      expect(once.busy, isTrue);

      pushing();
      start();
      expect(started, 1, reason: 'the page is arriving');

      await tester.pump(const Duration(seconds: 1));
      expect(once.busy, isFalse);
      // The wait is still running in the background of this test; end it.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('an open that ends without pushing releases the window', (
      tester,
    ) async {
      final once = OpenOnce();
      addTearDown(once.dispose);
      var started = 0;
      void start() => once.openSlow((_) async => started++);

      start();
      await tester.pump();

      expect(once.busy, isFalse);
      start();
      expect(started, 2);
    });

    testWidgets('an open that throws releases the window', (tester) async {
      final once = OpenOnce();
      addTearDown(once.dispose);

      await runZonedGuarded(() async {
        once.openSlow((_) => Future<void>.error(StateError('on purpose')));
        await tester.pump();
      }, (error, stack) {});

      expect(once.busy, isFalse);
    });

    testWidgets('disposed during the wait: no timer starts after it', (
      tester,
    ) async {
      late void Function() pushing;
      final once = OpenOnce()
        ..openSlow((p) async {
          pushing = p;
          await Future<void>.delayed(const Duration(seconds: 1));
        })
        ..dispose();

      pushing();

      expect(once.busy, isFalse, reason: 'no window starts after dispose');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a call of pushing after the first does nothing', (
      tester,
    ) async {
      final once = OpenOnce();
      addTearDown(once.dispose);
      late void Function() pushing;
      once.openSlow((p) async => pushing = p);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(once.busy, isFalse);

      pushing();

      expect(once.busy, isFalse);
    });
  });
}
