import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The trailing widget of a row in the playground.
enum _Trailing { none, chevron, value, switchOn, switchOff }

/// `TtGroupedRows`, `TtGroupLabel`, `TtRowIcon` and `TtListRow`: settings-style
/// groups of rows.
final WidgetbookComponent ttGroupedRowsComponent = WidgetbookComponent(
  name: 'TtGroupedRows / TtGroupLabel / TtRowIcon',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'rows',
          initialValue: 3,
          min: 1,
          max: 6,
        );
        final label = context.knobs.string(
          label: 'group label',
          initialValue: 'Reminders',
        );
        final showLabel = context.knobs.boolean(
          label: 'show group label',
          initialValue: true,
        );
        final trailing = context.knobs.object.dropdown<_Trailing>(
          label: 'trailing',
          options: _Trailing.values,
          initialOption: _Trailing.switchOn,
          labelBuilder: (v) => v.name,
        );
        final boxed = context.knobs.boolean(label: 'boxed icon');
        final withIcon = context.knobs.boolean(
          label: 'icon',
          initialValue: true,
        );
        final subtitle = context.knobs.boolean(
          label: 'subtitle',
          initialValue: true,
        );
        final tappable = context.knobs.boolean(label: 'tappable');
        final stack = context.knobs.boolean(
          label: 'stack trailing at large text',
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Evening reminder',
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel) TtGroupLabel(label),
              TtGroupedRows(
                children: [
                  for (var i = 0; i < count; i++)
                    TtListRow(
                      title: '$title ${i + 1}',
                      subtitle: subtitle ? 'Only if clips are waiting' : null,
                      leading: withIcon
                          ? TtRowIcon(
                              icon: Symbols.bedtime_rounded,
                              boxed: boxed,
                            )
                          : null,
                      trailing: switch (trailing) {
                        _Trailing.none => null,
                        _Trailing.chevron => const Icon(
                          Symbols.chevron_right_rounded,
                        ),
                        _Trailing.value => const Text('Allowed'),
                        _Trailing.switchOn => TtSwitch(
                          value: true,
                          onChanged: (_) {},
                          semanticLabel: '$title ${i + 1}',
                        ),
                        _Trailing.switchOff => TtSwitch(
                          value: false,
                          onChanged: (_) {},
                          semanticLabel: '$title ${i + 1}',
                        ),
                      },
                      stackTrailingAtLargeText: stack,
                      onTap: tappable ? () {} : null,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  ],
);

/// `TtRowCount`: the count at the end of a row, a pill or plain text.
final WidgetbookComponent ttRowCountComponent = WidgetbookComponent(
  name: 'TtRowCount',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final text = context.knobs.string(label: 'text', initialValue: '3 new');
        final pill = context.knobs.boolean(label: 'pill', initialValue: true);
        final off = context.knobs.boolean(label: 'row is off');
        return Padding(
          padding: EdgeInsets.symmetric(vertical: context.tt.spacing.m),
          child: TtGroupedRows(
            children: [
              TtListRow(
                title: 'Today',
                tall: true,
                off: off,
                trailing: TtRowCount(text, pill: pill),
                onTap: off ? null : () {},
              ),
            ],
          ),
        );
      },
    ),
  ],
);

/// `TtRowSpinner`: the 20 dp spinner that replaces a row's chevron.
final WidgetbookComponent ttRowSpinnerComponent = WidgetbookComponent(
  name: 'TtRowSpinner',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final reduced = context.knobs.boolean(label: 'animations removed');
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.xl),
            child: const Align(
              alignment: Alignment.topLeft,
              child: TtRowSpinner(semanticLabel: 'Checking your videos'),
            ),
          ),
        );
      },
    ),
  ],
);

/// `TtListRow` as the Add earlier videos sheet uses it: tall, with a count,
/// a skeleton, a spinner, and the off look (D-79).
final WidgetbookComponent ttListRowComponent = WidgetbookComponent(
  name: 'TtListRow',
  useCases: [
    WidgetbookUseCase(
      name: 'Add earlier videos rows',
      builder: (context) {
        final todayCount = context.knobs.int.slider(
          label: 'Today: new videos (0 = none)',
          initialValue: 3,
          max: 9,
        );
        final loading = context.knobs.boolean(label: 'loading the count');
        final counting = context.knobs.boolean(label: 'counting the dates');
        final adding = context.knobs.boolean(label: 'adding Today');
        final busy = loading || counting || adding;
        final off = busy || todayCount == 0;
        final count = loading
            ? const TtSkeletonCount()
            : adding
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  TtRowCount('Adding…', pill: false),
                  TtRowSpinner(semanticLabel: 'Adding'),
                ],
              )
            : todayCount == 0
            ? const TtRowCount('none', pill: false)
            : TtRowCount('$todayCount new');
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: context.tt.spacing.m),
          child: TtGroupedRows(
            children: [
              TtListRow(
                title: 'Today',
                subtitle: 'Wed, Oct 28',
                tall: true,
                leading: const TtRowIcon(
                  icon: Symbols.today_rounded,
                  boxed: false,
                ),
                trailing: count,
                stackTrailingAtLargeText: true,
                off: off,
                semanticLabel: 'Today',
                onTap: off ? null : () {},
              ),
              TtListRow(
                title: 'Choose dates…',
                subtitle: counting
                    ? 'Oct 8 – Oct 10 · Checking…'
                    : 'Up to 10 years back',
                tall: true,
                leading: const TtRowIcon(
                  icon: Symbols.edit_calendar_rounded,
                  boxed: false,
                ),
                trailing: counting
                    ? const TtRowSpinner(semanticLabel: 'Checking')
                    : const Icon(Symbols.chevron_right_rounded),
                off: busy,
                onTap: busy ? null : () {},
              ),
            ],
          ),
        );
      },
    ),
  ],
);
