import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taketray/data/models.dart';
import 'package:taketray/main.dart';
import 'package:taketray/state/app_state.dart';

void main() {
  testWidgets('Tagging a clip from To tag moves to the next clip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late AppState state;
    await tester.runAsync(() async {
      state = AppState(
        await SampleData.load(),
        await SharedPreferences.getInstance(),
      );
    });
    await tester.pumpWidget(TakeTrayApp(state: state));
    await tester.pump();

    expect(find.text('Reels'), findsWidgets);
    expect(find.text('Shooting mode on'), findsOneWidget);

    await tester.tap(find.text('To tag').last);
    await tester.pump(const Duration(milliseconds: 500));
    final waiting = state.toTag.length;
    expect(find.text('Start tagging'), findsOneWidget);

    await tester.tap(find.text('Start tagging'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1 of $waiting'), findsOneWidget);

    await tester.tap(find.text('London Food').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.toTag.length, waiting - 1);
    expect(find.text('2 of $waiting'), findsOneWidget);
    expect(find.text('Added to London Food'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.toTag.length, waiting);
    await tester.pumpWidget(const SizedBox());
  });
}
