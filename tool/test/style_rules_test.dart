import 'package:taketray_tool/src/style_rules.dart';
import 'package:test/test.dart';

void main() {
  List<StyleViolation> check(String src) =>
      findStyleViolations(src, path: 'a.dart');

  group('findStyleViolations', () {
    test('flags raw colours', () {
      final v = check('final c = Color(0xFF000000);');
      expect(v.single.rule, 'raw-color');
      expect(v.single.line, 1);
      expect(v.single.path, 'a.dart');
    });

    test('flags the other raw colour forms', () {
      expect(
        check('final c = Color.fromARGB(1, 2, 3, 4);').single.rule,
        'raw-color',
      );
      expect(
        check('final c = Color.fromRGBO(1, 2, 3, 1);').single.rule,
        'raw-color',
      );
      expect(check('final c = Colors.red;').single.rule, 'raw-color');
    });

    test('flags raw text styles', () {
      expect(
        check('const s = TextStyle(fontSize: 14);').single.rule,
        'raw-text-style',
      );
    });

    test('flags raw insets', () {
      expect(
        check('EdgeInsets.symmetric(horizontal: 16)').single.rule,
        'raw-insets',
      );
      expect(check('EdgeInsets.all(8)').single.rule, 'raw-insets');
      expect(
        check('EdgeInsetsDirectional.only(start: 4.5)').single.rule,
        'raw-insets',
      );
    });

    test('flags raw sizes', () {
      expect(check('SizedBox(height: 8)').single.rule, 'raw-size');
      expect(check('SizedBox(width: 8.0, child: x)').single.rule, 'raw-size');
    });

    test('SizedBox.shrink is clean', () {
      expect(check('SizedBox.shrink()'), isEmpty);
    });

    test('flags raw radii', () {
      expect(check('BorderRadius.circular(12)').single.rule, 'raw-radius');
      expect(check('Radius.circular(12.5)').single.rule, 'raw-radius');
    });

    test('flags raw durations', () {
      expect(check('Duration(milliseconds: 300)').single.rule, 'raw-duration');
      expect(check('Duration(seconds: 1)').single.rule, 'raw-duration');
    });

    test('flags raw directional radii', () {
      expect(
        check('BorderRadiusDirectional.circular(12)').single.rule,
        'raw-radius',
      );
    });

    test('flags a raw SizedBox.square dimension', () {
      expect(check('SizedBox.square(dimension: 24)').single.rule, 'raw-size');
    });

    test('flags raw durations in minutes, hours, microseconds', () {
      expect(check('Duration(minutes: 1)').single.rule, 'raw-duration');
      expect(check('Duration(hours: 2)').single.rule, 'raw-duration');
      expect(check('Duration(microseconds: 5)').single.rule, 'raw-duration');
    });

    test('token-based directional radii and square sizes are clean', () {
      expect(check('BorderRadiusDirectional.circular(radii.m)'), isEmpty);
      expect(check('SizedBox.square(dimension: sizes.icon)'), isEmpty);
    });

    test('reports the right line number and snippet', () {
      final v = check('final a = 1;\n\n  final c = Colors.red;\n');
      expect(v.single.line, 3);
      expect(v.single.snippet, 'final c = Colors.red;');
    });

    test('allows a justified exception on the previous line', () {
      const src =
          '// style-check: allow video surface must be pure black\n'
          'final c = Colors.black;';
      expect(check(src), isEmpty);
    });

    test('allows a justified exception on the same line', () {
      const src = 'final c = Colors.black; // style-check: allow video surface';
      expect(check(src), isEmpty);
    });

    test('an allow comment does not leak to later lines', () {
      const src =
          '// style-check: allow reason\n'
          'final a = Colors.black;\n'
          'final b = Colors.white;';
      expect(check(src).single.line, 3);
    });

    test('token-based code is clean', () {
      const src = 'Padding(padding: EdgeInsets.all(context.tt.spacing.m))';
      expect(check(src), isEmpty);
    });

    test('commented-out code is clean', () {
      expect(check('// Color(0xFF000000)'), isEmpty);
      expect(check('final a = 1; // Colors.red'), isEmpty);
    });

    test('flags calls split across lines', () {
      for (final src in [
        'EdgeInsets.symmetric(\n  horizontal: 16,\n)',
        'EdgeInsets.all(\n  8,\n)',
        'SizedBox(\n  height: 8,\n)',
        'SizedBox(\n  child: Foo(),\n  width: 8,\n)',
        'BorderRadius.circular(\n  12,\n)',
        'Duration(\n  milliseconds: 300,\n)',
      ]) {
        expect(check(src), hasLength(1), reason: src);
        expect(check(src).single.line, 1, reason: src);
      }
    });

    test('token arithmetic with a literal is clean', () {
      for (final src in [
        'EdgeInsets.all(spacing.m * 2)',
        'EdgeInsets.all(context.tt.spacing.m * 2)',
        'EdgeInsets.symmetric(horizontal: tokens.x2, vertical: 2 * tokens.y)',
        'SizedBox(height: spacing.m * 2)',
        'BorderRadius.circular(radii.m * 2)',
        'Duration(milliseconds: motion.base * 2)',
        'SizedBox(child: Foo(height: 8), width: tokens.w)',
      ]) {
        expect(check(src), isEmpty, reason: src);
      }
    });

    test('plain literals are still flagged', () {
      for (final src in [
        'EdgeInsets.only(left: tokens.a, top: 4)',
        'EdgeInsets.all(-8)',
        'SizedBox(width: 8.0)',
        'Duration(seconds: 2)',
      ]) {
        expect(check(src), hasLength(1), reason: src);
      }
    });

    test('an allow marker without a reason does not exempt', () {
      expect(
        check('// style-check: allow\nfinal c = Colors.red;'),
        hasLength(1),
      );
      expect(
        check('final c = Colors.red; // style-check: allow'),
        hasLength(1),
      );
    });

    test('a marker on a line with code exempts only that line', () {
      const src =
          'final a = Colors.red; // style-check: allow reason\n'
          'final b = Colors.red;';
      expect(check(src).single.line, 2);
    });

    test('a // inside a string is not a comment', () {
      final v = check("final u = 'https://x'; final j = Colors.red;");
      expect(v.single.rule, 'raw-color');
    });

    test('an allow comment above a multi-line violation exempts it', () {
      const src =
          '// style-check: allow legacy layout\n'
          'EdgeInsets.symmetric(\n'
          '  horizontal: 16,\n'
          ');';
      expect(check(src), isEmpty);
    });

    test('block comments are ignored', () {
      expect(
        check('/* Colors.red\n EdgeInsets.all(8) */ final a = 1;'),
        isEmpty,
      );
    });
  });
}
