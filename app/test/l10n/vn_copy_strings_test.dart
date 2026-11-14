import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('Phase 8 VN copy screens copy, verbatim (D-127)', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The space check.
    expect(l10n.copySpaceTitle('VN'), 'Copy clips for VN');
    expect(l10n.copySpaceNeed(12, '900 MB'), 'These 12 clips need 900 MB');
    expect(l10n.copySpaceNeed(1, '900 MB'), 'This clip needs 900 MB');
    expect(l10n.copySpaceFree('6.2 GB'), 'You have 6.2 GB free.');
    expect(l10n.copyLegendCopies('900 MB'), 'Copies: 900 MB');
    expect(l10n.copyLegendFreeAfter('5.3 GB'), 'Free after copying: 5.3 GB');
    expect(
      l10n.copyReserveNote('500 MB'),
      'TakeTray keeps 500 MB free for your phone.',
    );
    expect(l10n.copyWhyTitle, 'Why copies?');
    expect(
      l10n.vnCopyWhyBody('Movies/TakeTray/Goa'),
      'VN needs all the clips in one folder. TakeTray copies them to '
      'Movies/TakeTray/Goa. Your original clips stay where they are.',
    );
    expect(l10n.copyTemporaryTitle, 'Copies are temporary');
    expect(
      l10n.vnCopyTemporaryBody,
      'After you export from VN, tap Done editing and TakeTray deletes them.',
    );
    expect(l10n.copyStart(12), 'Copy 12 clips');
    expect(l10n.copyStart(1), 'Copy 1 clip');
    expect(l10n.copyBack, 'Back');
    expect(l10n.copyShortTitle, 'Not enough space');
    expect(
      l10n.copyShortBody(12, '2.4 GB', '1.1 GB'),
      'These 12 clips need 2.4 GB. You have 1.1 GB free.',
    );
    expect(l10n.copyShortHave('1.1 GB'), 'You have 1.1 GB');
    expect(l10n.copyShortBy('300 MB'), 'Short by 300 MB');
    expect(l10n.copyShortHelpTitle, 'What you can do');
    expect(
      l10n.copyShortHelpBody,
      'Select fewer clips, or free up space on your phone and try again.',
    );
    expect(l10n.copySelectFewer, 'Select fewer clips');
    expect(l10n.copyStartFailed, "Couldn't start copying. Try again.");

    // Copying, and the Stop dialog.
    expect(l10n.copyProgressTitle('VN'), 'Copying clips for VN');
    expect(l10n.copyProgressCount(7, 12), '7 of 12 clips');
    expect(
      l10n.copyProgressBytes('600 MB', '900 MB', 'Goa'),
      '600 MB of 900 MB · into Movies/TakeTray/Goa',
    );
    expect(
      l10n.copyKeepOpen,
      'Keep TakeTray open until copying finishes. '
      'The screen stays on until then.',
    );
    expect(l10n.copyPercent(40), '40%');
    expect(l10n.copyStopTitle, 'Stop copying?');
    expect(
      l10n.copyStopBody(7),
      "The 7 copies made so far will be deleted. Your original clips aren't "
      'affected.',
    );
    expect(l10n.copyKeepCopying, 'Keep copying');
    expect(l10n.copyStop, 'Stop');
    expect(l10n.copyStoppedFirst, 'Copying stopped. No copies were kept.');
    expect(
      l10n.copyStoppedAdd,
      'Copying stopped. The new copies were deleted.',
    );

    // The ways it can end.
    expect(l10n.copySpaceFullTitle, 'Phone storage is full');
    expect(
      l10n.copySpaceFullBody(7, 12),
      '7 of 12 clips were copied before space ran out. '
      'Free up some space, then try again.',
    );
    expect(l10n.copyDeleteStop, 'Delete copies and stop');
    expect(l10n.copyInterruptedTitle, 'Copying stopped');
    expect(
      l10n.copyInterruptedBody(7, 12),
      'TakeTray was closed before copying finished. '
      '7 of 12 clips were copied.',
    );
    expect(
      l10n.copyStorageErrorBody(7, 12),
      "The phone couldn't save the copies. 7 of 12 clips were copied.",
    );
    expect(l10n.copyFailedTitle(1), "1 clip couldn't be copied");
    expect(l10n.copyFailedTitle(3), "3 clips couldn't be copied");
    expect(
      l10n.copyFailedOneBody('9:41 AM', 11),
      'The clip from 9:41 AM may have been deleted or moved. '
      'The other 11 clips were copied.',
    );
    expect(
      l10n.copyFailedManyBody(9),
      'They may have been deleted or moved. The other 9 clips were copied.',
    );
    expect(l10n.copyContinueWith(11), 'Continue with 11 clips');
    expect(l10n.copyContinueWith(1), 'Continue with 1 clip');
    expect(l10n.copyAllFailedTitle(12), "The clips couldn't be copied");
    expect(l10n.copyAllFailedBody(12), 'They may have been deleted or moved.');
    expect(l10n.copyAddedSnack(3, 'VN'), '3 clips added to the VN folder');

    // Ready.
    expect(l10n.copyReadyTitle('VN'), 'Ready for VN');
    expect(
      l10n.vnReadyIntro('New project', 'Goa'),
      'In VN, tap New project and open the Goa folder.',
    );
    expect(l10n.copyStepNumber(2), 'Step 2');
    expect(l10n.vnStep1Title, 'Open VN, tap New project');
    expect(l10n.vnStep1Body, "It's the big + button.");
    expect(l10n.vnStep2Title('Goa'), 'Open the Goa folder');
    expect(l10n.vnStep2Body, 'Inside Movies › TakeTray.');
    expect(l10n.vnStep3Title, 'Select all the clips');
    expect(l10n.vnStep3Body, "They're already in shooting order.");
    expect(l10n.copyOpenEditor('VN'), 'Open VN');
    expect(l10n.copyDone, 'Done');
  });

  testWidgets('the keep-open line no longer says copying continues', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // screens.js:414 said "You can leave the app; copying continues." There
    // is no foreground service (D-118), so leaving can end the copy.
    expect(l10n.copyKeepOpen.toLowerCase(), isNot(contains('leave')));
    expect(l10n.copyKeepOpen.toLowerCase(), isNot(contains('continues')));
    expect(l10n.copyKeepOpen, contains('Keep TakeTray open'));
  });
}
