import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A short list of [steps], each with a small picture on the left and, on
/// the right, its number, title and one line of explanation. The prototype's
/// "Ready for VN" screen uses it to show what to tap in the editor.
///
/// Steps are 12 dp apart. A picture is 112 x 132 dp and is drawn, not
/// photographed, so it keeps its size at large text; the text beside it wraps
/// and the step grows. A screen reader hears each step's number, title and
/// body as one node. The pictures are decoration and are hidden from it,
/// except the folder list of [TtIllustratedStep.folders], which announces the
/// highlighted folder as selected.
///
/// Every text is a parameter, so any editor's steps can use these pictures.
class TtIllustratedSteps extends StatelessWidget {
  /// The [steps], top to bottom.
  const new({required this.steps, super.key});

  /// The steps, in order.
  final List<TtIllustratedStep> steps;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    // proto.css: .vsteps { gap: 12px }
    spacing: context.tt.spacing.s,
    children: [for (final step in steps) _Step(step)],
  );
}

/// One step of [TtIllustratedSteps]: its picture and its words.
class TtIllustratedStep {
  /// A step whose picture is a phone screen with two grey bars and a big
  /// "+" button: "open the editor and tap New project".
  const new newProject({
    required this.number,
    required this.title,
    required this.body,
  }) : _kind = _StepKind.newProject,
       folders = const [],
       highlighted = 0,
       thumbnails = const [];

  /// A step whose picture is a list of [folders] with the one at
  /// [highlighted] marked.
  ///
  /// There must be one to four folders and [highlighted] must be one of them.
  const new folders({
    required this.number,
    required this.title,
    required this.body,
    required this.folders,
    required this.highlighted,
  }) : assert(folders.length > 0, 'a folder list needs a folder'),
       assert(
         folders.length <= TtMetrics.stepFoldersMax,
         'the picture holds four folders at most',
       ),
       assert(
         highlighted >= 0 && highlighted < folders.length,
         'highlighted must be the index of a folder',
       ),
       _kind = _StepKind.folders,
       thumbnails = const [];

  /// A step whose picture is a grid of [thumbnails], numbered 1 to n in the
  /// order given.
  ///
  /// The picture holds six: of more, the first six are shown. With none
  /// (every clip gone) the picture is left plain, with no tiles.
  const new tiles({
    required this.number,
    required this.title,
    required this.body,
    required this.thumbnails,
  }) : _kind = _StepKind.tiles,
       folders = const [],
       highlighted = 0;

  /// The small label above the title, such as "Step 1".
  final String number;

  /// What to do, such as "Open VN, tap New project".
  final String title;

  /// One line that helps, such as "It's the big + button."
  final String body;

  /// The folder names of a [TtIllustratedStep.folders] step.
  final List<String> folders;

  /// Which of [folders] is marked.
  final int highlighted;

  /// The pictures of a [TtIllustratedStep.tiles] step (the first six are
  /// shown).
  final List<ImageProvider> thumbnails;

  final _StepKind _kind;
}

enum _StepKind { newProject, folders, tiles }

class _Step extends StatelessWidget {
  const new(this.step);

