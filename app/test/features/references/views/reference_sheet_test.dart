import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/references/views/reference_sheet.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The sheet's goldens are **macOS only, and not on CI** (D-61, D-97): make or
/// update them with `tool/flutter test --update-goldens
/// test/features/references/views/reference_sheet_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _noLink = "There's no link on your clipboard.";
const _notALink =
    "That isn't a link. In Instagram: Share › Copy link, then paste it here.";
const _failed = "Couldn't save the reference.";

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ReferencesRepository refs;
  late Reel goa;
  var clipboardReads = 0;

  setUp(() {
    h = VmHarness();
    reels = ReelsRepository(h.media.db, h.media.clock);
    refs = ReferencesRepository(h.media.db, h.media.clock);
    clipboardReads = 0;
  });

  /// Answers the platform's clipboard with [answer] and counts the reads.
  void clipboard(WidgetTester tester, Object? Function() answer) {
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          clipboardReads++;
          return answer();
        }
        return null;
      });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  /// A page with a button that opens the sheet the way a screen does, over
  /// reel [goa] (which the test has made).
  Future<void> pumpHostOver(
    WidgetTester tester, {
    ReelReference? editing,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TtButton(
          label: 'open',
          onPressed: () =>
              showReferenceSheet(context, reelId: goa.id, editing: editing),
        ),
      ),
    ),
    overrides: h.appOverrides,
    textScale: textScale,
    brightness: brightness,
  );

  /// Makes reel "Goa", then [pumpHostOver] it.
  Future<void> pumpHost(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    goa = await real(tester, () => reels.create('Goa'));
    await pumpHostOver(tester, textScale: textScale, brightness: brightness);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await settleApp(tester);
  }

  Future<ReelReference> saved(
    WidgetTester tester,
    String url, {
    String? label,
  }) async {
    final result = await real(
      tester,
      () => refs.add(goa.id, url, label: label),
    );
    return (result as ReferenceAdded).reference;
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TtTextField && w.label == label,
    description: 'the "$label" field',
  );

  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextField));

  String textIn(WidgetTester tester, String label) =>
      tester.widget<TextField>(input(label)).controller!.text;

  bool focused(WidgetTester tester, String label) => tester
      .widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(input(label), text);
    await tester.pump();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  Future<List<ReelReference>> stored(WidgetTester tester) =>
      real(tester, () => refs.watchForReel(goa.id).first);

  group('the Add sheet', () {
    testApp('has the copy, a counter and an empty link field', (tester) async {
      await pumpHost(tester);
      await open(tester);

      expect(find.text('Add reference'), findsOneWidget);
      expect(find.text('to Goa'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('Instagram, YouTube or any other link'), findsOneWidget);
      expect(find.text('https://www.instagram.com/reel/…'), findsOneWidget);
      expect(find.text('Label (optional)'), findsOneWidget);
      expect(find.text('Fast cuts, food close-ups'), findsOneWidget);
      expect(find.text('0/60'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // The link field takes the focus at once, and Add never asks the phone
      // for an icon.
      expect(focused(tester, 'Link'), isTrue);
      expect(h.editors.calls, isEmpty);
    });

    testApp('nothing touches the clipboard until Paste', (tester) async {
      clipboard(tester, () => {'text': 'https://x.com/a'});
      await pumpHost(tester);
      await open(tester);
      expect(clipboardReads, 0);

      await type(tester, 'Link', 'x.com/b');
      await type(tester, 'Label (optional)', 'Mine');
      await tapAndSettle(tester, find.text('Paste'));
      expect(clipboardReads, 1);
    });

    testApp('Paste with a caption fills the link and moves to Label', (
      tester,
    ) async {
      clipboard(
        tester,
        () => {'text': 'Look https://instagram.com/reel/A1 wow'},
      );
      await pumpHost(tester);
      await open(tester);
      await tapAndSettle(tester, find.text('Paste'));

      expect(textIn(tester, 'Link'), 'https://instagram.com/reel/A1');
      expect(focused(tester, 'Label (optional)'), isTrue);
      expect(find.text(_noLink), findsNothing);
    });

    testApp('Paste takes the first of two links', (tester) async {
      clipboard(
        tester,
        () => {'text': 'a https://youtu.be/AAA b https://youtu.be/BBB'},
      );
      await pumpHost(tester);
      await open(tester);
      await tapAndSettle(tester, find.text('Paste'));
      expect(textIn(tester, 'Link'), 'https://youtu.be/AAA');
    });

    testApp('Paste takes a link out of a very long text', (tester) async {
      clipboard(tester, () => {'text': '${'word ' * 20000}https://x.com/end.'});
      await pumpHost(tester);
      await open(tester);
      await tapAndSettle(tester, find.text('Paste'));
      expect(textIn(tester, 'Link'), 'https://x.com/end');
    });

    testApp('Paste clears an error and replaces what was typed', (
      tester,
    ) async {
      clipboard(tester, () => {'text': 'https://x.com/a'});
      await pumpHost(tester);
      await open(tester);
      await tapAndSettle(tester, find.text('Save'));
      expect(find.text(_notALink), findsOneWidget);

      await tapAndSettle(tester, find.text('Paste'));
      expect(find.text(_notALink), findsNothing);
      expect(textIn(tester, 'Link'), 'https://x.com/a');
    });

    for (final (name, answer) in <(String, Object? Function())>[
      ('an empty clipboard', () => {'text': ''}),
      ('a blank clipboard', () => {'text': '  \n '}),
      ('no clipboard data (an image)', () => null),
      ('a caption with no link', () => {'text': 'Nice shots, no link here'}),
      ('a bare address (no scheme)', () => {'text': 'instagram.com/reel/A1'}),
      (
        'a failing clipboard',
        () => throw PlatformException(code: 'clipboard-error'),
      ),
    ]) {
      testApp('Paste with $name says there is no link', (tester) async {
        clipboard(tester, answer);
        await pumpHost(tester);
        await open(tester);
        await type(tester, 'Link', 'typed.com/a');
        await tapAndSettle(tester, find.text('Paste'));

        expect(find.text(_noLink), findsOneWidget);
        expect(textIn(tester, 'Link'), 'typed.com/a');
        expect(await stored(tester), isEmpty);
        expect(find.byType(TtSheet), findsOneWidget);
        // Typing takes the message away.
        await type(tester, 'Link', 'typed.com/ab');
        expect(find.text(_noLink), findsNothing);
      });
    }

    for (final text in ['', '   ', 'hello world', 'hello.', '.com']) {
      testApp('Save with "$text" says it is not a link', (tester) async {
        await pumpHost(tester);
        await open(tester);
        await type(tester, 'Link', text);
        await tapAndSettle(tester, find.text('Save'));

        expect(find.text(_notALink), findsOneWidget);
        expect(find.byType(TtSheet), findsOneWidget);
        expect(await stored(tester), isEmpty);
        // The text stays, and typing takes the message away.
        expect(textIn(tester, 'Link'), text);
        await type(tester, 'Link', '$text.');
        expect(find.text(_notALink), findsNothing);
      });
    }

    testApp('Save closes the sheet, shows the snack, and Undo removes it', (
      tester,
    ) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'www.instagram.com/reel/A1/?igsh=z');
      await type(tester, 'Label (optional)', '  Fast cuts ');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Reference saved'), findsOneWidget);
      final rows = await stored(tester);
      expect(rows.single.url, 'https://www.instagram.com/p/A1/');
      expect(rows.single.label, 'Fast cuts');

      await tapAndSettle(tester, find.text('Undo'));
      expect(await stored(tester), isEmpty);
      expect(find.text("Couldn't undo. Try again."), findsNothing);
    });

    testApp('Undo after the reference is already gone does not fail', (
      tester,
    ) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'https://x.com/a');
      await tapAndSettle(tester, find.text('Save'));
      final row = (await stored(tester)).single;
      await real(tester, () => refs.delete(row.id));

      await tapAndSettle(tester, find.text('Undo'));
      expect(find.text("Couldn't undo. Try again."), findsNothing);
      expect(await stored(tester), isEmpty);
    });

    testApp('Enter in Label saves', (tester) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'https://x.com/a');
      await tester.tap(input('Label (optional)'));
      await tester.pump();
      await type(tester, 'Label (optional)', 'Slow pans');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Reference saved'), findsOneWidget);
      expect((await stored(tester)).single.label, 'Slow pans');
    });

    testApp('the label stops at 60 characters (emoji count once)', (
      tester,
    ) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Label (optional)', '🎬' * 65);
      expect(find.text('60/60'), findsOneWidget);
    });

    testApp('a link already saved says where, and keeps the sheet', (
      tester,
    ) async {
      goa = await real(tester, () => reels.create('Goa'));
      await saved(tester, 'https://www.instagram.com/p/A1/', label: 'First');
      await pumpHostOver(tester);
      await open(tester);
      await type(tester, 'Link', 'instagram.com/reel/A1?igsh=other');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text('Already saved in Goa'), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text('Reference saved'), findsNothing);
      expect((await stored(tester)).single.label, 'First');
      // Typing takes it away.
      await type(tester, 'Link', 'instagram.com/reel/A2');
      expect(find.text('Already saved in Goa'), findsNothing);
    });

    testApp('Save on a deleted reel says it could not, and saves nothing', (
      tester,
    ) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'https://x.com/a');
      await real(tester, () => reels.delete(goa.id));
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text(_failed), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text('Reference saved'), findsNothing);
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
      // The text is kept, and the next edit takes the failure away.
      expect(textIn(tester, 'Link'), 'https://x.com/a');
      await type(tester, 'Link', 'https://x.com/ab');
      expect(find.text(_failed), findsNothing);
    });

    testApp('a double tap on Save saves once', (tester) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'https://x.com/a');
      final button = find.text('Save');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);

      expect(await stored(tester), hasLength(1));
      expect(find.text('Already saved in Goa'), findsNothing);
      expect(find.text('Reference saved'), findsOneWidget);
    });

    testApp('Cancel closes the sheet and saves nothing', (tester) async {
      await pumpHost(tester);
      await open(tester);
      await type(tester, 'Link', 'https://x.com/a');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TtSheet), findsNothing);
      expect(await stored(tester), isEmpty);
      expect(find.text('Reference saved'), findsNothing);
    });

    testApp('meets the accessibility guidelines, with an error', (
      tester,
    ) async {
      await pumpHost(tester);
      await open(tester);
      await tapAndSettle(tester, find.text('Save'));
      await expectTtAccessible(tester);
    });
  });

  group('the Edit label sheet', () {
    late ReelReference ref;

    Future<void> openEdit(
      WidgetTester tester, {
      String url = 'https://www.instagram.com/reel/A1/',
      String? label = 'Fast cuts',
      double textScale = 1,
    }) async {
      h.editors.allowOnly({'apps'});
      goa = await real(tester, () => reels.create('Goa'));
      ref = await saved(tester, url, label: label);
      await pumpHostOver(tester, editing: ref, textScale: textScale);
      await open(tester);
    }

    testApp('shows the source row, the label and no link field', (
      tester,
    ) async {
      await openEdit(tester);

      expect(find.text('Edit label'), findsOneWidget);
      expect(find.text('Add reference'), findsNothing);
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('instagram.com/p/A1'), findsOneWidget);
      expect(find.text('Link'), findsNothing);
      expect(find.text('Paste'), findsNothing);
      expect(textIn(tester, 'Label (optional)'), 'Fast cuts');
      expect(focused(tester, 'Label (optional)'), isTrue);
      expect(find.text('Save'), findsOneWidget);
    });

    for (final (url, kind, short) in [
      (
        'https://www.instagram.com/someone/',
        'Instagram profile',
        'instagram.com/someone',
      ),
      (
        'https://www.youtube.com/shorts/abc',
        'YouTube Short',
        'youtube.com/shorts/abc',
      ),
      (
        'https://www.youtube.com/watch?v=abc',
        'YouTube video',
        'youtube.com/watch',
      ),
      (
        'https://www.tiktok.com/@a/video/1',
        'TikTok video',
        'tiktok.com/@a/video/1',
      ),
      ('https://example.com/page?x=1', 'example.com', 'example.com/page'),
    ]) {
      testApp('the source row of $url says "$kind"', (tester) async {
        await openEdit(tester, url: url);
        expect(find.text(kind), findsOneWidget);
        expect(find.text(short), findsOneWidget);
      });
    }

    testApp('Save sets the label, closes and shows "Label saved"', (
      tester,
    ) async {
      await openEdit(tester);
      await type(tester, 'Label (optional)', '  Slow pans ');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Label saved'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect((await stored(tester)).single.label, 'Slow pans');
    });

    testApp('a blank label clears it', (tester) async {
      await openEdit(tester);
      await type(tester, 'Label (optional)', '   ');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text('Label saved'), findsOneWidget);
      expect((await stored(tester)).single.label, isNull);
    });

    testApp('Enter saves', (tester) async {
      await openEdit(tester, label: null);
      await type(tester, 'Label (optional)', 'Hello');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.byType(TtSheet), findsNothing);
      expect((await stored(tester)).single.label, 'Hello');
    });

    testApp('Save on a reference that is gone says it could not', (
      tester,
    ) async {
      await openEdit(tester);
      await real(tester, () => refs.delete(ref.id));
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text(_failed), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text('Label saved'), findsNothing);
      await type(tester, 'Label (optional)', 'More');
      expect(find.text(_failed), findsNothing);
    });

    testApp('a double tap on Save writes once', (tester) async {
      await openEdit(tester);
      await type(tester, 'Label (optional)', 'New');
      final button = find.text('Save');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);

      expect((await stored(tester)).single.label, 'New');
      expect(find.text('Label saved'), findsOneWidget);
      expect(find.text(_failed), findsNothing);
    });

    testApp('meets the accessibility guidelines', (tester) async {
      await openEdit(tester);
      await expectTtAccessible(tester);
    });

    testApp('at 200 % nothing overflows', (tester) async {
      await openEdit(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Instagram'), findsOneWidget);
    });
  });

  group('goldens', () {
    Future<Uint8List> icon() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 48, 48),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(48, 48), [
            const Color(0xFFF58529),
            const Color(0xFFDD2A7B),
          ]),
      );
      final image = await recorder.endRecording().toImage(48, 48);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    }

    Future<void> showPictures(WidgetTester tester) async {
      bool pending() => find
          .byType(Image)
          .evaluate()
          .map((e) => e.renderObject)
          .whereType<RenderImage>()
          .any((r) => r.image == null);
      for (var i = 0; i < 40 && (i < 2 || pending()); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await settleApp(tester);
    }

    Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/$name.png'),
    );

    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, '1x'),
      (2.0, Brightness.light, '2x'),
      (1.0, Brightness.dark, 'dark_1x'),
    ]) {
      testApp('empty ($suffix)', (tester) async {
        await pumpHost(tester, textScale: scale, brightness: brightness);
        await open(tester);
        await shot(tester, 'reference_sheet_empty_$suffix');
      }, skip: !_goldens);

      testApp('with an error ($suffix)', (tester) async {
        await pumpHost(tester, textScale: scale, brightness: brightness);
        await open(tester);
        await type(tester, 'Link', 'hello');
        await tapAndSettle(tester, find.text('Save'));
        await shot(tester, 'reference_sheet_error_$suffix');
      }, skip: !_goldens);

      testApp('edit ($suffix)', (tester) async {
        final png = await real(tester, icon);
        h.editors
          ..installed = {'com.instagram.android': true}
          ..icons = {'com.instagram.android': png}
          ..allowOnly({'apps'});
        goa = await real(tester, () => reels.create('Goa'));
        final ref = await saved(
          tester,
          'https://www.instagram.com/reel/A1/',
          label: 'Fast cuts, food close-ups',
        );
        await pumpHostOver(
          tester,
          editing: ref,
          textScale: scale,
          brightness: brightness,
        );
        await open(tester);
        await showPictures(tester);
        await shot(tester, 'reference_sheet_edit_$suffix');
      }, skip: !_goldens);
    }
  });
}
