import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _field(Widget field, {Brightness brightness = Brightness.light}) =>
    ttTestApp(
      Padding(padding: const EdgeInsets.all(16), child: field),
      brightness: brightness,
    );

String _counter(int length, int max) => '$length/$max';

void main() {
  group('TtTextField', () {
    testWidgets('shows its label and hint', (tester) async {
      await tester.pumpWidget(
        _field(const TtTextField(label: 'Reel name', hint: 'London Food')),
      );
      expect(find.text('Reel name'), findsOneWidget);
      expect(find.text('London Food'), findsOneWidget);
    });

    testWidgets('reports typing and submitting', (tester) async {
      final changes = <String>[];
      final submits = <String>[];
      await tester.pumpWidget(
        _field(
          TtTextField(
            label: 'Reel name',
            onChanged: changes.add,
            onSubmitted: submits.add,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Tokyo');
      expect(changes, ['Tokyo']);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submits, ['Tokyo']);
    });

    testWidgets('uses and updates a given controller', (tester) async {
      final controller = TextEditingController(text: 'Rome');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _field(TtTextField(label: 'Reel name', controller: controller)),
      );
      expect(find.text('Rome'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Paris');
      expect(controller.text, 'Paris');
    });

    testWidgets('maxLength 40 refuses a 41st character', (tester) async {
      await tester.pumpWidget(
        _field(
          const TtTextField(
            label: 'Reel name',
            maxLength: 40,
            counterText: _counter,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a' * 40);
      await tester.pump();
      expect(find.text('40/40'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '${'a' * 40}b');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'a' * 40);
      expect(find.text('40/40'), findsOneWidget);
    });

    testWidgets('the counter counts up from 0 and shows only with maxLength', (
      tester,
    ) async {
      await tester.pumpWidget(
        _field(
          const TtTextField(
            label: 'Reel name',
            maxLength: 40,
            counterText: _counter,
          ),
        ),
      );
      expect(find.text('0/40'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('3/40'), findsOneWidget);

      await tester.pumpWidget(_field(const TtTextField(label: 'Reel name')));
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('the counter text comes from the caller', (tester) async {
      await tester.pumpWidget(
        _field(
          TtTextField(
            label: 'Reel name',
            maxLength: 40,
            counterText: (length, max) => '$length of $max used',
          ),
        ),
      );
      expect(find.text('0 of 40 used'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('3 of 40 used'), findsOneWidget);
    });

    test('maxLength without a counterText is a programming error', () {
      expect(
        () => TtTextField(label: 'Reel name', maxLength: 40),
        throwsAssertionError,
      );
    });

    testWidgets('text field error is in semantics', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _field(
            const TtTextField(label: 'Reel name', error: 'Name already used'),
          ),
        );
        final node = tester.getSemantics(find.byType(EditableText));
        expect(node.hint, contains('Name already used'));

        await tester.pumpWidget(_field(const TtTextField(label: 'Reel name')));
        expect(
          tester.getSemantics(find.byType(EditableText)).hint,
          isNot(contains('Name already used')),
        );
      } finally {
        handle.dispose();
      }
    });

    group('swapping the controller', () {
      Future<void> pumpWith(
        WidgetTester tester,
        TextEditingController? controller,
      ) => tester.pumpWidget(
        _field(TtTextField(label: 'Reel name', controller: controller)),
      );

      String shown(WidgetTester tester) =>
          tester.widget<TextField>(find.byType(TextField)).controller!.text;

      testWidgets('swapping controller keeps text (own to given)', (
        tester,
      ) async {
        await pumpWith(tester, null);
        await tester.enterText(find.byType(TextField), 'typed');
        final given = TextEditingController();
        addTearDown(given.dispose);
        await pumpWith(tester, given);
        expect(given.text, 'typed');
        expect(shown(tester), 'typed');
        expect(tester.takeException(), isNull);
      });

      testWidgets('a given controller that has text keeps its own text', (
        tester,
      ) async {
        await pumpWith(tester, null);
        await tester.enterText(find.byType(TextField), 'typed');
        final given = TextEditingController(text: 'theirs');
        addTearDown(given.dispose);
        await pumpWith(tester, given);
        expect(given.text, 'theirs');
        expect(shown(tester), 'theirs');
      });

      testWidgets('swapping controller keeps text (given to own)', (
        tester,
      ) async {
        final given = TextEditingController(text: 'theirs');
        addTearDown(given.dispose);
        await pumpWith(tester, given);
        await tester.enterText(find.byType(TextField), 'edited');
        await pumpWith(tester, null);
        expect(shown(tester), 'edited');
        expect(given.text, 'edited');
        expect(tester.takeException(), isNull);
      });

      testWidgets('given to another given leaves both alone', (tester) async {
        final a = TextEditingController(text: 'a');
        final b = TextEditingController();
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        await pumpWith(tester, a);
        await pumpWith(tester, b);
        expect(a.text, 'a');
        expect(b.text, '');
        expect(shown(tester), '');
      });

      testWidgets('the counter follows a swapped controller', (tester) async {
        Widget field(TextEditingController? c) => _field(
          TtTextField(
            label: 'Reel name',
            controller: c,
            maxLength: 40,
            counterText: _counter,
          ),
        );
        await tester.pumpWidget(field(null));
        await tester.enterText(find.byType(TextField), 'abc');
        final given = TextEditingController();
        addTearDown(given.dispose);
        await tester.pumpWidget(field(given));
        expect(find.text('3/40'), findsOneWidget);
        given.text = 'abcde';
        await tester.pump();
        expect(find.text('5/40'), findsOneWidget);
      });
    });

    testWidgets('the error icon scales with text', (tester) async {
      Future<double> iconSize(double scale) async {
        await tester.pumpWidget(
          ttTestApp(
            const Padding(
              padding: EdgeInsets.all(16),
              child: TtTextField(label: 'Reel name', error: 'Oops'),
            ),
            textScale: scale,
          ),
        );
        return tester.getSize(find.byIcon(Symbols.error_rounded)).width;
      }

      final one = await iconSize(1);
      final two = await iconSize(2);
      expect(two, closeTo(one * 2, 0.01));
    });

    testWidgets('the helper shows under the box', (tester) async {
      await tester.pumpWidget(
        _field(const TtTextField(label: 'Reel name', helper: 'Press Enter')),
      );
      expect(find.text('Press Enter'), findsOneWidget);
    });

    testWidgets('an error replaces the helper and shows the error icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _field(
          const TtTextField(
            label: 'Reel name',
            helper: 'Press Enter',
            error: 'Name already used',
          ),
        ),
      );
      expect(find.text('Name already used'), findsOneWidget);
      expect(find.text('Press Enter'), findsNothing);
      expect(find.byIcon(Symbols.error_rounded), findsOneWidget);

      await tester.pumpWidget(
        _field(const TtTextField(label: 'Reel name', helper: 'Press Enter')),
      );
      expect(find.byIcon(Symbols.error_rounded), findsNothing);
    });

    testWidgets('multiline is a taller box and accepts new lines', (
      tester,
    ) async {
      await tester.pumpWidget(_field(const TtTextField(label: 'Notes')));
      final single = tester.getSize(find.byType(TextField)).height;
      await tester.pumpWidget(
        _field(const TtTextField(label: 'Notes', multiline: true)),
      );
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThan(single),
      );
      await tester.enterText(find.byType(TextField), 'one\ntwo');
      expect(find.text('one\ntwo'), findsOneWidget);
    });

    testWidgets('the box is at least 56 dp high', (tester) async {
      await tester.pumpWidget(_field(const TtTextField(label: 'Reel name')));
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(56),
      );
    });

    testWidgets('autofocus focuses the field', (tester) async {
      await tester.pumpWidget(
        _field(const TtTextField(label: 'Reel name', autofocus: true)),
      );
      await tester.pump();
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          _field(
            const TtTextField(
              label: 'Reel name',
              hint: 'London Food',
              helper: 'Press Enter to add the next one',
              maxLength: 40,
              counterText: _counter,
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });

      testWidgets('the error state passes the guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          _field(
            const TtTextField(label: 'Reel name', error: 'Name already used'),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }

    testWidgets('long text and a long error do not overflow at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Padding(
            padding: EdgeInsets.all(16),
            child: TtTextField(
              label: 'A very long label for the reel name field',
              error: 'This name is already used by another reel in this tray',
              maxLength: 40,
              counterText: _counter,
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
