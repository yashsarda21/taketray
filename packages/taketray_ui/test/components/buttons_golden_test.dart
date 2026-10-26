import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Button kinds',
    fileName: 'buttons_kinds',
    scenarios: [
      for (final kind in TtButtonKind.values)
        TtScenario(kind.name, _KindRow(kind)),
    ],
  );

  ttGoldenTest(
    'Button sizes and long label',
    fileName: 'buttons_sizes',
    scenarios: [
      for (final size in TtButtonSize.values)
        TtScenario(
          size.name,
          _OnSurface(
            children: [
              TtButton(label: 'Publish', size: size, onPressed: _noop),
              TtButton(
                label: 'Tag',
                icon: Symbols.sell_rounded,
                kind: TtButtonKind.tonal,
                size: size,
                onPressed: _noop,
              ),
              TtButton(
                label: 'Skip',
                kind: TtButtonKind.text,
                size: size,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      const TtScenario(
        'long label',
        _OnSurface(
          children: [
            TtButton(
              label: 'Publish this reel to every one of my channels',
              icon: Symbols.publish_rounded,
              onPressed: _noop,
            ),
            TtButton(
              label: 'Publish this reel to every one of my channels',
              kind: TtButtonKind.outlined,
              size: TtButtonSize.small,
              onPressed: _noop,
            ),
          ],
        ),
      ),
      const TtScenario(
        'expand',
        _OnSurface(
          children: [
            TtButton(
              label: 'Continue',
              size: TtButtonSize.large,
              expand: true,
              onPressed: _noop,
            ),
            TtButton(
              label: 'Not now',
              kind: TtButtonKind.tonal,
              expand: true,
              onPressed: _noop,
            ),
          ],
        ),
      ),
    ],
  );

  ttGoldenTest(
    'Icon buttons',
    fileName: 'icon_buttons',
    scenarios: [
      for (final style in TtIconButtonStyle.values)
        TtScenario(style.name, _IconButtonRow(style)),
    ],
  );

  ttGoldenTest(
    'Floating action button',
    fileName: 'fab',
    scenarios: const [
      TtScenario(
        'fab',
        _OnSurface(
          children: [
            TtFab(
              label: 'Shoot',
              icon: Symbols.videocam_rounded,
              onPressed: _noop,
            ),
          ],
        ),
      ),
      TtScenario(
        'long label',
        _OnSurface(
          children: [
            TtFab(
              label: 'Start shooting the next reel',
              icon: Symbols.videocam_rounded,
              onPressed: _noop,
            ),
          ],
        ),
      ),
    ],
  );
}

void _noop() {}

/// A sample photo under a video-style scrim, as ghost and on-video controls
/// are always seen.
DecorationImage _darkPhoto(int n) => DecorationImage(
  image: fixtureThumb(n),
  fit: BoxFit.cover,
  colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOver),
);

/// [children] in a wrapping row on the page surface.
class _OnSurface extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tt.spacing.s),
    child: Wrap(
      spacing: context.tt.spacing.xs,
      runSpacing: context.tt.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );
}

/// One kind: enabled and disabled, with and without an icon. Ghost sits on a
/// dark photo, as it does in the app.
class _KindRow extends StatelessWidget {
  const new(this.kind);

  final TtButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final row = _OnSurface(
      children: [
        TtButton(label: 'Label', kind: kind, onPressed: _noop),
        TtButton(
          label: 'Label',
          kind: kind,
          icon: Symbols.sell_rounded,
          onPressed: _noop,
        ),
        TtButton(label: 'Label', kind: kind, onPressed: null),
        TtButton(
          label: 'Label',
          kind: kind,
          icon: Symbols.sell_rounded,
          onPressed: null,
        ),
      ],
    );
    if (kind != TtButtonKind.ghost) return row;
    return DecoratedBox(
      decoration: BoxDecoration(image: _darkPhoto(1)),
      child: row,
    );
  }
}

/// Unfilled and filled glyphs, unpressed and pressed, then disabled.
class _IconButtonRow extends StatelessWidget {
  const new(this.style);

  final TtIconButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.all(context.tt.spacing.xs),
      child: Wrap(
        children: [
          TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            onPressed: _noop,
          ),
          TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            filled: true,
            onPressed: _noop,
          ),
          TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            pressed: false,
            onPressed: _noop,
          ),
          TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            filled: true,
            pressed: true,
            onPressed: _noop,
          ),
          TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            onPressed: null,
          ),
          TtIconButton(
            icon: Symbols.close_rounded,
            semanticLabel: 'Close',
            style: style,
            onPressed: _noop,
          ),
        ],
      ),
    );
    if (style == TtIconButtonStyle.plain) return row;
    // The circle style sits over content; on video the icon is white over the picture.
    return DecoratedBox(
      decoration: BoxDecoration(image: _darkPhoto(2)),
      child: row,
    );
  }
}
