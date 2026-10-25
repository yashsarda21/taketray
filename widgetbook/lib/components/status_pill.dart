import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtStatusPill`: a reel's status, on a surface or as dark glass on media.
final WidgetbookComponent ttStatusPillComponent = WidgetbookComponent(
  name: 'TtStatusPill',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final kind = context.knobs.object.dropdown<TtStatusKind>(
          label: 'kind',
          options: TtStatusKind.values,
          labelBuilder: (v) => v.name,
        );
        final onMedia = context.knobs.boolean(label: 'on media');
        final large = context.knobs.boolean(label: 'large');
        final pressable = context.knobs.boolean(label: 'pressable (caret)');
        final label = context.knobs.string(
          label: 'label',
          initialValue: switch (kind) {
            TtStatusKind.collecting => 'Collecting',
            TtStatusKind.ready => 'Ready to edit',
            TtStatusKind.published => 'Published',
          },
        );
        final pill = TtStatusPill(
          kind: kind,
          label: label,
          onMedia: onMedia,
          large: large,
          onPressed: pressable ? () {} : null,
          semanticLabel: pressable ? 'Status: $label. Change status' : null,
        );
        final padded = Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: Align(alignment: Alignment.topLeft, child: pill),
        );
        if (!onMedia) return padded;
        return DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: wbThumb(3), fit: BoxFit.cover),
          ),
          child: padded,
        );
      },
    ),
  ],
);
