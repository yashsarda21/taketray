import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/views/backup_screen.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_backup_actions.dart';
import '../../../support/fake_files_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';

/// The day the tests are on: a backup date in its year has no year.
final DateTime _today = DateTime.utc(2026, 11, 17, 12);

const _exportBody =
    "Saves your reels, tags and shot ideas to a file. Your videos aren't in "
    'it; they stay in your gallery.';
const _importBody =
    'Brings back reels and tags from a backup made on this phone. It '
    'replaces everything in the app now.';
const _newPhoneBody =
    "That isn't supported yet. A backup only links to videos on this phone, "
    'so on a new phone every clip would show as missing.';
const _confirmBody =
    'Importing replaces everything in TakeTray now. Your videos are not '
    'touched.';
const _copiesSentence =
    'VN copies already on this phone stay there and show on the VN copies '
    'screen, where you can delete them.';
const _notBackup = "This file isn't a TakeTray backup.";
const _newer =
    'This backup is from a newer TakeTray. Update the app, then try again.';
const _damaged = 'This backup is damaged, so nothing was changed.';
const _tooBig = 'This file is too big to be a TakeTray backup.';
const _copying = 'Copying is still running. Try again when it finishes.';

/// What a test pumped: the fakes, and the stored backup date (a good
/// `recordExport` moves it to the clock's time).
class PumpedBackup {
  PumpedBackup(this.actions, this.files);

  final FakeBackupActions actions;
  final FakeFilesBridge files;
  DateTime? stored;
}

