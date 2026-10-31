import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/fit_or_fallback.dart';

const _wide = Key('wide');
const _narrow = Key('narrow');

/// [child] in [width] dp of room, free to be smaller than that.
Widget _room(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Widget _app(double width, {VoidCallback? onWide, VoidCallback? onNarrow}) =>
    _room(
      width,
      FitOrFallback(
        preferred: GestureDetector(
          key: _wide,
          behavior: HitTestBehavior.opaque,
          onTap: onWide,
          child: const SizedBox(width: 120, height: 30),
        ),
        fallback: GestureDetector(
          key: _narrow,
          behavior: HitTestBehavior.opaque,
          onTap: onNarrow,
          child: const SizedBox(width: 40, height: 48),
        ),
      ),
    );

void main() {
  group('FitOrFallback', () {
    testWidgets('shows the preferred child when it fits', (tester) async {
      await tester.pumpWidget(_app(200));
      expect(tester.getSize(find.byType(FitOrFallback)), const Size(120, 30));
      expect(tester.getRect(find.byKey(_wide)).size, const Size(120, 30));
    });

    testWidgets('shows the fallback when the preferred child does not fit', (
      tester,
    ) async {
      await tester.pumpWidget(_app(100));
      expect(tester.getSize(find.byType(FitOrFallback)), const Size(40, 48));
      expect(tester.getRect(find.byKey(_narrow)).size, const Size(40, 48));
    });

    testWidgets('switches when the room changes', (tester) async {
      await tester.pumpWidget(_app(200));
      expect(tester.getSize(find.byType(FitOrFallback)).height, 30);
      await tester.pumpWidget(_app(100));
      expect(tester.getSize(find.byType(FitOrFallback)).height, 48);
      await tester.pumpWidget(_app(120));
      expect(tester.getSize(find.byType(FitOrFallback)).height, 30);
    });

    testWidgets('only the shown child takes taps', (tester) async {
      var wide = 0;
      var narrow = 0;
      await tester.pumpWidget(
        _app(100, onWide: () => wide++, onNarrow: () => narrow++),
      );
      await tester.tapAt(const Offset(20, 20));
      expect((wide, narrow), (0, 1));
      await tester.pumpWidget(
        _app(200, onWide: () => wide++, onNarrow: () => narrow++),
      );
      await tester.tapAt(const Offset(20, 20));
      expect((wide, narrow), (1, 1));
    });

    testWidgets('only the shown child is in the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        Widget labelled(double width) => _room(
          width,
          FitOrFallback(
            preferred: Semantics(
              label: 'wide one',
              child: const SizedBox(width: 120, height: 30),
            ),
            fallback: Semantics(
              label: 'narrow one',
              child: const SizedBox(width: 40, height: 48),
            ),
          ),
        );
        List<String> labels() {
          final found = <String>[];
          void visit(SemanticsNode node) {
            if (node.label.isNotEmpty) found.add(node.label);
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester
                .renderObject(find.byType(FitOrFallback))
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          return found;
        }

        await tester.pumpWidget(labelled(100));
        expect(labels(), ['narrow one']);
        await tester.pumpWidget(labelled(200));
        expect(labels(), ['wide one']);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('answers intrinsic size queries', (tester) async {
      await tester.pumpWidget(
        _room(
          100,
          IntrinsicHeight(
            child: FitOrFallback(
              preferred: const SizedBox(width: 120, height: 30),
              fallback: const SizedBox(width: 40, height: 48),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FitOrFallback)).height, 48);
    });
  });
}
