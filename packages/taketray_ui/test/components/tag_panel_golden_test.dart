import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Tag panel and same as previous',
    fileName: 'tag_panel',
    scenarios: [
      TtScenario(
        'panel, 5 chips, pick several',
        _overPhoto(
          TtTagPanel(
            title: 'Add to reel',
            chips: _chips(),
            headerAction: TtButton(
              label: 'Pick several',
              icon: Symbols.library_add_check_rounded,
              kind: TtButtonKind.text,
              size: TtButtonSize.small,
              onPressed: () {},
            ),
          ),
        ),
      ),
      TtScenario(
        'panel, multi-select with footer',
        _overPhoto(
          TtTagPanel(
            title: 'Pick reels for this clip',
            chips: _chips(multi: true),
            headerAction: TtButton(
              label: 'Cancel',
              kind: TtButtonKind.text,
              size: TtButtonSize.small,
              onPressed: () {},
            ),
            footer: TtButton(
              label: 'Add to 2 reels & next',
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
      TtScenario(
        'panel, long names',
        _overPhoto(TtTagPanel(title: 'Add to reel', chips: _chips(long: true))),
      ),
      TtScenario(
        'panel, names that share a first word',
        _overPhoto(
          TtTagPanel(title: 'Add to reel', chips: _chips(shared: true)),
        ),
      ),
      TtScenario(
        'same as previous, 3 reels',
        _padded(
          TtSameAsPreviousButton(
            label: 'Same as previous',
            detail: 'Lisbon trip, Autumn recipes, Garden',
            semanticLabel:
                'Same as previous: Lisbon trip, Autumn recipes, '
                'Garden',
            onPressed: () {},
          ),
        ),
      ),
      TtScenario(
        'same as previous, disabled',
        _padded(
          const TtSameAsPreviousButton(
            label: 'Same as previous',
            semanticLabel: 'Same as previous',
          ),
        ),
      ),
      TtScenario(
        'same as previous, long names',
        _padded(
          TtSameAsPreviousButton(
            label: 'Same as previous',
            detail:
                'Saturday morning market walk with the whole family, '
                'Autumn recipes, Garden',
            semanticLabel: 'Same as previous: long',
            onPressed: () {},
          ),
        ),
      ),
      TtScenario(
        'quick row: skip and same as previous',
        _padded(
          Row(
            spacing: 8,
            children: [
              TtButton(
                label: 'Skip',
                icon: Symbols.redo_rounded,
                kind: TtButtonKind.ghost,
                semanticLabel: 'Skip this clip',
                onPressed: () {},
              ),
              Expanded(
                child: TtSameAsPreviousButton(
                  label: 'Same as previous',
                  detail: 'Lisbon trip, Autumn recipes, Garden',
                  semanticLabel:
                      'Same as previous: Lisbon trip, Autumn '
                      'recipes, Garden',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _padded(Widget child) => TtVideoSurface(
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

/// The panel at the bottom of a frame of footage, as in the player.
Widget _overPhoto(Widget panel) => TtVideoSurface(
  child: SizedBox(
    height: 560,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image(image: fixtureThumb(3), fit: BoxFit.cover),
        Align(alignment: Alignment.bottomCenter, child: panel),
      ],
    ),
  ),
);

List<Widget> _chips({
  bool multi = false,
  bool long = false,
  bool shared = false,
}) {
  final names = shared
      ? [
          'Lisbon trip',
          'Lisbon food market',
          'Lisbon nights',
          'Lisbon food',
          'Lisbon',
        ]
      : long
      ? [
          'Saturday morning market walk with the whole family',
          'Autumn recipes from the farm kitchen',
          'Summer weekend by the lake',
          'Garden',
          'Birthday party',
        ]
      : [
          'Lisbon trip',
          'Autumn recipes',
          'Summer weekend',
          'Garden',
          'Birthday',
        ];
  return [
    for (var i = 0; i < names.length; i++)
      TtReelChip(
        name: names[i],
        countText: long ? '1234 clips' : '${12 - i * 2} clips',
        semanticLabel: 'Add to ${names[i]}',
        cover: i == 3 ? null : fixtureThumb(1 + i),
        multiSelect: multi,
        state: multi && i < 2 ? TtReelChipState.picked : TtReelChipState.idle,
        onTap: () {},
      ),
  ];
}
