import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtButton`: every kind and size, with and without an icon, enabled or not.
final WidgetbookComponent ttButtonComponent = WidgetbookComponent(
  name: 'TtButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final kind = context.knobs.object.dropdown<TtButtonKind>(
          label: 'kind',
          options: TtButtonKind.values,
          labelBuilder: (v) => v.name,
        );
        final size = context.knobs.object.dropdown<TtButtonSize>(
          label: 'size',
          options: TtButtonSize.values,
          initialOption: TtButtonSize.medium,
          labelBuilder: (v) => v.name,
        );
        final label = context.knobs.string(
          label: 'label',
          initialValue: 'Save',
        );
        final withIcon = context.knobs.boolean(label: 'icon');
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final expand = context.knobs.boolean(label: 'expand');
        final onPhoto = context.knobs.boolean(
          label: 'on a photo (for ghost)',
          initialValue: kind == TtButtonKind.ghost,
        );
        final button = TtButton(
          label: label,
          kind: kind,
          size: size,
          icon: withIcon ? Symbols.sell_rounded : null,
          expand: expand,
          onPressed: enabled ? () {} : null,
        );
        return _Stage(onPhoto: onPhoto, child: button);
      },
    ),
  ],
);

/// `TtIconButton`: the three styles, filled glyph, toggle state.
final WidgetbookComponent ttIconButtonComponent = WidgetbookComponent(
  name: 'TtIconButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final style = context.knobs.object.dropdown<TtIconButtonStyle>(
          label: 'style',
          options: TtIconButtonStyle.values,
          labelBuilder: (v) => v.name,
        );
        final filled = context.knobs.boolean(label: 'filled glyph');
        final toggle = context.knobs.boolean(label: 'toggle');
        final pressed = context.knobs.boolean(label: 'pressed');
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        return _Stage(
          onPhoto: style != TtIconButtonStyle.plain,
          child: TtIconButton(
            icon: Symbols.favorite_rounded,
            semanticLabel: 'Favourite',
            style: style,
            filled: filled,
            pressed: toggle ? pressed : null,
            onPressed: enabled ? () {} : null,
          ),
        );
      },
    ),
  ],
);

/// `TtFab`: the extended floating action button.
final WidgetbookComponent ttFabComponent = WidgetbookComponent(
  name: 'TtFab',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => _Stage(
        onPhoto: false,
        child: TtFab(
          label: context.knobs.string(label: 'label', initialValue: 'Shoot'),
          icon: Symbols.videocam_rounded,
          liftBy: context.knobs.boolean(label: 'snack showing (lifted)')
              ? TtMetrics.fabSnackLift
              : 0,
          onPressed: () {},
        ),
      ),
    ),
  ],
);

/// `TtButtonRow`: equal-width buttons that stack when a label does not fit.
final WidgetbookComponent ttButtonRowComponent = WidgetbookComponent(
  name: 'TtButtonRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'buttons',
          initialValue: 2,
          min: 1,
          max: 3,
        );
        final first = context.knobs.string(
          label: 'first label',
          initialValue: 'Cancel',
        );
        final last = context.knobs.string(
          label: 'last label',
          initialValue: 'Add to reel',
        );
        final size = context.knobs.object.dropdown<TtButtonSize>(
          label: 'size',
          options: TtButtonSize.values,
          initialOption: TtButtonSize.medium,
          labelBuilder: (v) => v.name,
        );
        return _Stage(
          onPhoto: false,
          child: TtButtonRow(
            children: [
              for (var i = 0; i < count; i++)
                TtButton(
                  label: i == count - 1
                      ? last
                      : i == 0
                      ? first
                      : 'Skip',
                  size: size,
                  kind: i == count - 1
                      ? TtButtonKind.filled
                      : TtButtonKind.tonal,
                  onPressed: () {},
                ),
            ],
          ),
        );
      },
    ),
  ],
);

/// [child] centred, over a sample photo with a video scrim when [onPhoto].
class _Stage extends StatelessWidget {
  const new({required this.child, required this.onPhoto});

  final Widget child;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.all(context.tt.spacing.xl),
      child: Align(alignment: Alignment.topLeft, child: child),
    );
    if (!onPhoto) return padded;
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: wbThumb(2),
          fit: BoxFit.cover,
          colorFilter: const ColorFilter.mode(
            Colors.black54,
            BlendMode.srcOver,
          ),
        ),
      ),
      child: padded,
    );
  }
}
