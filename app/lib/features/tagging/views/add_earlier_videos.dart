import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
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

/// Opens the "Add earlier videos" sheet (D-73, D-76) from the Shooting mode
/// card's link or To tag's menu, and reports what happened with a snack on
/// [context]'s screen:
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

/// The sheet: a title and a line of explanation, then one row per range with
/// how many videos it would add.
///
/// - While the counts load, the rows are there with a skeleton for the count,
///   and cannot be tapped.
/// - A row with 0 says "none" and cannot be tapped; so do all the rows while
///   an add is running, and a second tap on a row is ignored.
/// - If the counts cannot be read, a short message and "Try again".
class _AddEarlierVideosSheet extends ConsumerStatefulWidget {
  const new({required this.onOutcome});

  final void Function(_Outcome outcome) onOutcome;

  @override
  ConsumerState<_AddEarlierVideosSheet> createState() =>
      _AddEarlierVideosSheetState();
}

class _AddEarlierVideosSheetState
    extends ConsumerState<_AddEarlierVideosSheet> {
  bool _adding = false;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final counts = ref.watch(earlierVideosControllerProvider);
    final failed = counts.hasError && !counts.hasValue && !counts.isLoading;
    final loading = !counts.hasValue && !failed;

    Widget range(String title, EarlierRange which) {
      final count = counts.value?[which];
      final usable = count != null && count > 0 && !_adding;
      final countText = count == null ? null : l10n.earlierRowCount(count);
      // What a screen reader says: the count, or that it is loading.
      final label = loading
          ? '$title, ${l10n.loading}'
          : countText == null
          ? title
          : '$title, $countText';
      final row = TtListRow(
        title: title,
        trailing: loading
            ? const SizedBox(
                width: TtMetrics.skeletonCountWidth,
                child: TtSkeletonLine(widthFactor: 1),
              )
            : countText == null
            ? null
            : Text(countText),
        stackTrailingAtLargeText: true,
        onTap: usable ? () => _add(which) : null,
        semanticLabel: label,
      );
      if (usable) return row;
      // proto.css: .li.dis { opacity: .45 }; a row that is only waiting for
      // its count is not dimmed.
      return Opacity(
        opacity: loading ? 1 : TtMetrics.listRowDisabledOpacity,
        child: Semantics(
          container: true,
          button: true,
          enabled: false,
          excludeSemantics: true,
          label: label,
          child: row,
        ),
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
                    onPressed: () =>
                        ref.invalidate(earlierVideosControllerProvider),
                  ),
                ],
              ),
            )
          else ...[
            range(l10n.earlierRangeToday, EarlierRange.today),
            range(l10n.earlierRangeLastTwoDays, EarlierRange.lastTwoDays),
            range(l10n.earlierRangeLastSevenDays, EarlierRange.lastSevenDays),
          ],
        ],
      ),
    );
  }
}
