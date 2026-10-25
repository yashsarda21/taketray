import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReferenceCard`: a saved reference to a video to recreate.
final WidgetbookComponent ttReferenceCardComponent = WidgetbookComponent(
  name: 'TtReferenceCard',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Cafe tour in Porto',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: 'Instagram · instagram.com/reel/abc',
        );
        final more = context.knobs.boolean(
          label: 'more button',
          initialValue: true,
        );
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 328,
          min: 200,
          max: 400,
        );
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TtReferenceCard(
                title: title,
                subtitle: subtitle,
                // A stand-in for the app icon the phone supplies.
                sourceIcon: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.surfaceContainerLow,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: 18,
                    child: Center(
                      child: Text(
                        'I',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                openLabel: 'Open',
                openSemanticLabel: 'Open reference: $title',
                onOpen: () {},
                moreSemanticLabel: more ? 'More options for $title' : null,
                onMore: more ? () {} : null,
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtAddReferenceTile`: the dashed "Add reference" tile.
final WidgetbookComponent ttAddReferenceTileComponent = WidgetbookComponent(
  name: 'TtAddReferenceTile',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Add reference',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: 'Save a reel you want to recreate',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtAddReferenceTile(
            title: title,
            subtitle: subtitle,
            onPressed: () {},
          ),
        );
      },
    ),
  ],
);
