import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('Phase 8 reel page while editing copy, verbatim (D-128)', (
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

    // The short editor name of the pill, banner and section button (R8).
    expect(l10n.editorShortEdits, 'Edits');

    // The banner.
    expect(l10n.reelEditingIn('CapCut'), 'Editing in CapCut');
    expect(l10n.reelEditingInSize('VN', '900 MB'), 'Editing in VN · 900 MB');
    expect(
      l10n.reelEditingCopies(12, 'Goa'),
      '12 copies in Movies/TakeTray/Goa',
    );
    expect(l10n.reelEditingCopies(1, 'Goa'), '1 copy in Movies/TakeTray/Goa');
    expect(l10n.reelEditingSentOn('Nov 12'), 'Sent on Nov 12');
    expect(
      l10n.reelEditingSentOnCopies('Nov 12', 3, 'Goa'),
      'Sent on Nov 12 · 3 copies in Movies/TakeTray/Goa',
    );
    expect(
      l10n.reelEditingSentOnCopies('Nov 12', 1, 'Goa'),
      'Sent on Nov 12 · 1 copy in Movies/TakeTray/Goa',
    );
    expect(l10n.reelDoneEditing, 'Done editing');
    expect(l10n.reelAddMoreClips, 'Add more clips');
    expect(l10n.reelCopyShow, 'Show');

    // The sections.
    expect(l10n.reelNewSinceTitle, 'New since you started editing');
    expect(l10n.reelNewSinceSubtitle(3), '3 clips · not in your edit yet');
    expect(l10n.reelNewSinceSubtitle(1), '1 clip · not in your edit yet');
    expect(l10n.reelCopyToFolder('VN'), 'Copy to VN folder');
    expect(l10n.reelInEditTitle, 'In your edit');
    expect(l10n.reelInEditFolder(12, 'VN'), '12 clips · in the VN folder');
    expect(l10n.reelInEditFolder(1, 'VN'), '1 clip · in the VN folder');
    expect(
      l10n.reelInEditSent(12, 'CapCut', 'Nov 12'),
      '12 clips · sent to CapCut on Nov 12',
    );
    expect(
      l10n.reelInEditSent(1, 'Edits', 'Nov 12'),
      '1 clip · sent to Edits on Nov 12',
    );

    // The card.
    expect(
      l10n.reelCardSemanticsEditing(
        'Goa. Collecting. 3 clips',
        'Editing in VN',
      ),
      'Goa. Collecting. 3 clips. Editing in VN',
    );

    // Add mode.
    expect(l10n.editAddTitle('VN'), 'Add clips to VN folder');
    expect(l10n.editInFolderMark('VN'), 'In VN folder');
    expect(
      l10n.clipTileSemanticsInFolder('Clip, 9:41 AM, 0:04', 'VN'),
      'Clip, 9:41 AM, 0:04, already in VN folder',
    );
    expect(l10n.editAddBarCount(2), '2 new clips to copy');
    expect(l10n.editAddBarCount(1), '1 new clip to copy');
    expect(
      l10n.editAddBarDetail('900 MB'),
      '900 MB · copies are added, never renamed',
    );
    expect(l10n.editAddBarNone, 'Pick clips to add');
    expect(l10n.editAddBarInFolder(4, 'VN'), '4 already in the VN folder');
    expect(l10n.editAddCopy, 'Copy');
    expect(
      l10n.editAlreadyInFolderSnack('VN'),
      'Already in the VN folder. Copies are deleted when you tap Done '
      'editing.',
    );

    // Done editing.
    expect(l10n.doneEditingExportedTitle, 'Have you exported your video?');
    expect(
      l10n.doneEditingVnBody('Goa', '900 MB'),
      "Once the copies are deleted, the VN project for Goa can't be edited "
      'any more. This frees 900 MB.',
    );
    expect(
      l10n.doneEditingCopiesBody('CapCut', '900 MB'),
      'Once the copies are deleted, clips you added to your CapCut project '
      'from the folder may show as missing. This frees 900 MB.',
    );
    expect(
      l10n.doneEditingSafe,
      'Your original clips are safe in your gallery.',
    );
    expect(l10n.doneEditingNotYet, 'Not yet');
    expect(l10n.doneEditingDeleteCopies, 'Delete copies');
    expect(
      l10n.doneEditingFreedSnack('900 MB'),
      'Copies deleted · 900 MB freed',
    );
    expect(
      l10n.doneEditingFreedLeftSnack('900 MB', 1),
      'Copies deleted · 900 MB freed. 1 file was changed outside TakeTray, '
      'so it was left in the folder.',
    );
    expect(l10n.doneEditingTitle('Goa'), 'Done editing Goa?');
    expect(
      l10n.doneEditingNoCopiesBody('CapCut'),
      'TakeTray stops showing which clips are in your CapCut project. '
      'Nothing is deleted.',
    );
    expect(l10n.doneEditingSnack('Goa'), 'Done editing Goa');
    expect(l10n.copiesNotDeleted, "Couldn't delete the copies. Try again.");

    // The delete dialog.
    expect(
      l10n.deleteReelVnCopies(12, '900 MB'),
      'The 12 VN copies (900 MB) will also be deleted, and the VN project '
      "can't be edited after that.",
    );
    expect(
      l10n.deleteReelFolderCopies(3, 'Goa', '900 MB'),
      'The 3 copies in Movies/TakeTray/Goa (900 MB) will also be deleted.',
    );

    // The remove and move snacks.
    expect(l10n.copiesDeletedSuffix(1), 'Its copy in the folder was deleted.');
    expect(
      l10n.copiesDeletedSuffix(3),
      'Their copies in the folder were deleted.',
    );
    expect(
      l10n.removedWithCopies(
        '1 clip removed from Goa. The video is still in your gallery.',
        'Its copy in the folder was deleted.',
      ),
      '1 clip removed from Goa. The video is still in your gallery. Its copy '
      'in the folder was deleted.',
    );
    expect(
      l10n.movedToCopiesSnack(
        'Goa',
        'Their copies in the folder were deleted.',
      ),
      'Moved to Goa. Their copies in the folder were deleted.',
    );
  });
}
