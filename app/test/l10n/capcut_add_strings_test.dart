import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('Phase 8 CapCut and Edits add-later copy, verbatim (D-129)', (
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

    // The section button; the banner's action is "Add more clips" (D-128).
    expect(l10n.reelAddToProject('CapCut'), 'Add to your CapCut project');
    expect(l10n.reelAddToProject('Edits'), 'Add to your Edits project');

    // The picker.
    expect(
      l10n.editAddProjectTitle('CapCut'),
      'Add clips to your CapCut project',
    );
    expect(
      l10n.editAddProjectTitle('Edits'),
      'Add clips to your Edits project',
    );
    expect(l10n.editInTheFolderMark, 'In the folder');
    expect(
      l10n.clipTileSemanticsInTheFolder('Clip, 9:00, 0:05'),
      'Clip, 9:00, 0:05, already in the folder',
    );
    expect(l10n.editAddFolderBarCount(3), '3 clips to copy');
    expect(l10n.editAddFolderBarCount(1), '1 clip to copy');
    expect(
      l10n.editAddFolderBarDetail('300 MB', 'Goa'),
      '300 MB · into Movies/TakeTray/Goa',
    );
    expect(l10n.editAddBarNone, 'Pick clips to add');
    expect(l10n.editAddBarInTheFolder(2), '2 already in the folder');
    expect(
      l10n.editAlreadyInTheFolderSnack,
      'Already in the folder. Copies are deleted when you tap Done editing.',
    );

    // The space check's notes.
    expect(l10n.copySpaceTitle('CapCut'), 'Copy clips for CapCut');
    expect(l10n.copyWhyTitle, 'Why copies?');
    expect(
      l10n.projectCopyWhyBody('CapCut', 'Movies/TakeTray/Goa'),
      'CapCut adds clips to a project from an album. TakeTray copies the '
      'clips you picked to Movies/TakeTray/Goa. Your original clips stay '
      'where they are.',
    );
    expect(l10n.copyTemporaryTitle, 'Copies are temporary');
    expect(
      l10n.projectCopyTemporaryBody('CapCut'),
      'After you export from CapCut, tap Done editing and TakeTray deletes '
      'them.',
    );

    // Progress and ready.
    expect(l10n.copyProgressTitle('CapCut'), 'Copying clips for CapCut');
    expect(l10n.projectReadyTitle('CapCut'), 'Ready to add in CapCut');
    expect(
      l10n.projectReadyIntro('CapCut', '+', 'Goa'),
      'In your CapCut project, tap + and open the Goa album.',
    );
    expect(l10n.projectStep1Title('CapCut'), 'Open your project in CapCut');
    expect(l10n.projectStep1Body, 'The one you started from TakeTray.');
    expect(l10n.projectStep2Title('Goa'), 'Open the Goa album');
    expect(l10n.projectStep2Body, "It's in Movies › TakeTray.");
    expect(l10n.projectStep3Title, 'Pick the new clips');
    expect(l10n.projectStep3Body, "They're in shooting order.");
    expect(l10n.copyOpenEditor('CapCut'), 'Open CapCut');
    expect(l10n.copyDone, 'Done');
  });
}
