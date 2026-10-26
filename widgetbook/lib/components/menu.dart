import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtMenuButton`: a "more" button that opens a menu.
final WidgetbookComponent ttMenuButtonComponent = WidgetbookComponent(
  name: 'TtMenuButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
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
  ],
);
