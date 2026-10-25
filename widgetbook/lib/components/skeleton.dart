import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtClipTileSkeleton`: a loading tile with a light band sweeping across.
final WidgetbookComponent ttClipTileSkeletonComponent = WidgetbookComponent(
  name: 'TtClipTileSkeleton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 107,
          min: 60,
          max: 240,
        );
        final reduced = context.knobs.boolean(label: 'animations removed');
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.xl),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: const TtClipTileSkeleton()),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtSkeletonLine`: a grey bar standing in for a line of text.
final WidgetbookComponent ttSkeletonLineComponent = WidgetbookComponent(
  name: 'TtSkeletonLine',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final factor = context.knobs.double.slider(
          label: 'width factor',
          initialValue: 0.4,
          min: 0.1,
          max: 1,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtSkeletonLine(widthFactor: factor),
        );
      },
    ),
  ],
);
