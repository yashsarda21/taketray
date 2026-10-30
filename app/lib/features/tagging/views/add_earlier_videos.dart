import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/rules/earlier_window.dart';
import 'package:taketray/features/tagging/view_models/earlier_videos_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Types only, never a message (D-10).
final Logger _log = Logger('earlierVideosSheet');

/// What the sheet reports to the screen that opened it.
sealed class _Outcome {
  const _Outcome();
}

/// The videos were added; [ids] are the new clips (for Undo).
class _Added extends _Outcome {
  const _Added(this.ids);

  final List<int> ids;
}

/// Adding failed.
class _AddFailed extends _Outcome {
  const _AddFailed();
}

/// Opens the "Add earlier videos" sheet (D-73, D-76, D-78) from the Shooting
/// mode card's link or To tag's menu, and reports what happened with a snack
/// on [context]'s screen:
///
/// - added: "N clips added to To tag" with **Undo**, which takes those clips
///   back out (only the ones nobody has touched since, D-75);
/// - the add failed: "Couldn't add videos. Try again.";
/// - Undo failed: "Couldn't undo. Try again.".
///
/// The snack is shown even if the sheet was dragged away while the add was
/// running. Nothing here throws: the controller's `add` and `undo` rethrow,
/// and both are caught.
Future<void> showAddEarlierVideos(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context);

  void undo(List<int> ids) => unawaited(() async {
    try {
      await container.read(earlierVideosControllerProvider.notifier).undo(ids);
    } on Object catch (error) {
      _log.warning('Undo failed: ${error.runtimeType}');
      if (context.mounted) {
        showTtSnack(context, message: l10n.earlierUndoFailed);
      }
    }
  }());

  void announce(_Outcome outcome) {
    if (!context.mounted) return;
    switch (outcome) {
      case _Added(:final ids):
        // The controller that added is the one that undoes: keep it alive
        // until the snack is gone, after the sheet (its only listener) closes.
        final keepAlive = container.listen(
          earlierVideosControllerProvider,
          (_, _) {},
        );
        final snack = showTtSnack(
          context,
          message: l10n.earlierAddedSnack(ids.length),
          icon: Symbols.check_circle_rounded,
          actionLabel: l10n.undo,
          onAction: () => undo(ids),
        );
        unawaited(snack.closed.whenComplete(keepAlive.close));
      case _AddFailed():
        showTtSnack(context, message: l10n.earlierAddFailed);
    }
  }

  return showTtSheet<void>(
    context,
    builder: (_) => _AddEarlierVideosSheet(onOutcome: announce),
  );
}

/// What the sheet is doing besides waiting for the user.
enum _Adding { none, today, dates }

/// The sheet: a title and a line of explanation, then two rows (D-78, D-79).
///
/// - **Today** (its date under it) has how many videos it would add trailing,
///   in a pill, and adds them as soon as it is tapped.
/// - **Choose dates…** ("Up to 10 years back", a chevron) opens TakeTray's
///   date range picker (`showTtDateRangePicker`): from ten years ago to
///   today, no future days. It opens on the **last dates chosen in this
///   sheet**, and on nothing the first time. After "Find videos" the sheet
///   counts the new videos in those days ("{dates} · Checking…" and a
///   spinner meanwhile) and a dialog asks "N videos found. Add them to To
///   tag?" with Cancel and Add, or says "No new videos…" with OK. Cancel and
///   OK leave the sheet open.
///
/// Every row is **off** (AA contrast, no fade, announced disabled) while the
/// count of Today loads, the dates are counted or an add runs, and a second
/// tap is ignored. Today with 0 says "none" and is off too. If a count cannot
/// be read, a warning banner under the subtitle says so with "Try again" (for
/// the dates, the same dates again), and the rows stay.
class _AddEarlierVideosSheet extends ConsumerStatefulWidget {
  const new({required this.onOutcome});

  final void Function(_Outcome outcome) onOutcome;

  @override
  ConsumerState<_AddEarlierVideosSheet> createState() =>
      _AddEarlierVideosSheetState();
}

