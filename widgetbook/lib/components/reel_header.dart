import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelHeader`: the name, status pill, facts and Shot ideas at the top of
/// a reel's detail screen.
final WidgetbookComponent ttReelHeaderComponent = WidgetbookComponent(
  name: 'TtReelHeader',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final name = context.knobs.string(
          label: 'name',
          initialValue: 'Lisbon trip',
        );
        final status = context.knobs.object.dropdown<TtStatusKind>(
          label: 'status',
          options: TtStatusKind.values,
          labelBuilder: (v) => v.name,
        );
        final clips = context.knobs.int.slider(
          label: 'clips',
          initialValue: 12,
          max: 300,
        );
        final missing = context.knobs.int.slider(label: 'missing');
        final ideas = context.knobs.string(
          label: 'shot ideas (empty for none)',
          initialValue:
              'Open on the tram, then the market stalls. Get the fish '
              'counter, the tile shop and the street musician. End on the '
              'view from the castle at golden hour.',
        );
        const names = {
          TtStatusKind.collecting: 'Collecting',
          TtStatusKind.ready: 'Ready to edit',
          TtStatusKind.published: 'Published',
        };
        return SingleChildScrollView(
          child: TtReelHeader<TtStatusKind>(
            name: name,
            statusKind: status,
            statusLabel: names[status]!,
            statusSemanticLabel: 'Status: ${names[status]}. Change',
            statusItems: [
              for (final kind in TtStatusKind.values)
                TtMenuItem<TtStatusKind>(
                  kind,
                  names[kind]!,
                  iconFilled: true,
                  checked: kind == status,
                ),
            ],
            onStatusSelected: (_) {},
            metaText: clips == 0 ? 'No clips yet' : '$clips clips · 4:32',
            missingText: missing == 0 ? null : '$missing missing',
            shotIdeas: ideas.isEmpty ? null : ideas,
            shotIdeasTitle: 'Shot ideas',
            showMoreLabel: 'Show more',
            showLessLabel: 'Show less',
          ),
        );
      },
    ),
  ],
);
