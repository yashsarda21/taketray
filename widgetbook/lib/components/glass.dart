import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtGlass`: the frosted panel, over a sample photo.
final WidgetbookComponent ttGlassComponent = WidgetbookComponent(
  name: 'TtGlass',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final radius = context.knobs.double.slider(
          label: 'radius',
          initialValue: 20,
          max: 40,
        );
        final blur = context.knobs.double.slider(
          label: 'blur',
          initialValue: TtMetrics.glassBlur,
          max: 40,
        );
        final shadow = context.knobs.boolean(
          label: 'shadow',
          initialValue: true,
        );
        final tinted = context.knobs.boolean(label: 'tint');
        final text = context.knobs.string(
          label: 'text',
          initialValue: 'A glass panel over a photo',
        );
        return _Photo(
          child: TtGlass(
            radius: radius,
            blur: blur,
            shadow: shadow,
            tint: tinted ? context.scheme.primary.withValues(alpha: 0.4) : null,
            child: Padding(
              padding: EdgeInsets.all(context.tt.spacing.m),
              child: Text(text),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtGlassPill`: the dark-glass badge on media.
final WidgetbookComponent ttGlassPillComponent = WidgetbookComponent(
  name: 'TtGlassPill',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final colors = context.tt.colors;
        final icons = <String, IconData>{
          'link': Symbols.link_rounded,
          'record': Symbols.fiber_manual_record_rounded,
          'ready': Symbols.check_circle_rounded,
          'videocam': Symbols.videocam_rounded,
        };
        final icon = context.knobs.object.dropdown<String>(
          label: 'icon',
          options: icons.keys.toList(),
        );
        final withText = context.knobs.boolean(
          label: 'text',
          initialValue: true,
        );
        final text = context.knobs.string(label: 'label', initialValue: '3');
        final tone = context.knobs.object.dropdown<String>(
          label: 'icon colour',
          options: const ['white', 'record', 'ready', 'published'],
        );
        return _Photo(
          child: TtGlassPill(
            icon: icons[icon]!,
            iconColor: switch (tone) {
              'record' => colors.recordOnMedia,
              'ready' => colors.readyOnMedia,
              'published' => colors.publishedOnMedia,
              _ => null,
            },
            text: withText ? text : null,
            semanticLabel: withText ? text : 'Linked',
          ),
        );
      },
    ),
  ],
);

/// [child] on a sample photo.
class _Photo extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      image: DecorationImage(image: wbThumb(3), fit: BoxFit.cover),
    ),
    child: Padding(
      padding: EdgeInsets.all(context.tt.spacing.xl),
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}
