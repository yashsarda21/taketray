import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('Phase 8 VN copies storage screen copy, verbatim (D-130)', (
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

    // Settings.
    expect(l10n.settingsGroupClips, 'Clips');
    expect(l10n.settingsCopiesTitle, 'Storage used by VN copies');
    expect(l10n.settingsCopiesSummary('1.8 GB', 3), '1.8 GB in 3 reels');
    expect(l10n.settingsCopiesSummary('600 MB', 1), '600 MB in 1 reel');
    expect(l10n.settingsCopiesNone, 'None');

    // The screen.
    expect(l10n.copiesStorageTitle, 'VN copies');
    expect(l10n.copiesStorageUsed(3), 'used by VN copies in 3 reels');
    expect(l10n.copiesStorageUsed(1), 'used by VN copies in 1 reel');
    expect(
      l10n.copiesStorageRow(2, '600 MB', 'Oct 5'),
      '2 copies · 600 MB · since Oct 5',
    );
    expect(
      l10n.copiesStorageRow(1, '300 MB', 'Oct 5'),
      '1 copy · 300 MB · since Oct 5',
    );
    expect(
      l10n.copiesStorageRowEditor(3, 'CapCut', '900 MB', 'Oct 5'),
      '3 copies for CapCut · 900 MB · since Oct 5',
    );
    expect(
      l10n.copiesStorageRowEditor(1, 'Instagram Edits', '300 MB', 'Oct 5'),
      '1 copy for Instagram Edits · 300 MB · since Oct 5',
    );
    expect(l10n.copiesStorageDelete, 'Delete');
    expect(
      l10n.copiesStorageDeleteSemantics('Goa'),
      'Delete the copies of Goa',
    );
    expect(
      l10n.copiesStorageNote,
      'Copies are only for VN. Deleting them never touches your original '
      'clips.',
    );
    expect(l10n.copiesStorageEmptyTitle, 'No VN copies');
    expect(
      l10n.copiesStorageEmptyBody,
      'When you edit a reel in VN, its temporary copies show up here.',
    );
    expect(l10n.copiesStorageLoadFailed, "Couldn't read the VN copies");

    // Files no reel records.
    expect(l10n.copiesStorageOrphansLabel, 'Not linked to a reel');
    expect(
      l10n.copiesStorageOrphansNote,
      'Left from an earlier install or a backup import. Android asks before '
      'deleting them.',
    );
    expect(l10n.copiesStorageOrphanRow(2, '240 MB'), '2 files · 240 MB');
    expect(l10n.copiesStorageOrphanRow(1, '250 MB'), '1 file · 250 MB');
    expect(
      l10n.copiesStorageOrphanDeleteSemantics('Old trip'),
      'Delete the files in Old trip',
    );
    expect(
      l10n.copiesStorageNeedsAccess,
      'With full video access, TakeTray can also find copies left from an '
      'earlier install.',
    );

    // The snack is Done editing's own.
    expect(
      l10n.doneEditingFreedSnack('240 MB'),
      'Copies deleted · 240 MB freed',
    );
  });
}
