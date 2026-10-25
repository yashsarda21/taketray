import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a tile in the 2-column reel grid at 360 dp (16 + 12 + 16).
const _tile = 158.0;

void main() {
  ttGoldenTest(
    'Reel card',
    fileName: 'reel_card',
    width: _tile,
    scenarios: [
      TtScenario('collecting, with cover', _card(cover: fixtureThumb(1))),
      TtScenario(
        'ready, with cover',
        _card(
          cover: fixtureThumb(2),
          status: TtStatusKind.ready,
          label: 'Ready to edit',
          name: 'Summer weekend',
        ),
      ),
      TtScenario(
        'published, with cover',
        _card(
          cover: fixtureThumb(3),
          status: TtStatusKind.published,
          label: 'Published',
          name: 'Autumn recipes',
        ),
      ),
      TtScenario('empty', _card(name: 'New reel', meta: '0 clips')),
      TtScenario(
        'with missing clips',
        _card(cover: fixtureThumb(4), missing: '2 missing'),
      ),
      TtScenario(
        'empty, with missing clips',
        _card(missing: '3 missing', meta: '0 clips'),
      ),
      TtScenario(
        'Editing in VN',
        _card(cover: fixtureThumb(5), vn: 'Editing in VN'),
      ),
      TtScenario('with 3 references', _card(cover: fixtureThumb(6), refs: 3)),
      TtScenario(
        'long name',
        _card(
          cover: fixtureThumb(1),
          name: 'Saturday morning market walk with the whole family',
          meta: '1234 clips · 12:34:56',
          missing: '12 missing',
          vn: 'Editing in VN',
          refs: 12,
        ),
      ),
      TtScenario(
        'long name, empty',
        _card(
          name: 'Saturday morning market walk with the whole family',
          meta: '1234 clips · 12:34:56',
          refs: 3,
        ),
      ),
      TtScenario('image fails to load', _card(cover: brokenImage, refs: 1)),
    ],
  );
}

Widget _card({
  ImageProvider? cover,
  String name = 'Lisbon trip',
  String meta = '12 clips · 1:03',
  TtStatusKind status = TtStatusKind.collecting,
  String label = 'Collecting',
  String? missing,
  String? vn,
  int refs = 0,
}) => TtReelCard(
  name: name,
  semanticLabel: '$name. $label. $meta',
  status: status,
  statusLabel: label,
  meta: meta,
  emptyLabel: 'No clips yet',
  cover: cover,
  missingText: missing,
  vnLabel: vn,
  referenceCount: refs,
  referencesSemanticLabel: '$refs references in $name',
  onTap: () {},
  onReferencesTap: () {},
);
