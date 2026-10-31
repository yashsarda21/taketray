import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('English strings resolve, including the plural badge', (
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

    expect(l10n.appTitle, 'TakeTray');
    expect(l10n.navReels, 'Reels');
    expect(l10n.navToTag, 'To tag');
    expect(l10n.navSettings, 'Settings');
    expect(l10n.toTagBadgeSemantics(0), 'No clips to tag');
    expect(l10n.toTagBadgeSemantics(1), '1 clip to tag');
    expect(l10n.toTagBadgeSemantics(23), '23 clips to tag');
  });

  testWidgets('the Phase 3 screens have the approved English copy', (
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

    // The banners.
    expect(l10n.accessManualTitle, 'Manual mode');
    expect(l10n.accessManualBody, "New clips aren't found automatically.");
    expect(l10n.accessManualAction, 'Allow full access');
    expect(l10n.accessLostTitle, "TakeTray can't see your videos");
    expect(l10n.accessLostBody, 'Allow access to find new clips.');
    expect(l10n.accessLostAction, 'Allow');
    // The Shooting mode card.
    expect(l10n.shootingOffTitle, 'Shooting mode');
    expect(
      l10n.shootingOffSubtitle,
      'Off. Turn on before you start filming, and new videos wait in To tag.',
    );
    expect(l10n.shootingOnTitle, 'Shooting mode on');
    expect(l10n.shootingOnSubtitle('9:41 AM'), 'On since 9:41 AM');
    expect(
      l10n.shootingOnSubtitleManual('9:41 AM'),
      'On since 9:41 AM · Manual mode: add clips yourself',
    );
    expect(l10n.shootingSwitchLabel, 'Shooting mode');
    expect(l10n.shootingOpenCamera, 'Open camera');
    expect(l10n.shootingStripTitle(1), '1 clip to tag');
    expect(l10n.shootingStripTitle(2), '2 clips to tag');
    expect(l10n.shootingStripTitle(120), '120 clips to tag');
    expect(l10n.shootingStripAction, 'Tag now');
    // To tag.
    expect(l10n.toTagStripOn('9:41 AM'), 'Shooting since 9:41 AM');
    expect(l10n.toTagStripOff, 'Shooting mode off');
    expect(l10n.toTagStripTurnOn, 'Turn on');
    expect(l10n.toTagEmptyOnTitle, 'All caught up');
    expect(l10n.toTagEmptyOnBody, 'New clips you shoot will show up here.');
    expect(l10n.toTagEmptyOffTitle, 'Nothing to tag');
    expect(
      l10n.toTagEmptyOffBody,
      'Turn on Shooting mode before you start filming. New videos will show '
      'up here.',
    );
    expect(l10n.toTagEmptyOffAction, 'Turn on Shooting mode');
    expect(l10n.clipTileSemantics('9:41 AM', '0:32'), 'Clip, 9:41 AM, 0:32');
    expect(l10n.clipMissing, 'Missing from phone');
    // Add earlier videos.
    expect(l10n.addEarlierVideos, 'Add earlier videos');
    expect(
      l10n.earlierSheetSubtitle,
      'From your camera folders. Clips you already tagged or skipped stay '
      'where they are.',
    );
    expect(l10n.earlierRangeToday, 'Today');
    expect(l10n.earlierChooseDates, 'Choose dates…');
    expect(l10n.earlierPickerTitle, 'Choose dates');
    expect(l10n.earlierPickerConfirm, 'Find videos');
    expect(l10n.earlierFoundTitle(1), '1 video found');
    expect(l10n.earlierFoundTitle(2), '2 videos found');
    expect(l10n.earlierFoundTitle(40), '40 videos found');
    expect(l10n.earlierFoundBody(1), 'Add it to To tag?');
    expect(l10n.earlierFoundBody(2), 'Add them to To tag?');
    expect(l10n.earlierNoneTitle, 'No new videos');
    expect(
      l10n.earlierNoneBetween('Oct 20', 'Oct 24'),
      'No new videos between Oct 20 and Oct 24.',
    );
    expect(l10n.earlierNoneOn('Oct 20'), 'No new videos on Oct 20.');
    expect(l10n.earlierDialogCancel, 'Cancel');
    expect(l10n.earlierDialogAdd, 'Add');
    expect(l10n.earlierDialogOk, 'OK');
    expect(l10n.earlierRowCount(0), 'none');
    expect(l10n.earlierRowCount(1), '1 new');
    expect(l10n.earlierRowCount(5), '5 new');
    expect(l10n.earlierAddedSnack(1), '1 clip added to To tag');
    expect(l10n.earlierAddedSnack(2), '2 clips added to To tag');
    expect(l10n.undo, 'Undo');
    expect(l10n.earlierAddFailed, "Couldn't add videos. Try again.");
    expect(l10n.undoFailed, "Couldn't undo. Try again.");
    expect(l10n.earlierCountFailed, "Couldn't check your videos.");
    expect(l10n.tryAgain, 'Try again');
    expect(l10n.moreOptions, 'More options');
  });

  test('every key of the English file has a value and a description', () {
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toList();

    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        (arb[key] as String).trim(),
        isNotEmpty,
        reason: '$key has no English text',
      );
      final meta = arb['@$key'] as Map<String, dynamic>?;
      expect(meta, isNotNull, reason: '$key has no @$key entry');
      expect(
        (meta!['description'] as String? ?? '').trim(),
        isNotEmpty,
        reason: '$key has no description for translators',
      );
    }
  });

  testWidgets('the redesigned Add earlier videos strings (D-79)', (
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

    expect(l10n.earlierCardRowSubtitle, 'Shot before Shooting mode was on');
    expect(
      l10n.earlierCardRowLabel,
      'Add earlier videos, shot before Shooting mode was on',
    );
    expect(l10n.earlierCardRowSubtitleOff, 'From your camera folder');
    expect(
      l10n.earlierCardRowLabelOff,
      'Add earlier videos, from your camera folder',
    );
    expect(l10n.earlierChooseSubtitle, 'Up to 10 years back');
    expect(
      l10n.earlierChecking('8 Oct – 10 Oct'),
      '8 Oct – 10 Oct · Checking…',
    );
    expect(
      l10n.earlierAddingRange('8 Oct – 10 Oct'),
      '8 Oct – 10 Oct · Adding…',
    );
    expect(l10n.earlierAddingToday, 'Adding…');
    expect(
      l10n.earlierTodayLabelNew(1),
      'Today, 1 new video. Adds them to To tag',
    );
    expect(
      l10n.earlierTodayLabelNew(3),
      'Today, 3 new videos. Adds them to To tag',
    );
    expect(l10n.earlierTodayLabelNone, 'Today, no new videos');
    expect(l10n.earlierTodayLabelLoading, 'Today, checking for new videos');
    expect(l10n.earlierTodayLabelNotChecked, 'Today, not checked');
    expect(l10n.earlierChooseLabel, 'Choose dates, up to 10 years back');
    expect(
      l10n.earlierChooseLabelBusy('8 Oct – 10 Oct · Checking…'),
      'Choose dates. 8 Oct – 10 Oct · Checking…',
    );
    expect(
      l10n.earlierCheckingSpinner('8 Oct – 10 Oct'),
      'Checking your videos from 8 Oct – 10 Oct',
    );
    expect(l10n.earlierPickerTitle, 'Choose dates');
    expect(l10n.pickerClear, 'Clear');
    expect(l10n.pickerSummaryNothingTitle, 'Tap the first day');
    expect(l10n.pickerSummaryNothingSubtitle, 'Then tap the last day.');
    expect(l10n.pickerSummaryFirstTitle('8 Oct'), '8 Oct – …');
    expect(
      l10n.pickerSummaryFirstSubtitle('8 Oct'),
      'Tap the last day, or Find videos for 8 Oct only.',
    );
    expect(l10n.pickerSummaryRangeTitle('8 Oct', '10 Oct'), '8 Oct – 10 Oct');
    expect(l10n.pickerSummaryRangeSubtitle(3), '3 days');
    expect(l10n.pickerSummaryOneDay, '1 day');
    expect(
      [
        l10n.pickerQuickYesterday,
        l10n.pickerQuickLastWeek,
        l10n.pickerQuickThisMonth,
        l10n.pickerQuickLastMonth,
      ],
      ['Yesterday', 'Last week', 'This month', 'Last month'],
    );
    expect(l10n.calendarYear, 'Year');
    expect(l10n.calendarMonth, 'Month');
    expect(
      l10n.calendarChooseMonthYear('October 2026'),
      'Choose month and year. Now October 2026',
    );
    expect(l10n.calendarBackToDays, 'Back to the days');
  });
}