class _AddEarlierVideosSheetState
    extends ConsumerState<_AddEarlierVideosSheet> {
  /// An add is running, and for what.
  _Adding _adding = _Adding.none;

  /// The picker is open, the dates are being counted, or the dialog asks.
  bool _choosing = false;

  /// The count of the chosen dates runs (the picker is closed).
  bool _finding = false;

  /// The dates whose count failed, for "Try again".
  EarlierCustom? _failedRange;

  /// The last dates chosen with "Find videos" in this sheet, which the picker
  /// opens on next time. Null until then.
  DateTimeRange? _lastRange;

  /// Gives the Choose dates… row its focus back when the picker closes.
  final FocusNode _chooseFocus = FocusNode(debugLabel: 'Choose dates');

  @override
  void dispose() {
    _chooseFocus.dispose();
    super.dispose();
  }

  /// Gives the Choose dates… row the focus back once it can be used again.
  ///
  /// The row is off (it has no ink well, so no focus) while the dates are
  /// counted or an add runs, and loses the focus then; a screen reader would
  /// start again from the top of the sheet. After the next frame the row is
  /// back and takes it.
  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chooseFocus.requestFocus();
    });
  }

  DateTime get _today =>
      DateUtils.dateOnly(ref.read(clockProvider).now().toLocal());

  Future<void> _add(EarlierRange range) async {
    if (_adding != _Adding.none) return;
    setState(
      () => _adding = range is EarlierToday ? _Adding.today : _Adding.dates,
    );
    // Read before waiting: the sheet may be gone when the add ends.
    final controller = ref.read(earlierVideosControllerProvider.notifier);
    final report = widget.onOutcome;
    final navigator = Navigator.of(context);
    _Outcome? outcome;
    try {
      final ids = await controller.add(range);
      outcome = ids.isEmpty ? null : _Added(ids);
    } on Object {
      // The controller logged the type.
      outcome = const _AddFailed();
    }
    if (outcome != null) report(outcome);
    if (!mounted) return;
    if (outcome == null) {
      // Nothing was left to add (the videos went away since the count): the
      // controller counted again, so the rows show the truth.
      setState(() => _adding = _Adding.none);
      _restoreFocus();
    } else {
      navigator.pop();
    }
  }

  /// Choose dates…: the picker, then [_find] the picked days.
  Future<void> _chooseDates() async {
    if (_choosing || _adding != _Adding.none) return;
    setState(() => _choosing = true);
    final l10n = AppLocalizations.of(context);
    final today = _today;
    // The row has the focus while the picker is open, so the picker gives it
    // back when it closes.
    _chooseFocus.requestFocus();
    final picked = await showTtDateRangePicker(
      context,
      // Ten years back, and nothing in the future.
      firstDate: DateTime(today.year - 10, today.month, today.day),
      lastDate: today,
      // Today on the app's clock (it opens on this month and marks the day).
      currentDate: today,
      // The last dates chosen in this sheet, or nothing the first time.
      initialDateRange: _lastRange,
      labels: _pickerLabels(l10n),
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _choosing = false);
      return;
    }
    _lastRange = picked;
    await _find(EarlierCustom(picked.start, picked.end));
  }

  /// Counts the new videos in [range] and asks whether to add them.
  ///
  /// Does nothing while a count already runs: a second tap on "Try again"
  /// before the screen redraws must not count twice and stack two dialogs.
  Future<void> _find(EarlierCustom range) async {
    if (_finding) return;
    final controller = ref.read(earlierVideosControllerProvider.notifier);
    setState(() {
      _choosing = true;
      _finding = true;
      _failedRange = null;
      _lastRange = DateTimeRange(start: range.from, end: range.to);
    });
    final int count;
    try {
      count = await controller.countIn(range);
    } on Object {
      // The controller logged the type.
      if (mounted) {
        setState(() {
          _choosing = false;
          _finding = false;
          _failedRange = range;
        });
        _restoreFocus();
      }
      return;
    }
    if (!mounted) return;
    setState(() => _finding = false);
    final add = await _confirm(range, count);
    if (!mounted) return;
    setState(() => _choosing = false);
    // Cancel, OK or a tap outside: the row has the focus again.
    if (!add) _restoreFocus();
    if (add) await _add(range);
  }

  /// The dialog after the count: true when the user chose Add.
  Future<bool> _confirm(EarlierCustom range, int count) async {
    final l10n = AppLocalizations.of(context);
    if (count == 0) {
      final today = _today;
      final from = ttDayText(context, range.from, today: today);
      final to = ttDayText(context, range.to, today: today);
      final oneDay = DateUtils.isSameDay(range.from, range.to);
      await showTtDialog<void>(
        context,
        title: l10n.earlierNoneTitle,
        body: oneDay
            ? l10n.earlierNoneOn(from)
            : l10n.earlierNoneBetween(from, to),
        actions: [TtDialogAction(null, l10n.earlierDialogOk)],
      );
      return false;
    }
    final add = await showTtDialog<bool>(
      context,
      title: l10n.earlierFoundTitle(count),
      body: l10n.earlierFoundBody(count),
      actions: [
        TtDialogAction(false, l10n.earlierDialogCancel),
        TtDialogAction(true, l10n.earlierDialogAdd),
      ],
    );
    return add ?? false;
  }

  /// "8 Oct – 10 Oct", or "8 Oct" for one day (the dates of the phone's
  /// language, with the year only when it is not this year).
  String _rangeText(DateTimeRange range) {
    final today = _today;
    final from = ttDayText(context, range.start, today: today);
    if (DateUtils.isSameDay(range.start, range.end)) return from;
    return '$from – ${ttDayText(context, range.end, today: today)}';
  }

  TtDateRangePickerLabels _pickerLabels(AppLocalizations l10n) =>
      TtDateRangePickerLabels(
        title: l10n.earlierPickerTitle,
        close: l10n.pickerClose,
        clear: l10n.pickerClear,
        findVideos: l10n.earlierPickerConfirm,
        yesterday: l10n.pickerQuickYesterday,
        lastWeek: l10n.pickerQuickLastWeek,
        thisMonth: l10n.pickerQuickThisMonth,
        lastMonth: l10n.pickerQuickLastMonth,
        nothingTitle: l10n.pickerSummaryNothingTitle,
        nothingSubtitle: l10n.pickerSummaryNothingSubtitle,
        firstTitle: l10n.pickerSummaryFirstTitle,
        firstSubtitle: l10n.pickerSummaryFirstSubtitle,
        rangeTitle: l10n.pickerSummaryRangeTitle,
        rangeSubtitle: l10n.pickerSummaryRangeSubtitle,
        oneDaySubtitle: l10n.pickerSummaryOneDay,
        calendar: TtDateRangeCalendarLabels(
          previousMonth: l10n.calendarPreviousMonth,
          nextMonth: l10n.calendarNextMonth,
          backToDays: l10n.calendarBackToDays,
          chooseMonthAndYear: l10n.calendarChooseMonthYear,
          yearHeading: l10n.calendarYear,
          monthHeading: l10n.calendarMonth,
          firstDay: l10n.calendarFirstDay,
          lastDay: l10n.calendarLastDay,
          onlyDay: l10n.calendarOnlyDay,
          inRange: l10n.calendarInRange,
          today: l10n.calendarToday,
          notAvailable: l10n.calendarNotAvailable,
          hasChosenDays: l10n.calendarHasChosenDays,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final count = ref.watch(earlierVideosControllerProvider);
    final countFailed = count.hasError && !count.hasValue && !count.isLoading;
    final failed = _failedRange != null || countFailed;
    final loading = !count.hasValue && !countFailed;
    // Every row is off while it loads, counts the dates or adds.
    final busy = loading || _finding || _adding != _Adding.none;
    final countingDates = _finding || _adding == _Adding.dates;
    final range = _lastRange;
    final value = count.value;

    Widget today() {
      final adding = _adding == _Adding.today;
      final usable = value != null && value > 0 && !busy;
      final Widget? trailing;
      if (loading) {
        trailing = const TtSkeletonCount();
      } else if (adding) {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          spacing: tt.spacing.xs,
          children: [
            TtRowCount(l10n.earlierAddingToday, pill: false),
            TtRowSpinner(semanticLabel: l10n.earlierAddingTodaySpinner),
          ],
        );
      } else if (value == null) {
        // The count could not be read: no number to show.
        trailing = null;
      } else if (value == 0) {
        trailing = TtRowCount(l10n.earlierRowCount(0), pill: false);
      } else {
        trailing = TtRowCount(l10n.earlierRowCount(value));
      }
      final label = loading
          ? l10n.earlierTodayLabelLoading
          : value == null
          ? l10n.earlierTodayLabelNotChecked
          : value == 0
          ? l10n.earlierTodayLabelNone
          : l10n.earlierTodayLabelNew(value);
      return TtListRow(
        title: l10n.earlierRangeToday,
        subtitle: MaterialLocalizations.of(context).formatMediumDate(_today),
        leading: const TtRowIcon(icon: Symbols.today_rounded, boxed: false),
        trailing: trailing,
        tall: true,
        stackTrailingAtLargeText: true,
        off: !usable,
        onTap: usable ? () => _add(const EarlierToday()) : null,
        semanticLabel: label,
      );
    }

    Widget chooseDates() {
      final adding = _adding == _Adding.dates;
      final String subtitle;
      final Widget trailing;
      if (countingDates && range != null) {
        final text = _rangeText(range);
        subtitle = adding
            ? l10n.earlierAddingRange(text)
            : l10n.earlierChecking(text);
        trailing = TtRowSpinner(
          semanticLabel: adding
              ? l10n.earlierAddingSpinner
              : l10n.earlierCheckingSpinner(text),
        );
      } else {
        subtitle = l10n.earlierChooseSubtitle;
        trailing = const Icon(Symbols.chevron_right_rounded);
      }
      return TtListRow(
        title: l10n.earlierChooseDates,
        subtitle: subtitle,
        leading: const TtRowIcon(
          icon: Symbols.edit_calendar_rounded,
          boxed: false,
        ),
        trailing: trailing,
        tall: true,
        focusNode: _chooseFocus,
        off: busy,
        onTap: busy ? null : _chooseDates,
        semanticLabel: countingDates && range != null
            ? l10n.earlierChooseLabelBusy(subtitle)
            : l10n.earlierChooseLabel,
      );
    }

    return TtSheet(
      child: ListView(
        shrinkWrap: true,
        // proto.css: .sheet .sh-body { padding-bottom: 12px }
        padding: EdgeInsets.only(bottom: tt.spacing.s),
        children: [
          // proto.css: .sheet .sh-head { padding: 4px 24px 12px }, with the
          // line under the title 4 dp below it (TtSheet's own title has no
          // second line).
          Padding(
            padding: EdgeInsets.fromLTRB(
              tt.spacing.xl,
              tt.spacing.xxs,
              tt.spacing.xl,
              tt.spacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tt.spacing.xxs,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.addEarlierVideos,
                    style: tt.text.material.titleLarge!.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.earlierSheetSubtitle,
                  style: tt.text.material.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (failed)
            TtBanner(
              kind: TtBannerKind.warning,
              icon: Symbols.error_rounded,
              title: l10n.earlierCountFailed,
              action: TtButton(
                label: l10n.tryAgain,
                kind: TtButtonKind.text,
                onPressed: () {
                  // A second tap before the redraw: the count runs.
                  if (_finding) return;
                  final range = _failedRange;
                  if (range != null) {
                    unawaited(_find(range));
                  } else {
                    ref.invalidate(earlierVideosControllerProvider);
                  }
                },
              ),
            ),
          today(),
          chooseDates(),
        ],
      ),
    );
  }
}
