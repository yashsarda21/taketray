import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtDialog` and `showTtDialog`: the pill-cornered dialog.
final WidgetbookComponent ttDialogComponent = WidgetbookComponent(
  name: 'TtDialog',
  useCases: [
    WidgetbookUseCase(
      name: 'Dialog panel',
      builder: (context) {
        final knobs = _DialogKnobs.of(context);
        return Center(
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.xl),
            child: TtDialog<String>(
              title: knobs.title,
              body: knobs.body,
              actions: knobs.actions,
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'showTtDialog',
      builder: (context) {
        final knobs = _DialogKnobs.of(context);
        return Center(
          child: Builder(
            builder: (context) => TtButton(
              label: 'Show dialog',
              onPressed: () => showTtDialog<String>(
                context,
                title: knobs.title,
                body: knobs.body,
                actions: knobs.actions,
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// The dialog's knobs, read once per use case.
class _DialogKnobs {
  const new({required this.title, required this.body, required this.actions});

  factory of(BuildContext context) {
    final title = context.knobs.string(
      label: 'title',
      initialValue: 'Stop copying?',
    );
    final body = context.knobs.stringOrNull(
      label: 'body',
      initialValue:
          'The 12 copies made so far will be deleted. Your original clips '
          'are not affected.',
    );
    final count = context.knobs.int.slider(
      label: 'actions',
      initialValue: 2,
      min: 1,
      max: 3,
    );
    final first = context.knobs.string(
      label: 'first action',
      initialValue: 'Keep copying',
    );
    final last = context.knobs.string(
      label: 'last action',
      initialValue: 'Stop',
    );
    final destructive = context.knobs.boolean(
      label: 'last action destructive',
      initialValue: true,
    );
    return _DialogKnobs(
      title: title,
      body: body,
      actions: [
        if (count > 1) TtDialogAction('first', first),
        if (count > 2) const TtDialogAction('middle', 'Later'),
        TtDialogAction('last', last, destructive: destructive),
      ],
    );
  }

  final String title;
  final String? body;
  final List<TtDialogAction<String>> actions;
}
