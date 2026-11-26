import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/router/routes.dart';

import '../../patrol_test/support/reel_finders.dart';
import '../support/test_app.dart';
import '../support/vm_harness.dart';

/// The finders the references Patrol flows tap and wait on (D-161), checked
/// here against the widgets they find on the phone: the S24 run of
/// 2026-11-22 timed out on both of the flows' old finders.
void main() {
  group('reelPageOf', () {
    late VmHarness h;

    setUp(() {
      h = VmHarness();
      // Home asks which editor apps are on the phone.
      h.editors.allowOnly({'apps'});
    });

    Future<void> settleApp(WidgetTester tester) async {
      await tester.runAsync(settle);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testApp('finds the page opened at its References, with the name scrolled '
        'away', (tester) async {
      final reels = h.container.read(reelsRepositoryProvider);
      final references = h.container.read(referencesRepositoryProvider);
      final ids = await tester.runAsync(() async {
        final goa = await reels.create(
          'Goa',
          description: 'Wide shot of the harbour at dawn',
        );
        final other = await reels.create('London');
        await references.add(goa.id, 'https://example.com/a1');
        await references.add(goa.id, 'https://example.com/a2');
        return (goa: goa.id, other: other.id);
      });
      await tester.pumpWidget(
        ProviderScope(overrides: h.appOverrides, child: const TakeTrayApp()),
      );
      await settleApp(tester);
      unawaited(
        GoRouter.of(tester.element(find.byType(ReelsScreen)))
            .push(Routes.reelReferences(ids!.goa)),
      );
      await settleApp(tester);

      // As on the S24: the page scrolled to its References section, and the
      // header with the name went off the screen (a finder skips it then).
      expect(find.byType(ReferencesSection), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReelDetailScreen),
          matching: find.text('Goa'),
        ),
        findsNothing,
      );
      expect(reelPageOf(ids.goa, 'Goa'), findsOneWidget);
      expect(reelPageOf(ids.other, 'London'), findsNothing);
    });
  });
}
