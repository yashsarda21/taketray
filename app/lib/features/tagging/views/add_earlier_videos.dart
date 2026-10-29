import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

/// The sheet: a title and a line of explanation, then two rows (D-78).
///
/// - **Today** has how many videos it would add trailing, and adds them as
///   soon as it is tapped.
/// - **Choose dates…** has a chevron. It opens Flutter's date range picker
///   (themed by the app theme): from ten years ago to today, no future days,
///   nothing chosen at first. After "Find videos" the sheet counts the new
///   videos in those days (a skeleton in the row meanwhile) and a dialog
///   asks "N videos found. Add them to To tag?" with Cancel and Add, or says
///   "No new videos…" with OK. Cancel and OK leave the sheet open.
///
/// While the count of Today loads, the rows are there with a skeleton and
/// cannot be tapped. Today with 0 says "none" and cannot be tapped; neither
/// row can while the dates are counted or an add is running, and a second tap
/// is ignored. If a count cannot be read, a short message and "Try again"
/// (for the dates, the same dates again).
class _AddEarlierVideosSheet extends ConsumerStatefulWidget {
  const new({required this.onOutcome});

  final void Function(_Outcome outcome) onOutcome;

  @override
  ConsumerState<_AddEarlierVideosSheet> createState() =>
      _AddEarlierVideosSheetState();
}

class _AddEarlierVideosSheetState
    extends ConsumerState<_AddEarlierVideosSheet> {
  /// An add is running.
  bool _adding = false;

  /// The picker is open, or the videos in the chosen dates are being counted.
  bool _choosing = false;

  /// The count of the chosen dates runs (the picker is closed).
  bool _finding = false;

  /// The dates whose count failed, for "Try again".
  EarlierCustom? _failedRange;

  Future<void> _add(EarlierRange range) async {
    if (_adding) return;
    setState(() => _adding = true);
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
      setState(() => _adding = false);
    } else {
      navigator.pop();
    }
  }

  /// Choose dates…: the picker, then [_find] the picked days.
  Future<void> _chooseDates() async {
    if (_choosing || _adding) return;
    setState(() => _choosing = true);
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(ref.read(clockProvider).now().toLocal());
    final picked = await showDateRangePicker(
      context: context,
      // Ten years back, and nothing in the future.
      firstDate: DateTime(today.year - 10, today.month, today.day),
      lastDate: today,
      // Today on the app's clock (it opens on this month and marks the day).
      currentDate: today,
      helpText: l10n.earlierPickerHelp,
      saveText: l10n.earlierPickerConfirm,
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _choosing = false);
      return;
    }
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
      }
      return;
    }
    if (!mounted) return;
    setState(() => _finding = false);
    final add = await _confirm(range, count);
    if (!mounted) return;
    setState(() => _choosing = false);
    if (add) await _add(range);
  }

  /// The dialog after the count: true when the user chose Add.
  Future<bool> _confirm(EarlierCustom range, int count) async {
    final l10n = AppLocalizations.of(context);
    if (count == 0) {
      final format = DateFormat.MMMd(
        Localizations.localeOf(context).toString(),
      );
      final from = format.format(range.from);
      final to = format.format(range.to);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final count = ref.watch(earlierVideosControllerProvider);
    final failed =
        _failedRange != null ||
        (count.hasError && !count.hasValue && !count.isLoading);
    final loading = !count.hasValue && !failed;
    final busy = _adding || _choosing;

    // What a screen reader says for a row that is waiting.
    String waiting(String title) => '$title, ${l10n.loading}';

    // proto.css: .li.dis { opacity: .45 }; a row that is only waiting for a
    // count is not dimmed.
    Widget disabled(TtListRow row, String label, {required bool dim}) =>
        Opacity(
          opacity: dim ? TtMetrics.listRowDisabledOpacity : 1,
          child: Semantics(
            container: true,
            button: true,
            enabled: false,
            excludeSemantics: true,
            label: label,
            child: row,
          ),
        );

    Widget skeleton() => const SizedBox(
      width: TtMetrics.skeletonCountWidth,
      child: TtSkeletonLine(widthFactor: 1),
    );

    Widget today() {
      final title = l10n.earlierRangeToday;
      final value = count.value;
      final usable = value != null && value > 0 && !busy;
      final countText = value == null ? null : l10n.earlierRowCount(value);
      final label = loading
          ? waiting(title)
          : countText == null
          ? title
          : '$title, $countText';
      final row = TtListRow(
        title: title,
        trailing: loading
            ? skeleton()
            : countText == null
            ? null
            : Text(countText),
        stackTrailingAtLargeText: true,
        onTap: usable ? () => _add(const EarlierToday()) : null,
        semanticLabel: label,
      );
      return usable ? row : disabled(row, label, dim: !loading);
    }

    Widget chooseDates() {
      final title = l10n.earlierChooseDates;
      final usable = !loading && !busy;
      final label = loading || _finding ? waiting(title) : title;
      final row = TtListRow(
        title: title,
        trailing: _finding
            ? skeleton()
            : const Icon(Symbols.chevron_right_rounded),
        onTap: usable ? _chooseDates : null,
        semanticLabel: label,
      );
      return usable ? row : disabled(row, label, dim: !(loading || _finding));
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: tt.spacing.xs,
                children: [
                  Text(
                    l10n.earlierCountFailed,
                    style: tt.text.material.bodyLarge!.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  TtButton(
                    label: l10n.tryAgain,
                    kind: TtButtonKind.tonal,
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
                ],
              ),
            )
          else ...[
            today(),
            chooseDates(),
          ],
        ],
      ),
    );
  }
}