Future<PumpedBackup> pump(
  WidgetTester tester, {
  DateTime? lastExport,
  FakeBackupActions? actions,
  FakeFilesBridge? files,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  final screen = PumpedBackup(
    actions ?? FakeBackupActions(),
    files ?? FakeFilesBridge(),
  )..stored = lastExport;
  screen.actions.onRecord = () => screen.stored = _today;
  await pumpScreen(
    tester,
    const BackupScreen(),
    overrides: <Override>[
      backupActionsProvider.overrideWithValue(screen.actions),
      filesBridgeProvider.overrideWithValue(screen.files),
      clockProvider.overrideWithValue(FixedClock(_today)),
      lastExportProvider.overrideWith((ref) async => screen.stored),
    ],
    brightness: brightness,
    textScale: textScale,
    size: size,
  );
  return screen;
}

/// A [Text] whose words are [text], whatever kind of space is between them
/// (dates use no-break spaces).
Finder plainText(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll(
            RegExp('[  ]'),
            ' ',
          ) ==
          text,
  description: 'a Text showing "$text"',
);

Finder button(String label) => find.widgetWithText(TtButton, label);

bool enabled(WidgetTester tester, String label) =>
    tester.widget<TtButton>(button(label)).onPressed != null;

Finder get exportSection => find.byKey(const ValueKey('backup-export'));
Finder get importSection => find.byKey(const ValueKey('backup-import'));

/// Taps **Import backup** and lets the confirm dialog open.
Future<void> openConfirm(WidgetTester tester) async {
  await tester.tap(button('Import backup'));
  await tester.pumpAndSettle();
}

/// Taps **Import backup**, then **Import** in the dialog.
Future<void> confirmImport(WidgetTester tester) async {
  await openConfirm(tester);
  await tester.tap(find.widgetWithText(TtButton, 'Import'));
  await tester.pumpAndSettle();
}

void main() {
  group('the page', () {
    testWidgets('title, both sections, the buttons and the new phone '
        'callout', (tester) async {
      await pump(tester);

      expect(find.text('Export and import'), findsOneWidget);
      expect(find.text('Export a backup'), findsOneWidget);
      expect(find.text(_exportBody), findsOneWidget);
      expect(button('Export backup'), findsOneWidget);
      expect(find.text('Import a backup'), findsOneWidget);
      expect(find.text(_importBody), findsOneWidget);
      expect(button('Import backup'), findsOneWidget);
      expect(find.text('Moving to a new phone?'), findsOneWidget);
      expect(find.text(_newPhoneBody), findsOneWidget);
      expect(find.byType(TtCallout), findsOneWidget);
      expect(tester.widget<TtCallout>(find.byType(TtCallout)).warning, isTrue);
      expect(find.byType(TtProgressBar), findsNothing);
    });

    testWidgets('the export button is filled and the import one outlined', (
      tester,
    ) async {
      await pump(tester);

      expect(
        tester.widget<TtButton>(button('Export backup')).kind,
        TtButtonKind.filled,
      );
      expect(
        tester.widget<TtButton>(button('Import backup')).kind,
        TtButtonKind.outlined,
      );
    });

    testWidgets('the sections in order: export, import, the callout', (
      tester,
    ) async {
      await pump(tester);

      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(exportSection), lessThan(top(importSection)));
      expect(top(importSection), lessThan(top(find.byType(TtCallout))));
      expect(
        find.descendant(of: exportSection, matching: button('Export backup')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: importSection, matching: button('Import backup')),
        findsOneWidget,
      );
    });

    testWidgets('no backup yet', (tester) async {
      await pump(tester);

      expect(
        find.descendant(
          of: exportSection,
          matching: find.text('No backup yet'),
        ),
        findsOneWidget,
      );
    });

    for (final (time, text) in [
      (DateTime.utc(2026, 11, 12, 12), 'Last backup: Nov 12'),
      (DateTime.utc(2025, 3, 5, 12), 'Last backup: Mar 5, 2025'),
    ]) {
      testWidgets('a backup on ${time.toIso8601String()}: "$text", as the '
          'Settings row says it', (tester) async {
        await pump(tester, lastExport: time);

        expect(
          find.descendant(of: exportSection, matching: plainText(text)),
          findsOneWidget,
        );
      });
    }

    testWidgets('fits at 2x text without overflow', (tester) async {
      await pump(tester, textScale: 2, size: const Size(360, 2000));

      expect(tester.takeException(), isNull);
      expect(button('Export backup'), findsOneWidget);
      expect(button('Import backup'), findsOneWidget);
    });

    testWidgets('meets the accessibility guidelines', (tester) async {
      await pump(tester, lastExport: DateTime.utc(2026, 11, 12, 12));

      await expectTtAccessible(tester);
    });

    testWidgets('meets them in dark', (tester) async {
      await pump(tester, brightness: Brightness.dark);

      await expectTtAccessible(tester);
    });
  });

  group('export', () {
    testWidgets('saved: "Backup saved", recorded once, and the date shows '
        'at once', (tester) async {
      final s = await pump(tester);

      await tester.tap(button('Export backup'));
      await tester.pumpAndSettle();

      expect(find.text('Backup saved'), findsOneWidget);
      expect(s.actions.records, 1);
      expect(s.files.saved.single.name, 'taketray-backup-2026-11-17.json');
      expect(
        find.descendant(
          of: exportSection,
          matching: plainText('Last backup: Nov 17'),
        ),
        findsOneWidget,
      );
      expect(find.text('No backup yet'), findsNothing);
    });

    testWidgets('cancelled: nothing recorded, no message', (tester) async {
      final s = await pump(tester, lastExport: DateTime.utc(2026, 11, 12, 12));
      s.files.saveAnswer = null;

      await tester.tap(button('Export backup'));
      await tester.pumpAndSettle();

      expect(s.actions.records, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.descendant(
          of: exportSection,
          matching: plainText('Last backup: Nov 12'),
        ),
        findsOneWidget,
      );
      expect(enabled(tester, 'Export backup'), isTrue);
    });

    testWidgets("the save fails: \"Couldn't save the backup.\", nothing "
        'recorded', (tester) async {
      final s = await pump(tester);
      s.files.failNext('saveDocument');

      await tester.tap(button('Export backup'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save the backup."), findsOneWidget);
      expect(find.text('Backup saved'), findsNothing);
      expect(s.actions.records, 0);
      expect(find.text('No backup yet'), findsOneWidget);
      expect(enabled(tester, 'Export backup'), isTrue);
    });

    testWidgets("the backup text cannot be made: \"Couldn't save the "
        'backup."', (tester) async {
      final s = await pump(tester);
      s.actions.exportError = StateError('database closed');

      await tester.tap(button('Export backup'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save the backup."), findsOneWidget);
      expect(s.files.calls, isEmpty);
    });

    testWidgets('while the picker is open both buttons are off and the '
        'export section shows progress', (tester) async {
      final s = await pump(tester);
      s.files.hold('saveDocument');

      await tester.tap(button('Export backup'));
      await tester.pump();

      expect(enabled(tester, 'Export backup'), isFalse);
      expect(enabled(tester, 'Import backup'), isFalse);
      expect(
        find.descendant(
          of: exportSection,
          matching: find.byType(TtProgressBar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: importSection,
          matching: find.byType(TtProgressBar),
        ),
        findsNothing,
      );
      expect(
        tester.widget<TtProgressBar>(find.byType(TtProgressBar)).semanticLabel,
        'Saving the backup',
      );

      s.files.release('saveDocument');
      await tester.pumpAndSettle();

      expect(enabled(tester, 'Export backup'), isTrue);
      expect(enabled(tester, 'Import backup'), isTrue);
      expect(find.byType(TtProgressBar), findsNothing);
    });

    testWidgets('double taps start one export', (tester) async {
      final s = await pump(tester);
      s.files.hold('saveDocument');

      await tester.tap(button('Export backup'));
      await tester.tap(button('Export backup'));
      await tester.pump();

      expect(s.files.methods, ['saveDocument']);
      s.files.release('saveDocument');
      await tester.pumpAndSettle();
      expect(s.actions.records, 1);
      expect(find.text('Backup saved'), findsOneWidget);
    });
  });

  group('import: the question first', () {
    testWidgets('"Import a backup?" with what it does, Cancel and Import', (
      tester,
    ) async {
      final s = await pump(tester);

      await openConfirm(tester);

      expect(find.byType(TtDialog<bool>), findsOneWidget);
      expect(find.text('Import a backup?'), findsOneWidget);
      expect(find.text(_confirmBody), findsOneWidget);
      expect(find.text(_copiesSentence), findsNothing);
      final dialog = tester.widget<TtDialog<bool>>(find.byType(TtDialog<bool>));
      expect([for (final a in dialog.actions) a.label], ['Cancel', 'Import']);
      expect(dialog.actions.last.destructive, isTrue);
      expect(s.files.calls, isEmpty, reason: 'no picker before the answer');
    });

    testWidgets('with VN copies on the phone it says they stay', (
      tester,
    ) async {
      final s = await pump(tester);
      s.actions.copies = true;

      await openConfirm(tester);

      expect(find.text(_confirmBody), findsOneWidget);
      expect(find.text(_copiesSentence), findsOneWidget);
    });

    testWidgets('the copies are asked about each time', (tester) async {
      final s = await pump(tester);
      await openConfirm(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Cancel'));
      await tester.pumpAndSettle();
      s.actions.copies = true;

      await openConfirm(tester);

      expect(find.text(_copiesSentence), findsOneWidget);
    });

    testWidgets('Cancel never opens the picker', (tester) async {
      final s = await pump(tester);
      await openConfirm(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(s.files.calls, isEmpty);
      expect(s.actions.imported, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a tap outside the question never opens the picker', (
      tester,
    ) async {
      final s = await pump(tester);
      await openConfirm(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(s.files.calls, isEmpty);
    });

    testWidgets('Back never opens the picker', (tester) async {
      final s = await pump(tester);
      await openConfirm(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(s.files.calls, isEmpty);
    });

    testWidgets('double taps ask once', (tester) async {
      final s = await pump(tester);
      // The question waits for the copies to be checked: the second tap
      // lands on the button, not on the dialog's scrim.
      s.actions.holdCopies();

      await tester.tap(button('Import backup'));
      await tester.pump();
      await tester.tap(button('Import backup'));
      await tester.pump();
      s.actions.releaseCopies();
      await tester.pumpAndSettle();

      expect(find.byType(TtDialog<bool>), findsOneWidget);
      expect(s.actions.log, ['hasCopies']);
    });
  });

  group('import: export waits for the question', () {
    testWidgets('Export tapped while the copies are checked does nothing, '
        'and the import then runs', (tester) async {
      final s = await pump(tester);
      s.files.openAnswer = '{}';
      s.actions.holdCopies();

      await tester.tap(button('Import backup'));
      await tester.pump();
      await tester.tap(button('Export backup'));
      await tester.pump();
      s.actions.releaseCopies();
      await tester.pumpAndSettle();

      expect(s.files.calls, isEmpty, reason: 'no save picker');
      expect(s.actions.log, ['hasCopies']);
      await tester.tap(find.widgetWithText(TtButton, 'Import'));
      await tester.pumpAndSettle();

      expect(s.files.methods, ['openDocument']);
      expect(find.text('Backup imported'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('after the question is cancelled Export works again', (
      tester,
    ) async {
      final s = await pump(tester);
      await openConfirm(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(button('Export backup'));
      await tester.pumpAndSettle();

      expect(s.files.methods, ['saveDocument']);
      expect(find.text('Backup saved'), findsOneWidget);
    });
  });

  group('import: the picker', () {
    testWidgets('Import opens the picker for a backup of up to 20 MB', (
      tester,
    ) async {
      final s = await pump(tester);

      await confirmImport(tester);

      expect(s.files.methods, ['openDocument']);
      expect(s.files.calls.single.args, [
        ['application/json', 'text/plain', '*/*'],
        20 * 1024 * 1024,
      ]);
    });

    testWidgets('a cancelled picker shows nothing and imports nothing', (
      tester,
    ) async {
      final s = await pump(tester);

      await confirmImport(tester);

      expect(s.actions.imported, isEmpty);
      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(find.byType(TtDialog<void>), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(enabled(tester, 'Import backup'), isTrue);
    });

    testWidgets('the picker fails: "Something went wrong. Try again.", no '
        'result', (tester) async {
      final s = await pump(tester);
      s.files.failNext('openDocument');

      await confirmImport(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Backup imported'), findsNothing);
      expect(find.textContaining('found'), findsNothing);
      expect(enabled(tester, 'Import backup'), isTrue);
    });

    testWidgets('the import fails with something that is not a bad file: '
        '"Something went wrong. Try again.", no result', (tester) async {
      final s = await pump(tester);
      s.files.openAnswer = '{}';
      s.actions.importError = StateError('disk full');

      await confirmImport(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Backup imported'), findsNothing);
      expect(find.textContaining('found'), findsNothing);
    });

    testWidgets('while the picker is open and the import runs both buttons '
        'are off and the import section shows progress', (tester) async {
      final s = await pump(tester);
      s.files.openAnswer = '{}';
      s.actions.holdImport();

      await confirmImport(tester);

      expect(enabled(tester, 'Export backup'), isFalse);
      expect(enabled(tester, 'Import backup'), isFalse);
      expect(
        find.descendant(
          of: importSection,
          matching: find.byType(TtProgressBar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: exportSection,
          matching: find.byType(TtProgressBar),
        ),
        findsNothing,
      );
      expect(
        tester.widget<TtProgressBar>(find.byType(TtProgressBar)).semanticLabel,
        'Importing the backup',
      );

      s.actions.releaseImport();
      await tester.pumpAndSettle();

      expect(find.text('Backup imported'), findsOneWidget);
      expect(find.byType(TtProgressBar), findsNothing);
    });
  });

  group('import: the result', () {
    for (final (name, result, title, body)
        in <(String, ImportResult, String, String?)>[
          (
            'done, some found',
            const ImportDone(fakeImportSummary, 3, 4),
            'Backup imported',
            '3 of 4 clips found.',
          ),
          (
            'done, none found',
            const ImportDone(fakeImportSummary, 0, 4),
            'Backup imported',
            '0 of 4 clips found.',
          ),
          (
            'done, one clip',
            const ImportDone(fakeImportSummary, 1, 1),
            'Backup imported',
            '1 of 1 clip found.',
          ),
          (
            'done, no clips',
            const ImportDone(fakeImportSummary, 0, 0),
            'Backup imported',
            '0 of 0 clips found.',
          ),
          ('copying', const ImportBusyCopying(), _copying, null),
          (
            'not JSON',
            const ImportRefused(BackupProblem.notJson),
            _notBackup,
            null,
          ),
          (
            'not TakeTray',
            const ImportRefused(BackupProblem.notTakeTray),
            _notBackup,
            null,
          ),
          (
            'newer',
            const ImportRefused(BackupProblem.newerVersion),
            _newer,
            null,
          ),
          (
            'damaged',
            const ImportRefused(BackupProblem.invalidData),
            _damaged,
            null,
          ),
          ('too large', const ImportTooLarge(), _tooBig, null),
        ]) {
      testWidgets('$name: "$title"${body == null ? '' : ' / "$body"'}', (
        tester,
      ) async {
        final s = await pump(tester);
        s.files.openAnswer = '{"a backup":1}';
        s.actions.importAnswer = result;

        await confirmImport(tester);

        expect(s.actions.imported, ['{"a backup":1}']);
        expect(find.byType(TtDialog<void>), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        if (body != null) {
          expect(find.text(body), findsOneWidget);
        } else {
          // "X of Y clips found" never shows for an import that did not
          // happen.
          expect(find.textContaining('found'), findsNothing);
          expect(find.text('Backup imported'), findsNothing);
        }
        expect(find.byType(SnackBar), findsNothing);

        await tester.tap(find.widgetWithText(TtButton, 'OK'));
        await tester.pumpAndSettle();
        expect(find.byType(TtDialog<void>), findsNothing);
        expect(enabled(tester, 'Import backup'), isTrue);
      });
    }

    testWidgets('a file over 20 MB at the picker: "$_tooBig", nothing '
        'imported', (tester) async {
      final s = await pump(tester);
      s.files.failNext('openDocument', FilesProblem.tooLarge);

      await confirmImport(tester);

      expect(s.actions.imported, isEmpty);
      expect(find.text(_tooBig), findsOneWidget);
      expect(find.textContaining('found'), findsNothing);
    });

    testWidgets('an import does not change the backup date', (tester) async {
      final s = await pump(tester, lastExport: DateTime.utc(2026, 11, 12, 12));
      s.files.openAnswer = '{}';

      await confirmImport(tester);
      await tester.tap(find.widgetWithText(TtButton, 'OK'));
      await tester.pumpAndSettle();

      expect(s.actions.records, 0);
      expect(
        find.descendant(
          of: exportSection,
          matching: plainText('Last backup: Nov 12'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the result dialog meets the accessibility guidelines', (
      tester,
    ) async {
      final s = await pump(tester);
      s.files.openAnswer = '{}';

      await confirmImport(tester);

      await expectTtAccessible(tester);
    });
  });
}
