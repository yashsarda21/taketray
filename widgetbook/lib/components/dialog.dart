import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtDialog`, `TtDialogNote` and `showTtDialog`: the pill-cornered dialog
/// and its reassurance line.
final WidgetbookComponent ttDialogComponent = WidgetbookComponent(
  name: 'TtDialog / TtDialogNote',
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
      name: 'Delete reel dialog',
      builder: (context) => Center(
        child: Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: const TtDialog<String>(
            title: 'Delete London Food?',
            icon: Symbols.delete_rounded,
            content: TtDialogNote(
              text:
                  'Your videos stay in your gallery. Only this reel and its '
                  'tags are removed.',
            ),
            actions: [
              TtDialogAction('cancel', 'Cancel'),
              TtDialogAction('delete', 'Delete reel', destructive: true),
            ],
          ),
        ),
      ),
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
                icon: knobs.icon,
                content: knobs.note == null
                    ? null
                    : TtDialogNote(text: knobs.note!),
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
  const new({
    required this.title,
    required this.body,
    required this.icon,
    required this.note,
    required this.actions,
  });

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
    final icon = context.knobs.boolean(label: 'icon')
        ? Symbols.delete_rounded
        : null;
    final note = context.knobs.stringOrNull(label: 'note');
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
      icon: icon,
      note: note,
      actions: [
        if (count > 1) TtDialogAction('first', first),
        if (count > 2) const TtDialogAction('middle', 'Later'),
        TtDialogAction('last', last, destructive: destructive),
      ],
    );
  }

  final String title;
  final String? body;
  final IconData? icon;
  final String? note;
  final List<TtDialogAction<String>> actions;
}
