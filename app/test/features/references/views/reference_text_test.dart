import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/references/view_models/source_icons.dart';
import 'package:taketray/features/references/views/reference_source_icon.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';

// A 1 x 1 transparent PNG.
final Uint8List _png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
  68, 174, 66, 96, 130,
]);

ReelReference _ref(String url, {String? label}) => ReelReference(
  id: 1,
  reelId: 1,
  url: url,
  source: ReferenceSource.link,
  createdAt: DateTime.utc(2026, 11, 19),
  label: label,
);

void main() {
  late AppLocalizations l10n;

  setUp(() => l10n = lookupAppLocalizations(const Locale('en')));

  group('referenceKindText', () {
    for (final (url, text) in [
      ('https://www.instagram.com/p/A1/', 'Instagram'),
      ('https://www.instagram.com/someone/', 'Instagram profile'),
      ('https://www.youtube.com/shorts/abc', 'YouTube Short'),
      ('https://youtu.be/abc', 'YouTube video'),
      ('https://www.youtube.com/watch?v=abc', 'YouTube video'),
      ('https://www.tiktok.com/@a/video/1', 'TikTok video'),
      ('https://example.com/a', 'example.com'),
      ('https://www.example.com/a', 'example.com'),
      ('https://m.example.com/a', 'example.com'),
      ('https://blog.example.co.uk/a', 'blog.example.co.uk'),
      // A percent-encoded host is shown decoded (M32).
      ('https://caf%C3%A9.fr/a', 'café.fr'),
      ('https://www.caf%C3%A9.fr/a', 'café.fr'),
      ('https://%C3.com/a', '%C3.com'),
    ]) {
      test('$url is "$text"', () {
        expect(referenceKindText(l10n, Uri.parse(url)), text);
      });
    }
  });

  group('referenceCardText', () {
    test('with a label: the label, and the kind and the short link', () {
      final text = referenceCardText(
        l10n,
        _ref('https://www.instagram.com/p/A1/', label: 'Fast cuts'),
      );
      expect(text.title, 'Fast cuts');
      expect(text.subtitle, 'Instagram · instagram.com/p/A1');
    });

    test('without a label: the short link, and the kind alone', () {
      final text = referenceCardText(
        l10n,
        _ref('https://www.instagram.com/p/A1/'),
      );
      expect(text.title, 'instagram.com/p/A1');
      expect(text.subtitle, 'Instagram');
    });

    test('a plain link says the host in the kind', () {
      final text = referenceCardText(
        l10n,
        _ref('https://www.example.com/a/b?x=1', label: 'Look'),
      );
      expect(text.title, 'Look');
      expect(text.subtitle, 'example.com · example.com/a/b');
    });

    test('a percent-encoded host is shown decoded, the url is unchanged', () {
      final text = referenceCardText(
        l10n,
        _ref('https://caf%C3%A9.fr/menu', label: 'Look'),
      );
      expect(text.title, 'Look');
      expect(text.subtitle, 'café.fr · café.fr/menu');
      expect(
        referenceCardText(l10n, _ref('https://caf%C3%A9.fr/menu')).title,
        'café.fr/menu',
      );
    });
  });

  group('referenceSourceIcon', () {
    Future<void> pump(
      WidgetTester tester,
      ReferenceSource source, {
      Map<ReferenceSource, Uint8List> icons = const {},
      double size = 40,
    }) => pumpScreen(
      tester,
      Scaffold(
        body: Center(
          child: Builder(
            builder: (context) =>
                referenceSourceIcon(context, source, size: size),
          ),
        ),
      ),
      overrides: [sourceIconsProvider.overrideWith((ref) async => icons)],
    );

    testWidgets('shows the phone icon when it has one', (tester) async {
      await pump(
        tester,
        ReferenceSource.instagram,
        icons: {ReferenceSource.instagram: _png},
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as MemoryImage).bytes, _png);
      expect(find.byIcon(Symbols.link_rounded), findsNothing);
      expect(tester.getSize(find.byType(Image)).width, closeTo(40, 0.001));
    });

    testWidgets('shows the link symbol for a source with no icon', (
      tester,
    ) async {
      await pump(
        tester,
        ReferenceSource.youtube,
        icons: {ReferenceSource.instagram: _png},
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
    });

    testWidgets('shows the link symbol for a plain link', (tester) async {
      await pump(
        tester,
        ReferenceSource.link,
        icons: {ReferenceSource.instagram: _png},
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
    });

    testWidgets('shows the link symbol while the icons load', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                referenceSourceIcon(context, ReferenceSource.instagram),
          ),
        ),
        overrides: [
          sourceIconsProvider.overrideWith((ref) => Future.any(const [])),
        ],
        settle: false,
      );
      await tester.pump();
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
    });

    testWidgets('shows the link symbol when asking the phone failed', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                referenceSourceIcon(context, ReferenceSource.instagram),
          ),
        ),
        overrides: [
          sourceIconsProvider.overrideWith(
            (ref) async => throw StateError('x'),
          ),
        ],
      );
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
    });

    testWidgets('has the size asked for, in either look', (tester) async {
      Finder icon() => find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(Consumer),
      );
      await pump(tester, ReferenceSource.link, size: 18);
      expect(tester.getSize(icon()), const Size(18, 18));
      await pump(
        tester,
        ReferenceSource.instagram,
        icons: {ReferenceSource.instagram: _png},
        size: 18,
      );
      expect(tester.getSize(icon()), const Size(18, 18));
    });

    testWidgets('is hidden from a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, ReferenceSource.link);
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });
  });
}
