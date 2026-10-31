import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtNavPill`: the floating glass tab bar, over a sample photo.
final WidgetbookComponent ttNavPillComponent = WidgetbookComponent(
  name: 'TtNavPill',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final selected = context.knobs.int.slider(
          label: 'selected index',
          max: 2,
        );
        final badge = context.knobs.int.slider(
          label: 'To tag badge',
          initialValue: 7,
          max: 120,
        );
        final longLabel = context.knobs.boolean(label: 'long label');
        return StatefulBuilder(
          key: ValueKey(selected),
          builder: (context, setState) {
            var current = selected;
            return StatefulBuilder(
              builder: (context, setInner) => DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(image: wbThumb(3), fit: BoxFit.cover),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TtNavPill(
                    currentIndex: current,
                    onSelected: (i) => setInner(() => current = i),
                    items: [
                      const TtNavItem(
                        icon: Symbols.video_library_rounded,
                        label: 'Reels',
                      ),
                      TtNavItem(
                        icon: Symbols.sell_rounded,
                        label: 'To tag',
                        badgeCount: badge,
                        badgeSemanticLabel: 'To tag, $badge clips',
                      ),
                      TtNavItem(
                        icon: Symbols.settings_rounded,
                        label: longLabel
                            ? 'Settings and preferences'
                            : 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ],
);