  final TtIllustratedStep step;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    // proto.css: .vstep { display: grid; grid-template-columns: 112px 1fr;
    // gap: 14px; align-items: center }
    return Row(
      spacing: TtMetrics.stepMockGap,
      children: [
        _Mock(step),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // proto.css: .vstep .n { label-medium; primary }
                Text(
                  step.number,
                  style: text.labelMedium!.copyWith(color: scheme.primary),
                ),
                // proto.css: .vstep > div > b { title-small; margin: 2px 0 }
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TtMetrics.stepTitleMargin,
                  ),
                  child: Text(
                    step.title,
                    style: text.titleSmall!.copyWith(color: scheme.onSurface),
                  ),
                ),
                // proto.css: .vstep > div > span:not(.n) { body-medium;
                // on-surface-variant }
                Text(
                  step.body,
                  style: text.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The 112 x 132 picture of a step.
class _Mock extends StatelessWidget {
  const new(this.step);

  final TtIllustratedStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tt = context.tt;
    final picture = switch (step._kind) {
      _StepKind.newProject => const _NewProjectPicture(),
      _StepKind.folders => _FoldersPicture(
        folders: step.folders,
        highlighted: step.highlighted,
      ),
      _StepKind.tiles => _TilesPicture(
        thumbnails: step.thumbnails.take(TtMetrics.stepTilesMax).toList(),
      ),
    };
    // proto.css: .vstep .mock { height: 132px; border-radius: 14px;
    // background: surface-container-highest; padding: 8px; overflow: hidden;
    // display: flex; flex-direction: column; gap: 5px }
    return SizedBox(
      width: TtMetrics.stepMockWidth,
      height: TtMetrics.stepMockHeight,
      child: DecoratedBox(
        key: ValueKey('tt-step-mock-${step.title}'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(TtMetrics.stepMockRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TtMetrics.stepMockRadius),
          child: Padding(
            padding: EdgeInsets.all(tt.spacing.xs),
            // A drawing: its small text does not follow the text size.
            child: MediaQuery.withNoTextScaling(child: picture),
          ),
        ),
      ),
    );
  }
}

class _NewProjectPicture extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tt = context.tt;
    Widget bar(int index, double fraction) => FractionallySizedBox(
      widthFactor: fraction,
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        height: TtMetrics.stepBarHeight,
        child: DecoratedBox(
          key: ValueKey('tt-step-bar-$index'),
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(tt.radii.xs),
          ),
        ),
      ),
    );
    // aria-hidden in the prototype: decoration only.
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TtMetrics.stepMockInnerGap,
        children: [
          bar(0, TtMetrics.stepBarFirstFraction),
          bar(1, TtMetrics.stepBarSecondFraction),
          // `margin: auto`: centred in what is left.
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: TtMetrics.stepPlusSize,
                child: DecoratedBox(
                  key: const ValueKey('tt-step-plus'),
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.circular(tt.radii.l),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.tertiaryContainer,
                        spreadRadius: TtMetrics.stepPlusRing,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Symbols.add_rounded,
                      size: tt.sizes.iconLarge,
                      color: scheme.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoldersPicture extends StatelessWidget {
  const new({required this.folders, required this.highlighted});

  final List<String> folders;
  final int highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.tt.text.material;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TtMetrics.stepMockInnerGap,
      children: [
        for (var i = 0; i < folders.length; i++)
          () {
            final on = i == highlighted;
            final color = on
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant;
            // The highlighted folder is announced as selected.
            return Semantics(
              container: true,
              excludeSemantics: true,
              label: folders[i],
              selected: on ? true : null,
              child: SizedBox(
                height: TtMetrics.stepFolderHeight,
                // proto.css: .vstep .mock .fl, .fl.hl
                child: DecoratedBox(
                  key: ValueKey('tt-step-folder-$i'),
                  decoration: BoxDecoration(
                    color: on ? scheme.tertiaryContainer : null,
                    borderRadius: BorderRadius.circular(
                      TtMetrics.stepFolderRadius,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TtMetrics.stepFolderPadding,
                    ),
                    child: Row(
                      spacing: TtMetrics.stepFolderPadding,
                      children: [
                        Icon(
                          Symbols.folder_rounded,
                          size: TtMetrics.stepFolderIconSize,
                          color: color,
                          fill: on ? 1 : 0,
                        ),
                        Expanded(
                          child: Text(
                            folders[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall!.copyWith(
                              color: color,
                              fontSize: TtMetrics.stepFolderFontSize,
                              fontWeight: TtMetrics.stepFolderWeight,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}

class _TilesPicture extends StatelessWidget {
  const new({required this.thumbnails});

  final List<ImageProvider> thumbnails;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.tt.text.material;
    // aria-hidden in the prototype: decoration only.
    return ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = TtMetrics.stepTileGap;
            const columns = TtMetrics.stepTileColumns;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < thumbnails.length; i++)
                  SizedBox(
                    key: ValueKey('tt-step-tile-$i'),
                    width: width,
                    height: width / TtMetrics.stepTileAspect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        TtMetrics.stepTileRadius,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: scheme.outlineVariant),
                          Image(
                            image: thumbnails[i],
                            fit: BoxFit.cover,
                            // A picture that cannot load leaves the quiet
                            // colour behind it.
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          Positioned(
                            left: TtMetrics.stepBadgeInset,
                            top: TtMetrics.stepBadgeInset,
                            child: SizedBox.square(
                              dimension: TtMetrics.stepBadgeSize,
                              child: DecoratedBox(
                                key: ValueKey('tt-step-badge-$i'),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    maxLines: 1,
                                    style: text.labelSmall!.copyWith(
                                      color: scheme.onPrimary,
                                      fontSize: TtMetrics.stepBadgeFontSize,
                                      fontWeight: TtMetrics.stepBadgeWeight,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
