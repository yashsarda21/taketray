import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/components/theme.dart';
import 'package:taketray_widgetbook/main.dart';

void main() {
  testWidgets('the catalogue app starts and lists the Theme use cases', (
    tester,
  ) async {
    // A desktop-sized window, so the navigation panel is shown.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TakeTrayCatalogue());
    await tester.pumpAndSettle();

    expect(find.text('Foundations'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    for (final useCase in themeComponent.useCases) {
      expect(find.text(useCase.name), findsOneWidget);
    }
  });

  group('Theme use cases render', () {
    for (final useCase in themeComponent.useCases) {
      for (final (name, theme) in [
        ('light', TakeTrayTheme.light()),
        ('dark', TakeTrayTheme.dark()),
        ('video', TakeTrayTheme.video()),
      ]) {
        testWidgets('${useCase.name} ($name)', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(body: Builder(builder: useCase.builder)),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(Text), findsWidgets);
        });
      }
    }
  });
}
