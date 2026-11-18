import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/views/backup_screen.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fake_backup_actions.dart';
import '../../../support/fake_files_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';

/// The Export and import screen as screenshots (Phase 10B, Task 7, D-150):
/// the screen with a last backup, the import question with VN copies on the
/// phone, and the result of an import; light and dark; and at 2x text.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/settings/views/backup_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

final DateTime _today = DateTime.utc(2026, 11, 17, 12);

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  double textScale = 1,
}) {
  final actions = FakeBackupActions()
    ..copies = true
    ..importAnswer = const ImportDone(fakeImportSummary, 41, 43);
  final files = FakeFilesBridge()..openAnswer = '{}';
  return pumpScreen(
    tester,
    const BackupScreen(),
    overrides: <Override>[
      backupActionsProvider.overrideWithValue(actions),
      filesBridgeProvider.overrideWithValue(files),
      clockProvider.overrideWithValue(FixedClock(_today)),
      lastExportProvider.overrideWith(
        (ref) async => DateTime.utc(2026, 11, 12, 12),
      ),
    ],
    brightness: brightness,
    textScale: textScale,
    size: Size(360, textScale > 1 ? 1400 : 800),
  );
}

Future<void> _openConfirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TtButton, 'Import backup'));
  await tester.pumpAndSettle();
}

Future<void> _openResult(WidgetTester tester) async {
  await _openConfirm(tester);
  await tester.tap(find.widgetWithText(TtButton, 'Import'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (scale, suffix) in [(1.0, ''), (2.0, '_2x')]) {
    for (final brightness in Brightness.values) {
      final name = '${brightness.name}$suffix';

      testWidgets('backup screen, $name', skip: !_goldens, (tester) async {
        await _pump(tester, brightness: brightness, textScale: scale);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/backup_screen_$name.png'),
        );
      });

      testWidgets('backup confirm with copies, $name', skip: !_goldens, (
        tester,
      ) async {
        await _pump(tester, brightness: brightness, textScale: scale);
        await _openConfirm(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/backup_confirm_copies_$name.png'),
        );
      });

      testWidgets('backup imported, $name', skip: !_goldens, (tester) async {
        await _pump(tester, brightness: brightness, textScale: scale);
        await _openResult(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/macos/backup_imported_$name.png'),
        );
      });
    }
  }
}
