import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtIllustration`: the seven flat illustrations.
final WidgetbookComponent ttIllustrationComponent = WidgetbookComponent(
  name: 'TtIllustration',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => Center(
        child: TtIllustration(
          context.knobs.object.dropdown<TtIllustrationKind>(
            label: 'kind',
            options: TtIllustrationKind.values,
            labelBuilder: (v) => v.name,
          ),
        ),
      ),
    ),
  ],
);

/// `TtEmptyState`: an illustration, a title, a body and up to two actions.
final WidgetbookComponent ttEmptyStateComponent = WidgetbookComponent(
  name: 'TtEmptyState',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final kind = context.knobs.object.dropdown<TtIllustrationKind>(
          label: 'illustration',
          options: TtIllustrationKind.values,
          labelBuilder: (v) => v.name,
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Nothing to tag',
        );
        final body = context.knobs.string(
          label: 'body',
          initialValue:
              'Turn on Shooting mode before you start filming. New '
              'videos will show up here.',
        );
        final actions = context.knobs.int.slider(
          label: 'actions',
          initialValue: 2,
          max: 2,
        );
        return SingleChildScrollView(
          child: TtEmptyState(
            illustration: kind,
            title: title,
            body: body,
            actions: [
              if (actions > 0)
                TtButton(
                  label: 'Turn on Shooting mode',
                  icon: Symbols.videocam_rounded,
                  onPressed: () {},
                ),
              if (actions > 1)
                TtButton(
                  label: 'Add videos',
                  icon: Symbols.library_add_rounded,
                  kind: TtButtonKind.text,
                  onPressed: () {},
                ),
            ],
          ),
        );
      },
    ),
  ],
);
