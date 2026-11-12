import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtStorageBar`: whether the copies fit on the phone.
final WidgetbookComponent ttStorageBarComponent = WidgetbookComponent(
  name: 'TtStorageBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Enough room',
      builder: (context) {
        final percent = context.knobs.int.slider(
          label: 'copies, % of the free space',
          initialValue: 30,
          max: 100,
        );
        final need = context.knobs.string(
          label: 'copies label',
          initialValue: 'Copies: 1.2 GB',
        );
        final free = context.knobs.string(
          label: 'free-after label',
          initialValue: 'Free after copying: 3.1 GB',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: TtStorageBar.enough(
            needFraction: percent / 100,
            needLabel: need,
            freeAfterLabel: free,
            semanticLabel: '$need. $free.',
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Not enough room',
      builder: (context) {
        final percent = context.knobs.int.slider(
          label: 'the phone has, % of what is needed',
          initialValue: 60,
          max: 99,
        );
        final have = context.knobs.string(
          label: 'have label',
          initialValue: 'You have 1.8 GB',
        );
        final short = context.knobs.string(
          label: 'short label',
          initialValue: 'Short by 1.2 GB',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: TtStorageBar.short(
            haveFraction: percent / 100,
            haveLabel: have,
            shortLabel: short,
            semanticLabel: '$have. $short.',
          ),
        );
      },
    ),
  ],
);
