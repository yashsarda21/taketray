import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a full-width card at 360 dp (16 + 328 + 16).
const _full = 328.0;

const _longSubtitle =
    'On since 9:41 AM · Manual mode: add clips yourself, because TakeTray '
    'cannot see new videos on its own right now';

void main() {
  ttGoldenTest(
    'Shooting mode card',
    fileName: 'shooting_mode_card',
    width: _full,
    // The record dot never settles: decode the pictures, then show it 0.3 s
    // into a pulse.
    pumpBeforeTest: (tester) async {
      await ttDecodeImages(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
    scenarios: [
      const TtScenario('off', _Card(on: false)),
      const TtScenario(
        'off, long subtitle',
        _Card(on: false, subtitle: _longSubtitle),
      ),
      TtScenario(
        'on, backdrop, references and to-tag',
        _Card(backdrop: fixtureThumb(2), rows: true),
      ),
      const TtScenario('on, no backdrop', _Card()),
      const TtScenario(
        'on, no backdrop, references and to-tag',
        _Card(rows: true),
      ),
      TtScenario(
        'on, long subtitle',
        _Card(backdrop: fixtureThumb(4), subtitle: _longSubtitle, rows: true),
      ),
      TtScenario(
        'on, backdrop fails to load',
        _Card(backdrop: brokenImage, rows: true),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const new({this.on = true, this.subtitle, this.backdrop, this.rows = false});

  final bool on;
  final String? subtitle;
  final ImageProvider? backdrop;
  final bool rows;

  @override
  Widget build(BuildContext context) => TtShootingModeCard(
    on: on,
    title: on ? 'Shooting mode on' : 'Shooting mode',
    subtitle:
        subtitle ??
        (on
            ? 'On since 9:41 AM'
            : 'Off. Turn on before you start filming, and new videos wait in '
                  'To tag.'),
    switchSemanticLabel: 'Shooting mode',
    onChanged: (_) {},
    backdrop: backdrop,
    cameraLabel: 'Open camera',
    onOpenCamera: () {},
    referencesRow: rows
        ? TtCardRow(
            icon: Symbols.link_rounded,
            title: 'References · 4',
            subtitle: 'From 2 Recording reels',
            onPressed: () {},
          )
        : null,
    toTagStrip: rows
        ? TtCardRow(
            icon: Symbols.sell_rounded,
            title: '3 clips to tag',
            trailingText: 'Tag now',
            onPressed: () {},
          )
        : null,
  );
}
