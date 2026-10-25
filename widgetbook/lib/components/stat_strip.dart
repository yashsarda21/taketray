import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtStatStrip`: the thin status line above a list.
final WidgetbookComponent ttStatStripComponent = WidgetbookComponent(
  name: 'TtStatStrip',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final live = context.knobs.boolean(
          label: 'live (record dot)',
          initialValue: true,
        );
        final muted = context.knobs.boolean(label: 'muted');
        final text = context.knobs.string(
          label: 'text',
          initialValue: 'Shooting since 9:41 AM',
        );
        final withAction = context.knobs.boolean(
          label: 'action',
          initialValue: true,
        );
        return TtStatStrip(
          leading: live
              ? const TtRecDot(compact: true)
              : const Icon(Symbols.videocam_off_rounded),
          text: text,
          muted: muted,
          action: withAction
              ? TtButton(
                  label: live ? 'Open camera' : 'Turn on',
                  icon: live ? Symbols.videocam_rounded : null,
                  kind: TtButtonKind.text,
                  onPressed: () {},
                )
              : null,
        );
      },
    ),
  ],
);
