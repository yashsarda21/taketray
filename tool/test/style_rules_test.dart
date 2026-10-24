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
  });
}
