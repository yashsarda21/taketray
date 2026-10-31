import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

void main() {
  group('TtTextStyles.weight', () {
    for (final weight in FontWeight.values) {
      test('weight ${weight.value} sets fontWeight and the wght axis', () {
        final style = TtTextStyles.weight(weight);
        expect(style.fontWeight, weight);
        expect(style.fontVariations, [
          ui.FontVariation('wght', weight.value.toDouble()),
        ]);
      });
    }

    test('merging it over a style changes both and keeps the rest', () {
      const base = TextStyle(fontSize: 13, letterSpacing: 0.5);
      final style = base.merge(TtTextStyles.weight(FontWeight.w700));
      expect(style.fontSize, 13);
      expect(style.letterSpacing, 0.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontVariations, [const ui.FontVariation('wght', 700)]);
    });
  });

  testWidgets('the TakeTray display styles keep fontWeight and wght equal', (
    tester,
  ) async {
    final text = TtTextStyles.fromScheme(TakeTrayTheme.light().colorScheme);
    final styles = {
      'pageTitle': text.pageTitle,
      'detailTitle': text.detailTitle,
      'screenTitle': text.screenTitle,
      'dialogTitle': text.dialogTitle,
      'shootTitle': text.shootTitle,
      'cardTitle': text.cardTitle,
      'groupLabel': text.groupLabel,
      'navLabel': text.navLabel,
    };
    for (final MapEntry(:key, :value) in styles.entries) {
      expect(value.fontVariations, [
        ui.FontVariation('wght', value.fontWeight!.value.toDouble()),
      ], reason: key);
    }
  });

  test('no component sets the wght axis by hand', () {
    // Only the helper and the generated type scale may build a
    // FontVariation; everything else goes through TtTextStyles.weight.
    final offenders = <String>[];
    for (final file in Directory('lib/src').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('tokens.g.dart') ||
          file.path.endsWith('tt_text_styles.dart')) {
        continue;
      }
      if (file.readAsStringSync().contains(RegExp(r'FontVariation\('))) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
