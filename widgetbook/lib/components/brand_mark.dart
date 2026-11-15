import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtBrandMark`: the launcher icon in a circle, at any size.
final WidgetbookComponent ttBrandMarkComponent = WidgetbookComponent(
  name: 'TtBrandMark',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final size = context.knobs.double.slider(
          label: 'size',
          initialValue: 28,
          min: 16,
          max: 192,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: Align(
            alignment: Alignment.topLeft,
            child: TtBrandMark(size: size),
          ),
        );
      },
    ),
  ],
);
