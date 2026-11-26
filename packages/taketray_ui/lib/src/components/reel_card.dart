import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/skeleton.dart';
import 'package:taketray_ui/src/components/status_pill.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// What a line under a [TtReelCard] says.
enum TtReelCardNoteKind {
  /// The reel is being edited in another app: a filled `folder_copy` in the
  /// primary colour.
  editing,

  /// Some of the reel's clips are gone from the phone: a filled `error` in
  /// the error colour.
  missing,

  /// The reel has references: a `link` in `onSurfaceVariant`.
  references,
}

/// One item of the optional line under a [TtReelCard], such as "2 missing".
class TtReelCardNote {
  /// A note of [kind] saying [text].
  const new(this.kind, this.text);

  /// Which note this is; it picks the icon and the colour.
  final TtReelCardNoteKind kind;

  /// What the note says, such as "Editing in VN".
  final String text;
}

/// A reel on the Home screen (D-194): the cover alone, and under it the
/// name, the status mark, the meta and, only when it applies, a line of
/// notes.
///
/// The cover is full width, 3:4, with rounded corners and nothing on it. With
/// no [cover], or one that fails to load, it shows a film icon; while the
/// picture decodes it shows the skeleton tile's shimmer in the same box, so
/// nothing moves when the picture lands. Under it: the [name] (two lines at
/// most), the [status] as a filled icon with [statusLabel] in words, the
/// [meta] (such as "14 clips · 5:30" or "No clips yet") and one wrapping line
/// for the [notes], in the order given, drawn only when there are some.
///
/// The whole card is one button named [semanticLabel] (which should say the
/// name, status, clip count and anything in the notes); nothing inside it is
/// a node of its own. While pressed the card scales to 98 %, except under
/// "remove animations".
class TtReelCard extends StatefulWidget {
  /// A card for the reel [name].
  const new({
    required this.name,
    required this.semanticLabel,
    required this.status,
    required this.statusLabel,
    required this.meta,
    this.cover,
    this.notes = const [],
    this.onTap,
    super.key,
  });

  /// The reel's name; two lines at most.
  final String name;

  /// What a screen reader says for the card.
  final String semanticLabel;

  /// The stage the reel is at; it picks the status mark.
  final TtStatusKind status;

  /// The status in words, such as "Collecting".
  final String statusLabel;

  /// The line under the status, such as "14 clips · 5:30", or "No clips yet".
  final String meta;

  /// The cover picture, or null for the film icon.
  final ImageProvider? cover;

  /// The items of the line under the meta, in order; none draws no line.
  final List<TtReelCardNote> notes;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  @override
  State<TtReelCard> createState() => _TtReelCardState();
}

class _TtReelCardState extends State<TtReelCard> {
  bool _pressed = false;

  void _press({required bool down}) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final tappable = widget.onTap != null;

    // home2.css:56: .h2-card { flex-direction: column; gap: 8px }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TtMetrics.reelCardGap,
      children: [
        _Cover(cover: widget.cover),
        Padding(
          // home2.css:60: .h2-cap { padding: 0 4px }
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: TtMetrics.reelCardCaptionInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TtMetrics.reelCardCaptionGap,
            children: [
              Text(
                widget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.text.material.titleSmall!.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              _StatusMark(kind: widget.status, label: widget.statusLabel),
              Text(
                widget.meta,
                style: tt.text
                    .numeric(tt.text.material.bodySmall!)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
              if (widget.notes.isNotEmpty) _Notes(notes: widget.notes),
            ],
          ),
        ),
      ],
    );

    final scale = _pressed && tappable && !tt.motion.isReduced
        ? TtMetrics.reelCardPressScale
        : 1.0;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: tappable,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: tappable ? (_) => _press(down: true) : null,
        onTapUp: tappable ? (_) => _press(down: false) : null,
        onTapCancel: tappable ? () => _press(down: false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: tt.motion.short3,
          curve: tt.motion.standard,
          child: content,
        ),
      ),
    );
  }
}

