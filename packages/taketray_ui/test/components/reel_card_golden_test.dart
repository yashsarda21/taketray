import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

/// The width of a card in the 2-column Home grid at 360 dp (16 + 12 + 16).
const _tile = 158.0;

/// The width of a card in the one-column grid at large text.
const _wide = 328.0;

void main() {
  ttGoldenTest(
    'Reel card',
    fileName: 'reel_card',
    width: _tile,
    // The cover that is still decoding shows a shimmer that never settles:
    // decode the other covers, then show it 0.4 s into a sweep.
    pumpBeforeTest: (tester) async {
      final pending = <(ImageProvider, Element)>[
        for (final element in find.byType(Image).evaluate())
          if ((element.widget as Image).image is! _Pending)
            ((element.widget as Image).image, element),
      ];
      await tester.runAsync(
        () => Future.wait([
          for (final (image, element) in pending)
            precacheImage(image, element, onError: (_, _) {}),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
    scenarios: [
      _scenario('collecting, with cover', _card(cover: fixtureThumb(1))),
      _scenario(
        'ready, with cover',
        _card(
          cover: fixtureThumb(2),
          status: TtStatusKind.ready,
          label: 'Ready to edit',
          name: 'Summer weekend',
        ),
      ),
      _scenario(
        'published, with cover',
        _card(
          cover: fixtureThumb(3),
          status: TtStatusKind.published,
          label: 'Published',
          name: 'Autumn recipes',
        ),
      ),
      _scenario('no clips', _card(name: 'New reel', meta: 'No clips yet')),
      _scenario(
        '2 missing',
        _card(
          cover: fixtureThumb(4),
          notes: const [
            TtReelCardNote(TtReelCardNoteKind.missing, '2 missing'),
          ],
        ),
      ),
      _scenario(
        'editing, 2 missing and 3 references',
        _card(
          cover: fixtureThumb(5),
          notes: const [
            TtReelCardNote(TtReelCardNoteKind.editing, 'Editing in VN'),
            TtReelCardNote(TtReelCardNoteKind.missing, '2 missing'),
            TtReelCardNote(TtReelCardNoteKind.references, '3 references'),
          ],
        ),
      ),
      _scenario(
        'a long name',
        _card(
          cover: fixtureThumb(6),
          name: 'Saturday morning market walk with the whole family',
          meta: '1234 clips · 12:34:56',
          status: TtStatusKind.ready,
          label: 'Ready to edit',
          notes: const [
            TtReelCardNote(TtReelCardNoteKind.missing, '12 missing'),
          ],
        ),
      ),
      _scenario('a cover still decoding', _card(cover: const _Pending())),
      _scenario('a cover that fails', _card(cover: brokenImage)),
    ],
  );
}

/// A scenario that is [_tile] wide, and [_wide] at large text (Home then has
/// one column).
TtScenario _scenario(String name, Widget child) =>
    TtScenario(name, child, largeWidth: _wide);

Widget _card({
  ImageProvider? cover,
  String name = 'Lisbon trip',
  String meta = '12 clips · 1:03',
  TtStatusKind status = TtStatusKind.collecting,
  String label = 'Collecting',
  List<TtReelCardNote> notes = const [],
}) => TtReelCard(
  name: name,
  semanticLabel: '$name. $label. $meta',
  status: status,
  statusLabel: label,
  meta: meta,
  cover: cover,
  notes: notes,
  onTap: () {},
);

/// A picture that never arrives.
@immutable
class _Pending extends ImageProvider<_Pending> {
  const new();

  @override
  Future<_Pending> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
