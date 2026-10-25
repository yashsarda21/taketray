import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtTagPanel`: the glass panel of reel chips at the bottom of the tag
/// player.
final WidgetbookComponent ttTagPanelComponent = WidgetbookComponent(
  name: 'TtTagPanel',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Add to reel',
        );
        final count = context.knobs.int.slider(
          label: 'chips (more than fit scroll)',
          initialValue: 5,
          max: 40,
        );
        final action = context.knobs.boolean(
          label: 'header action',
          initialValue: true,
        );
        final footer = context.knobs.boolean(label: 'footer button');
        final multi = context.knobs.boolean(label: 'multi-select chips');
        return TtVideoSurface(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: wbThumb(3), fit: BoxFit.cover),
              Align(
                alignment: Alignment.bottomCenter,
                child: TtTagPanel(
                  title: title,
                  headerAction: action
                      ? TtButton(
                          label: 'Pick several',
                          icon: Symbols.library_add_check_rounded,
                          kind: TtButtonKind.text,
                          size: TtButtonSize.small,
                          onPressed: () {},
                        )
                      : null,
                  footer: footer
                      ? TtButton(
                          label: 'Add to 2 reels & next',
                          expand: true,
                          onPressed: () {},
                        )
                      : null,
                  chips: [
                    for (var i = 0; i < count; i++)
                      _chip(
                        i < _names.length ? _names[i] : 'Reel ${i + 1}',
                        i,
                        multi: multi,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  ],
);

TtReelChip _chip(String name, int i, {required bool multi}) => TtReelChip(
  name: name,
  countText: '${(i * 7) % 30} clips',
  semanticLabel: 'Add to $name',
  cover: i % 4 == 3 ? null : wbThumb(1 + i % 12),
  multiSelect: multi,
  state: multi && i < 2 ? TtReelChipState.picked : TtReelChipState.idle,
  onTap: () {},
);

const _names = [
  'Lisbon trip',
  'Autumn recipes',
  'Summer weekend',
  'Garden',
  'Birthday',
  'Saturday morning market walk with the whole family',
];

/// `TtSameAsPreviousButton`: repeats the last clip's reels.
final WidgetbookComponent ttSameAsPreviousButtonComponent = WidgetbookComponent(
  name: 'TtSameAsPreviousButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final label = context.knobs.string(
          label: 'label',
          initialValue: 'Same as previous',
        );
        final reels = context.knobs.int.slider(
          label: 'reels in the detail (0 = no detail)',
          max: 6,
          initialValue: 3,
        );
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 328,
          min: 160,
          max: 328,
        );
        final detail = reels == 0 ? null : _names.take(reels).join(', ');
        return TtVideoSurface(
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.m),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: TtSameAsPreviousButton(
                  label: label,
                  detail: detail,
                  semanticLabel: 'Same as previous: ${detail ?? ''}',
                  onPressed: enabled ? () {} : null,
                ),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
