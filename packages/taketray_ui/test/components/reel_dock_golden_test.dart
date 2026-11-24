import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  // The player is always dark, so there is only a dark golden.
  ttGoldenTest(
    'Reel dock',
    fileName: 'reel_dock',
    brightnesses: const [Brightness.dark],
    scenarios: [
      TtScenario(
        'four chips',
        _onClip(
          _dock(
            chips: [
              for (var i = 1; i <= 3; i++) _chip(i),
              const TtNewReelChip(
                title: 'New reel',
                semanticLabel: 'New reel',
                style: TtReelChipStyle.onVideo,
              ),
            ],
            scrub: _scrub(),
            actions: [
              _action('Pick several', Symbols.library_add_check_rounded),
              _action('All reels', Symbols.apps_rounded),
            ],
          ),
        ),
      ),
      TtScenario(
        'no reels',
        _onClip(
          _dock(
            chips: const [
              TtNewReelChip(
                title: 'New reel',
                semanticLabel: 'New reel',
                fullWidth: true,
                style: TtReelChipStyle.onVideo,
              ),
            ],
            emptyText:
                "You don't have any reels yet. Create one and this clip "
                'goes into it.',
          ),
        ),
      ),
      TtScenario(
        'Pick several, with the footer',
        _onClip(
          _dock(
            title: 'Pick reels',
            chips: [
              _chip(1, state: TtReelChipState.picked),
              _chip(2),
              _chip(3, state: TtReelChipState.picked),
            ],
            actions: [
              _action('All reels', Symbols.apps_rounded),
              _action('Cancel', null),
            ],
            footer: TtButton(
              label: 'Add to 2 reels & next',
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ],
  );
}

TtReelChip _chip(int n, {TtReelChipState state = TtReelChipState.idle}) =>
    TtReelChip(
      name: n == 2 ? 'London Food and Drink' : 'Reel $n',
      countText: '${n * 3} clips',
      semanticLabel: 'Add to Reel $n',
      cover: fixtureThumb(n),
      state: state,
      multiSelect: state != TtReelChipState.idle,
      style: TtReelChipStyle.onVideo,
      onTap: () {},
    );

TtButton _action(String label, IconData? icon) => TtButton(
  label: label,
  icon: icon,
  kind: TtButtonKind.text,
  size: TtButtonSize.small,
  onPressed: () {},
);

TtReelDock _dock({
  required List<Widget> chips,
  String title = 'Add to reel',
  Widget? scrub,
  List<Widget> actions = const [],
  String? emptyText,
  Widget? footer,
}) => TtReelDock(
  title: title,
  semanticLabel: 'Reels',
  chips: chips,
  scrub: scrub,
  actions: actions,
  emptyText: emptyText,
  footer: footer,
);

Widget _scrub() => const TtScrubBar(
  progress: 0.26,
  positionText: '1:12',
  durationText: '4:32',
  semanticLabel: 'Playback position',
  semanticValue: '1:12 of 4:32',
);

/// [dock] under 120 dp of a stand-in for a very bright clip (the worst case
/// for the scrim): a pale gradient with a black bar, which runs on behind the
/// dock.
Widget _onClip(Widget dock) => DecoratedBox(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF2E3C2), Color(0xFFBFE3DE), Color(0xFFFFFFFF)],
    ),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        height: 120,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 150),
            child: SizedBox(
              width: 10,
              height: 120,
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      ),
      dock,
    ],
  ),
);
