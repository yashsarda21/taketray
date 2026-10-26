import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSheet` and `showTtSheet`: the floating bottom sheet.
final WidgetbookComponent ttSheetComponent = WidgetbookComponent(
  name: 'TtSheet',
  useCases: [
    WidgetbookUseCase(
      name: 'Sheet panel',
      builder: (context) {
        final knobs = _SheetKnobs.of(context);
        return Align(
          alignment: Alignment.bottomCenter,
          child: knobs.build(context),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'showTtSheet',
      builder: (context) {
        final knobs = _SheetKnobs.of(context);
        final dismissible = context.knobs.boolean(
          label: 'dismissible (scrim tap, drag)',
          initialValue: true,
        );
        return Center(
          child: Builder(
            builder: (context) => TtButton(
              label: 'Show sheet',
              onPressed: () => showTtSheet<void>(
                context,
                fullScreen: knobs.fullScreen,
                isDismissible: dismissible,
                builder: knobs.build,
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// The sheet's knobs, read once per use case.
class _SheetKnobs {
  const new({
    required this.title,
    required this.rows,
    required this.footer,
    required this.field,
    required this.fullScreen,
  });

  factory of(BuildContext context) => _SheetKnobs(
    title: context.knobs.stringOrNull(label: 'title', initialValue: 'New reel'),
    rows: context.knobs.int.slider(
      label: 'list rows',
      initialValue: 3,
      max: 30,
    ),
    footer: context.knobs.boolean(label: 'footer', initialValue: true),
    field: context.knobs.boolean(label: 'text field (keyboard)'),
    fullScreen: context.knobs.boolean(label: 'full screen'),
  );

  final String? title;
  final int rows;
  final bool footer;
  final bool field;
  final bool fullScreen;

  Widget build(BuildContext context) => TtSheet(
    title: title,
    fullScreen: fullScreen,
    footer: footer
        ? TtButtonRow(
            children: [
              TtButton(
                label: 'Cancel',
                kind: TtButtonKind.tonal,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              TtButton(
                label: 'Create',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          )
        : null,
    child: ListView(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.tt.spacing.xl),
      children: [
        if (field) const TtTextField(label: 'Reel name'),
        for (var i = 1; i <= rows; i++)
          SizedBox(
            height: context.tt.sizes.touchTarget,
            child: Row(
              children: [
                const Icon(Symbols.movie_rounded),
                SizedBox(width: context.tt.spacing.m),
                Expanded(child: Text('Reel $i')),
              ],
            ),
          ),
      ],
    ),
  );
}
