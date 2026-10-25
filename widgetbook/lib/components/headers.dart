import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSceneHeader`: a scene's title and subtitle with an action.
final WidgetbookComponent ttSceneHeaderComponent = WidgetbookComponent(
  name: 'TtSceneHeader',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: '9:41 – 10:05 AM',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle',
          initialValue: '8 clips · 2:14',
        );
        final action = context.knobs.string(
          label: 'action',
          initialValue: 'Tag scene',
        );
        return TtSceneHeader(
          title: title,
          subtitle: subtitle,
          action: TtButton(
            label: action,
            icon: Symbols.sell_rounded,
            kind: TtButtonKind.tonal,
            size: TtButtonSize.small,
            onPressed: () {},
          ),
        );
      },
    ),
  ],
);

/// `TtDayHeader`: a day's title with small text after it.
final WidgetbookComponent ttDayHeaderComponent = WidgetbookComponent(
  name: 'TtDayHeader',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Day 2 · Sat 13 Jun',
        );
        final withTrailing = context.knobs.boolean(
          label: 'trailing',
          initialValue: true,
        );
        final trailing = context.knobs.string(
          label: 'trailing text',
          initialValue: '14 clips',
        );
        return TtDayHeader(
          title: title,
          trailing: withTrailing ? trailing : null,
        );
      },
    ),
  ],
);
