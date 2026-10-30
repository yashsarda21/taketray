import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longName = 'Saturday morning market walk with the whole family';

Widget _card({
  String name = 'Lisbon trip',
  ImageProvider? cover,
  bool withCover = true,
  TtStatusKind status = TtStatusKind.collecting,
  String meta = '12 clips · 1:03',
  String? missingText,
  String? vnLabel,
  int referenceCount = 0,
  VoidCallback? onTap,
  VoidCallback? onReferencesTap,
  double width = 158,
}) => Center(
  child: SizedBox(
    width: width,
    child: TtReelCard(
      name: name,
      semanticLabel: '$name. Collecting. 12 clips',
      status: status,
      statusLabel: 'Collecting',
      meta: meta,
      emptyLabel: 'No clips yet',
      cover: withCover ? (cover ?? fixtureThumb(1)) : null,
      missingText: missingText,
      vnLabel: vnLabel,
      referenceCount: referenceCount,
      referencesSemanticLabel: '$referenceCount references in $name',
      onTap: onTap ?? () {},
      onReferencesTap: onReferencesTap ?? () {},
    ),
  ),
);

Future<void> _decode(WidgetTester tester, ImageProvider image) async {
  await tester.runAsync(
    () => precacheImage(
      image,
      tester.element(find.byType(TtReelCard)),
      onError: (_, _) {},
    ),
  );
  await tester.pumpAndSettle();
}

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  group('TtReelCard', () {
    testWidgets('is a 4:5 card with the name, meta and status', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(tester.getSize(find.byType(TtReelCard)), const Size(158, 197.5));
      expect(find.text('Lisbon trip'), findsOneWidget);
      expect(find.text('12 clips · 1:03'), findsOneWidget);
      expect(find.text('Collecting'), findsOneWidget);
    });

    testWidgets('shows the status in each kind', (tester) async {
      for (final kind in TtStatusKind.values) {
        await tester.pumpWidget(ttTestApp(_card(status: kind)));
        expect(
          tester.widget<TtStatusPill>(find.byType(TtStatusPill)).kind,
          kind,
        );
        expect(
          tester.widget<TtStatusPill>(find.byType(TtStatusPill)).onMedia,
          isTrue,
        );
      }
    });

    testWidgets('with a cover the text is white on the picture', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      final tt = tester.element(find.byType(TtReelCard)).tt;
      expect(find.text('No clips yet'), findsNothing);
      expect(_style(tester, 'Lisbon trip').color, tt.colors.onMedia);
      expect(_style(tester, '12 clips · 1:03').color, tt.colors.onMediaVariant);
      expect(_style(tester, 'Lisbon trip').fontSize, 15);
      expect(_style(tester, 'Lisbon trip').fontWeight, FontWeight.w700);
    });

    testWidgets('without a cover it shows the empty art in surface colours', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(withCover: false)));
      final tt = tester.element(find.byType(TtReelCard)).tt;
      final scheme = tester.element(find.byType(TtReelCard)).scheme;
      expect(find.text('No clips yet'), findsOneWidget);
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(_style(tester, 'Lisbon trip').color, scheme.onSurface);
      expect(_style(tester, '12 clips · 1:03').color, scheme.onSurfaceVariant);
      expect(tt.colors.onMedia, isNot(scheme.onSurface));
    });

    testWidgets('a cover that fails to load falls back to the empty art', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(cover: brokenImage)));
      await _decode(tester, brokenImage);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No clips yet'), findsOneWidget);
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
      final scheme = tester.element(find.byType(TtReelCard)).scheme;
      expect(_style(tester, 'Lisbon trip').color, scheme.onSurface);
    });

    testWidgets('a good cover is not replaced by the empty art', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('missing clips show the count with an error icon', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(missingText: '2 missing')));
      final tt = tester.element(find.byType(TtReelCard)).tt;
      expect(find.text('2 missing'), findsOneWidget);
      expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
      expect(_style(tester, '2 missing').color, tt.colors.missingOnMedia);
      expect(_style(tester, '2 missing').fontWeight, FontWeight.w600);
    });

    testWidgets('no missing text, no error icon', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.byIcon(Symbols.error_rounded), findsNothing);
    });

    testWidgets('the VN mark shows when vnLabel is given', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(vnLabel: 'Editing in VN')));
      expect(find.text('Editing in VN'), findsOneWidget);
      expect(find.byIcon(Symbols.folder_copy_rounded), findsOneWidget);
      // 40 dp below the card's top, 8 dp in.
      final card = tester.getTopLeft(find.byType(TtReelCard));
      final vn = tester.getTopLeft(find.byType(TtGlassPill));
      expect(vn - card, const Offset(8, 40));
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.byType(TtGlassPill), findsNothing);
    });

    testWidgets('the name clamps to 2 lines and the meta to 1', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(name: _longName, meta: '1234 clips · 12:34:56 long')),
      );
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
      final meta = tester.widget<Text>(find.textContaining('1234 clips'));
      expect(meta.maxLines, 1);
    });

    for (final brightness in Brightness.values) {
      testWidgets('long text at 2x does not overflow (${brightness.name})', (
        tester,
      ) async {
        for (final withCover in [true, false]) {
          await tester.pumpWidget(
            ttTestApp(
              _card(
                name: _longName,
                withCover: withCover,
                meta: '1234 clips · 12:34:56',
                missingText: '12 missing',
                vnLabel: 'Editing in VN',
                referenceCount: 3,
              ),
              brightness: brightness,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'at 2x text the pills stay clear of the name and the badge of the '
        'meta (${brightness.name})',
        (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              _card(
                name: _longName,
                meta: '1234 clips · 12:34:56',
                missingText: '12 missing',
                vnLabel: 'Editing in VN',
                referenceCount: 12,
              ),
              brightness: brightness,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final lowestPill = [
            tester.getRect(find.byType(TtStatusPill)),
            tester.getRect(find.byType(TtGlassPill)),
          ].map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
          final name = tester.getRect(find.text(_longName));
          expect(name.top, greaterThanOrEqualTo(lowestPill));

          // The visible badge: its icon and count, padded to the pill.
          final badge = tester
              .getRect(find.byIcon(Symbols.link_rounded))
              .expandToInclude(tester.getRect(find.text('12')))
              .inflate(6);
          final meta = tester.getRect(find.textContaining('1234 clips'));
          expect(badge.overlaps(meta), isFalse);
        },
      );
    }

    for (final scale in [1.0, 1.5, 2.0]) {
      for (final vn in [null, 'Editing in VN']) {
        testWidgets('on empty art the status pill clears the film icon '
            '(${scale}x, ${vn == null ? 'no VN' : 'VN'})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              _card(
                withCover: false,
                name: _longName,
                meta: '1234 clips · 12:34:56',
                vnLabel: vn,
              ),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final lowestPill = [
            tester.getRect(find.byType(TtStatusPill)),
            if (vn != null) tester.getRect(find.byType(TtGlassPill)),
          ].map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
          final icon = tester.getRect(find.byIcon(Symbols.movie_rounded));
          expect(icon.top, greaterThanOrEqualTo(lowestPill));
        });
      }
    }

    testWidgets('a tap on the card calls onTap', (tester) async {
      var taps = 0;
      var refs = 0;
      await tester.pumpWidget(
        ttTestApp(
          _card(
            referenceCount: 3,
            onTap: () => taps++,
            onReferencesTap: () => refs++,
          ),
        ),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(TtReelCard)) + const Offset(40, 60),
      );
      expect(taps, 1);
      expect(refs, 0);
    });

    group('references badge', () {
      test('references without a semantic label is a programming error', () {
        TtReelCard build({required int count, String? label}) => TtReelCard(
          name: 'Lisbon trip',
          semanticLabel: 'Lisbon trip',
          status: TtStatusKind.collecting,
          statusLabel: 'Collecting',
          meta: '12 clips',
          emptyLabel: 'No clips yet',
          referenceCount: count,
          referencesSemanticLabel: label,
        );
        expect(() => build(count: 3), throwsAssertionError);
        expect(
          () => build(count: 3, label: 'Three references'),
          returnsNormally,
        );
        expect(() => build(count: 0), returnsNormally);
      });

      testWidgets('is not built when referenceCount is 0', (tester) async {
        await tester.pumpWidget(ttTestApp(_card()));
        expect(find.byIcon(Symbols.link_rounded), findsNothing);
        expect(find.bySemanticsLabel(RegExp('references in')), findsNothing);
      });

      testWidgets('shows the link icon and the count', (tester) async {
        await tester.pumpWidget(ttTestApp(_card(referenceCount: 3)));
        expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(_style(tester, '3').fontWeight, FontWeight.w700);
      });

      testWidgets('a tap calls onReferencesTap and not onTap', (tester) async {
        var taps = 0;
        var refs = 0;
        await tester.pumpWidget(
          ttTestApp(
            _card(
              referenceCount: 3,
              onTap: () => taps++,
              onReferencesTap: () => refs++,
            ),
          ),
        );
        await tester.tapAt(tester.getCenter(find.byIcon(Symbols.link_rounded)));
        expect(refs, 1);
        expect(taps, 0);
      });

      testWidgets('a tap in its 48 dp margin still counts', (tester) async {
        var taps = 0;
        var refs = 0;
        await tester.pumpWidget(
          ttTestApp(
            _card(
              referenceCount: 3,
              onTap: () => taps++,
              onReferencesTap: () => refs++,
            ),
          ),
        );
        final link = tester.getCenter(find.byIcon(Symbols.link_rounded));
        // The pill is 26 dp high; 11 dp above it is still the target.
        await tester.tapAt(link - const Offset(0, 17));
        expect(refs, 1);
        expect(taps, 0);
      });

      testWidgets('has its own semantics node, 48 dp or larger', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(ttTestApp(_card(referenceCount: 3)));
        final badge = tester.getSemantics(
          find.bySemanticsLabel('3 references in Lisbon trip'),
        );
        expect(badge.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(badge.rect.width, greaterThanOrEqualTo(48));
        expect(badge.rect.height, greaterThanOrEqualTo(48));
        final card = tester.getSemantics(
          find.bySemanticsLabel('Lisbon trip. Collecting. 12 clips'),
        );
        expect(card.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(card.id, isNot(badge.id));
        handle.dispose();
      });

      testWidgets('the caption leaves room for it', (tester) async {
        await tester.pumpWidget(ttTestApp(_card(referenceCount: 3)));
        final card = tester.getRect(find.byType(TtReelCard));
        final name = tester.getRect(find.text('Lisbon trip'));
        expect(name.left - card.left, 12);
        final nameBox = tester
            .renderObject<RenderBox>(find.text('Lisbon trip'))
            .size
            .width;
        expect(nameBox, lessThanOrEqualTo(158 - 12 - 50));
      });
    });

    testWidgets('semantics: one button named by semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_card(onTap: () => taps++)));
      final node = tester.getSemantics(find.byType(TtReelCard));
      final data = node.getSemanticsData();
      expect(data.label, 'Lisbon trip. Collecting. 12 clips');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'passes the accessibility guidelines with a cover, missing clips and '
        'each status (${brightness.name})',
        (tester) async {
          for (final withCover in [true, false]) {
            for (final status in TtStatusKind.values) {
              await tester.pumpWidget(
                ttTestApp(
                  _card(
                    withCover: withCover,
                    status: status,
                    referenceCount: 2,
                    missingText: '2 missing',
                  ),
                  brightness: brightness,
                ),
              );
              if (withCover) await _decode(tester, fixtureThumb(1));
              await expectTtAccessible(tester);
            }
          }
        },
      );
    }

    testWidgets('the card is announced with the status and missing clips, '
        'and the badge is its own button', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ttTestApp(
            _card(
              status: TtStatusKind.published,
              missingText: '2 missing',
              referenceCount: 3,
              onTap: () {},
              onReferencesTap: () {},
            ),
          ),
        );
        await _decode(tester, fixtureThumb(1));
        final card = tester.getSemantics(
          find.bySemanticsLabel('Lisbon trip. Collecting. 12 clips'),
        );
        expect(card.getSemanticsData().flagsCollection.isButton, isTrue);
        // The pill and the "missing" text are part of the card's one label,
        // not separate nodes.
        expect(find.bySemanticsLabel('Collecting'), findsNothing);
        expect(find.bySemanticsLabel('2 missing'), findsNothing);
        expect(
          find.bySemanticsLabel('3 references in Lisbon trip'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            _card(
              withCover: false,
              referenceCount: 3,
              missingText: '2 missing',
              vnLabel: 'Editing in VN',
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
