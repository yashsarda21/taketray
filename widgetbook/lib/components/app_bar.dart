import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtAppBar`: the top bar, standard, large or in selection mode.
final WidgetbookComponent ttAppBarComponent = WidgetbookComponent(
  name: 'TtAppBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Trip to Lisbon',
        );
        final subtitle = context.knobs.string(
          label: 'subtitle (empty for none)',
          initialValue: '12 clips',
        );
        final large = context.knobs.boolean(label: 'large');
        final selection = context.knobs.boolean(label: 'selection');
        final liveRegion = context.knobs.boolean(
          label: 'liveRegion (selection only)',
        );
        final back = context.knobs.boolean(
          label: 'leading button',
          initialValue: true,
        );
        final actions = context.knobs.int.slider(
          label: 'actions',
          initialValue: 2,
          max: 3,
        );
        const icons = [
          (Symbols.search_rounded, 'Search'),
          (Symbols.sell_rounded, 'Tag'),
          (Symbols.more_vert_rounded, 'More'),
        ];
        return Align(
          alignment: Alignment.topCenter,
          child: TtAppBar(
            title: title,
            subtitle: subtitle.isEmpty ? null : subtitle,
            large: large,
            selection: selection,
            liveRegion: liveRegion,
            leading: back
                ? TtIconButton(
                    icon: Symbols.arrow_back_rounded,
                    semanticLabel: 'Back',
                    style: TtIconButtonStyle.circle,
                    onPressed: () {},
                  )
                : null,
            actions: [
              for (final (icon, label) in icons.take(actions))
                TtIconButton(
                  icon: icon,
                  semanticLabel: label,
                  style: TtIconButtonStyle.circle,
                  onPressed: () {},
                ),
            ],
          ),
        );
      },
    ),
  ],
);

/// `TtHeaderPill`: the tonal "+ New" button at the end of a header.
final WidgetbookComponent ttHeaderPillComponent = WidgetbookComponent(
  name: 'TtHeaderPill',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final label = context.knobs.string(label: 'label', initialValue: 'New');
        return Align(
          alignment: AlignmentDirectional.topEnd,
          child: TtHeaderPill(
            icon: Symbols.add_rounded,
            label: label,
            semanticLabel: 'New reel',
            onPressed: () {},
          ),
        );
      },
    ),
  ],
);

/// `TtLargeSliverAppBar`: a large title that shrinks into a pinned bar as
/// the page scrolls.
final WidgetbookComponent ttLargeSliverAppBarComponent = WidgetbookComponent(
  name: 'TtLargeSliverAppBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Reels',
        );
        final pill = context.knobs.boolean(
          label: 'header pill',
          initialValue: true,
        );
        return CustomScrollView(
          slivers: [
            TtLargeSliverAppBar(
              title: title,
              actions: [
                if (pill)
                  TtHeaderPill(
                    icon: Symbols.add_rounded,
                    label: 'New',
                    semanticLabel: 'New reel',
                    onPressed: () {},
                  ),
              ],
            ),
            SliverList.builder(
              itemCount: 30,
              itemBuilder: (context, i) =>
                  ListTile(title: Text('Row ${i + 1}')),
            ),
          ],
        );
      },
    ),
  ],
);
