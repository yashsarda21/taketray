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
        _field(const TtTextField(label: 'Reel name', maxLength: 40)),
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
        _field(const TtTextField(label: 'Reel name', maxLength: 40)),
      );
      expect(find.text('0/40'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('3/40'), findsOneWidget);

      await tester.pumpWidget(_field(const TtTextField(label: 'Reel name')));
      expect(find.textContaining('/'), findsNothing);
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
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
