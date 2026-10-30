import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtMenuButton`: a "more" button that opens a menu.
final WidgetbookComponent ttMenuButtonComponent = WidgetbookComponent(
  name: 'TtMenuButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Reel menu',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'items',
          initialValue: 3,
          min: 1,
          max: 6,
        );
        final destructive = context.knobs.boolean(
          label: 'last item destructive',
          initialValue: true,
        );
        final icons = context.knobs.boolean(label: 'icons', initialValue: true);
        final long = context.knobs.boolean(label: 'long labels');
        const samples = [
          ('Reel details', Symbols.edit_rounded),
          ('Select clips', Symbols.checklist_rounded),
          ('Share', Symbols.share_rounded),
          ('Edit video', Symbols.movie_edit_rounded),
          ('Select all', Symbols.select_all_rounded),
          ('Delete reel', Symbols.delete_rounded),
        ];
        final items = [
          for (var i = 0; i < count; i++)
            TtMenuItem<int>(
              i,
              long
                  ? '${samples[i].$1} for every clip in this long reel'
                  : samples[i].$1,
              icon: icons ? samples[i].$2 : null,
              destructive: destructive && i == count - 1,
            ),
        ];
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.xs),
            child: Builder(
              builder: (context) => TtMenuButton<int>(
                items: items,
                onSelected: (value) => ScaffoldMessenger.maybeOf(context)
                    ?.showSnackBar(
                      SnackBar(content: Text('Picked ${items[value].label}')),
                    ),
                builder: (context, open) => TtIconButton(
                  icon: Symbols.more_vert_rounded,
                  semanticLabel: 'More',
                  onPressed: open,
                ),
              ),
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Status menu',
      builder: (context) {
        final current = context.knobs.object.dropdown<TtStatusKind>(
          label: 'current status',
          options: TtStatusKind.values,
          labelBuilder: (v) => v.name,
        );
        const labels = {
          TtStatusKind.collecting: (
            'Collecting',
            'Still shooting clips for it',
            Symbols.radio_button_checked_rounded,
          ),
          TtStatusKind.ready: (
            'Ready to edit',
            'All the clips are in',
            Symbols.content_cut_rounded,
          ),
          TtStatusKind.published: (
            'Published',
            'Posted on Instagram',
            Symbols.check_circle_rounded,
          ),
        };
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.m),
            child: TtMenuButton<TtStatusKind>(
              items: [
                for (final kind in TtStatusKind.values)
                  TtMenuItem<TtStatusKind>(
                    kind,
                    labels[kind]!.$1,
                    icon: labels[kind]!.$3,
                    iconFilled: true,
                    subtitle: labels[kind]!.$2,
                    checked: kind == current,
                  ),
              ],
              onSelected: (_) {},
              builder: (context, open) => TtStatusPill(
                kind: current,
                label: labels[current]!.$1,
                large: true,
                onPressed: open,
              ),
            ),
          ),
        );
      },
    ),
  ],
);
