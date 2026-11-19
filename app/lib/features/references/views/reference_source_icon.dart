import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/references/view_models/source_icons.dart';
import 'package:taketray_ui/taketray_ui.dart';

// proto.css: .srcic { border-radius: 28%; box-shadow: 0 0 0 2px
// var(--md-surface-container-low) }, refs.js: icon('link', size < 30 ? 's16')

/// The corner radius of the icon, as a share of its size.
const double _radiusShare = 0.28;

/// The ring in the card's colour around the icon.
const double _ringWidth = 2;

/// Below this size the link symbol is the small one.
const double _smallBelow = 30;
const double _smallGlyph = 16;
const double _glyph = 24;

/// The icon of a reference's source, [size] dp square (18 on a card, 40 in
/// the Edit label sheet): the source app's own icon as the phone supplied it
/// (D-155), or, when the phone has none (the app is not installed, a plain
/// link, the phone has not answered yet or failed), the generic link symbol
/// in a quiet tile. TakeTray never draws a source's logo.
///
/// Decoration only: a screen reader hears the kind in words elsewhere.
Widget referenceSourceIcon(
  BuildContext context,
  ReferenceSource source, {
  double size = 40,
}) => Consumer(
  builder: (context, ref, _) {
    final png = ref.watch(
      sourceIconsProvider.select((icons) => icons.value?[source]),
    );
    return _SourceIcon(png: png, size: size);
  },
);

class _SourceIcon extends StatelessWidget {
  const new({required this.png, required this.size});

  final Uint8List? png;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final radius = BorderRadius.circular(size * _radiusShare);
    final link = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Symbols.link_rounded,
          size: size < _smallBelow ? _smallGlyph : _glyph,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final bytes = png;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.surfaceContainerLow,
              width: _ringWidth,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: bytes == null
                ? link
                : Image.memory(
                    bytes,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // A PNG that will not decode shows the symbol, not an
                    // error.
                    errorBuilder: (context, _, _) => link,
                  ),
          ),
        ),
      ),
    );
  }
}
