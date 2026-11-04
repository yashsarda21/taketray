import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtTagDone`: the "All done!" screen at the end of the tag player.
final WidgetbookComponent ttTagDoneComponent = WidgetbookComponent(
  name: 'TtTagDone',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'All done!',
        );
        final body = context.knobs.string(
          label: 'body',
          initialValue: '10 clips sorted. Nice work.',
        );
        final reels = context.knobs.int.slider(
          label: 'reel rows (more than fit scroll)',
          initialValue: 2,
          max: 30,
        );
        final skipped = context.knobs.boolean(
          label: 'skipped row',
          initialValue: true,
        );
        return TtTagDone(
          title: title,
          body: body,
          rows: [
            for (var i = 0; i < reels; i++)
              TtTagDoneRow(
                name: i == 0 ? 'Lisbon trip' : 'Reel ${i + 1}',
                count: '+${5 - i % 4}',
              ),
            if (skipped) const TtTagDoneRow(name: 'Skipped', count: '3'),
          ],
          primaryLabel: 'See your reels',
          onPrimary: () {},
          secondaryLabel: 'Back to To tag',
          onSecondary: () {},
        );
      },
    ),
  ],
);
