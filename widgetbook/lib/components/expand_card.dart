import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtExpandCard`: a card that opens to show its body. Tap the header to try
/// it; the knob sets where it starts.
final WidgetbookComponent ttExpandCardComponent = WidgetbookComponent(
  name: 'TtExpandCard',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Samsung',
        );
        final badge = context.knobs.string(
          label: 'badge (empty for none)',
          initialValue: 'Your phone',
        );
        final startOpen = context.knobs.boolean(
          label: 'starts expanded',
          initialValue: true,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          // Keyed by the knob, so changing it starts the card again.
          child: _OpenCard(
            key: ValueKey(startOpen),
            startOpen: startOpen,
            title: title,
            badge: badge.isEmpty ? null : badge,
          ),
        );
      },
    ),
  ],
);

class _OpenCard extends StatefulWidget {
  const new({
    required this.startOpen,
    required this.title,
    required this.badge,
    super.key,
  });

  final bool startOpen;
  final String title;
  final String? badge;

  @override
  State<_OpenCard> createState() => _OpenCardState();
}

class _OpenCardState extends State<_OpenCard> {
  late bool _open = widget.startOpen;

  @override
  Widget build(BuildContext context) => TtExpandCard(
    title: widget.title,
    badge: widget.badge,
    expanded: _open,
    onToggle: () => setState(() => _open = !_open),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.tt.spacing.s,
      children: [
        const TtStepList([
          'Open Settings › Battery › Background usage limits.',
          'Tap Never sleeping apps and add TakeTray.',
          'If TakeTray is under Sleeping apps, remove it.',
        ]),
        TtButton(
          label: 'Open battery settings',
          icon: Symbols.open_in_new_rounded,
          kind: TtButtonKind.tonal,
          onPressed: () {},
        ),
      ],
    ),
  );
}