/// The cover: a 3:4 box with rounded corners and nothing on it.
class _Cover extends StatelessWidget {
  const new({required this.cover});

  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final picture = cover;
    // home2.css:58: .h2-card .h2-cv { width: 100%; aspect-ratio: 3 / 4;
    // border-radius: 20px }, and :32 background: surface-container-high.
    return AspectRatio(
      aspectRatio: TtMetrics.reelCardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TtMetrics.reelCardRadius),
        child: ColoredBox(
          color: context.scheme.surfaceContainerHigh,
          child: picture == null
              ? const _NoPicture()
              : Image(
                  image: picture,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  // The shimmer fills the box until the first frame, so the
                  // card does not change when the picture lands.
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null ? const TtClipTileSkeleton() : child,
                  errorBuilder: (context, error, stackTrace) =>
                      const _NoPicture(),
                ),
        ),
      ),
    );
  }
}

/// The cover of a reel with no picture, or one that failed to load.
class _NoPicture extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // home2.css:34, :59: .h2-cv.empty { center; color: on-surface-variant },
    // .h2-card .h2-cv.empty .ms { font-size: 28px }
    return Center(
      child: Icon(
        Symbols.movie_rounded,
        size: TtMetrics.reelCardEmptyIconSize,
        color: context.scheme.onSurfaceVariant,
      ),
    );
  }
}

/// The status mark: a filled icon that carries the colour, and the word.
class _StatusMark extends StatelessWidget {
  const new({required this.kind, required this.label});

  final TtStatusKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // home2.css:35-39: .h2-st { gap: 4px; label-medium; on-surface-variant },
    // .h2-st .ms { 14px }, .rec error, .ready tertiary, .pub primary
    final (glyph, colour) = switch (kind) {
      TtStatusKind.collecting => (
        Symbols.radio_button_checked_rounded,
        scheme.error,
      ),
      TtStatusKind.ready => (Symbols.content_cut_rounded, scheme.tertiary),
      TtStatusKind.published => (Symbols.check_circle_rounded, scheme.primary),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TtMetrics.reelCardStatusGap,
      children: [
        Icon(
          glyph,
          size: TtMetrics.reelCardStatusIconSize,
          color: colour,
          fill: 1,
        ),
        Flexible(
          child: Text(
            label,
            style: tt.text.material.labelMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The line of notes under the meta: a wrapping row of icon and text items.
class _Notes extends StatelessWidget {
  const new({required this.notes});

  final List<TtReelCardNote> notes;

  @override
  Widget build(BuildContext context) {
    // home2.css:41: .h2-xs { flex-wrap: wrap; gap: 4px 10px }
    return Wrap(
      spacing: TtMetrics.reelCardNotesSpacing,
      runSpacing: TtMetrics.reelCardNotesRunSpacing,
      children: [for (final note in notes) _Note(note: note)],
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.note});

  final TtReelCardNote note;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // home2.css:42-45: .h2-x { gap: 3px; label-small; on-surface-variant },
    // .h2-x .ms { 14px }, .vn primary, .er error
    final (glyph, colour, filled) = switch (note.kind) {
      TtReelCardNoteKind.editing => (
        Symbols.folder_copy_rounded,
        scheme.primary,
        true,
      ),
      TtReelCardNoteKind.missing => (Symbols.error_rounded, scheme.error, true),
      TtReelCardNoteKind.references => (
        Symbols.link_rounded,
        scheme.onSurfaceVariant,
        false,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TtMetrics.reelCardNoteGap,
      children: [
        Icon(
          glyph,
          size: TtMetrics.reelCardNoteIconSize,
          color: colour,
          fill: filled ? 1 : null,
        ),
        Flexible(
          child: Text(
            note.text,
            style: tt.text.material.labelSmall!.copyWith(color: colour),
          ),
        ),
      ],
    );
  }
}
