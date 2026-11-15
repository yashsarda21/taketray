import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtIllustratedSteps / TtIllustratedStep`: steps with a small picture.
final WidgetbookComponent ttIllustratedStepsComponent = WidgetbookComponent(
  name: 'TtIllustratedSteps / TtIllustratedStep',
  useCases: [
    WidgetbookUseCase(
      name: 'The three steps',
      builder: (context) {
        final folder = context.knobs.string(
          label: 'folder name',
          initialValue: 'Café Hopping Bengaluru',
        );
        final highlighted = context.knobs.int.slider(
          label: 'highlighted folder',
          initialValue: 2,
          max: 3,
        );
        final tiles = context.knobs.int.slider(
          label: 'thumbnails',
          initialValue: 6,
          min: 1,
          max: 6,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: TtIllustratedSteps(
            steps: [
              const TtIllustratedStep.newProject(
                number: 'Step 1',
                title: 'Open VN, tap New project',
                body: "It's the big + button.",
              ),
              TtIllustratedStep.folders(
                number: 'Step 2',
                title: 'Open the $folder folder',
                body: 'Inside Movies › TakeTray.',
                folders: ['Camera', 'Download', folder, 'WhatsApp Video'],
                highlighted: highlighted,
              ),
              TtIllustratedStep.tiles(
                number: 'Step 3',
                title: 'Select all the clips',
                body: "They're already in shooting order.",
                thumbnails: [for (var i = 1; i <= tiles; i++) wbThumb(i)],
              ),
            ],
          ),
        );
      },
    ),
  ],
);
