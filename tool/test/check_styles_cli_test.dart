import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('check_styles fails when the directory is missing', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/check_styles.dart',
      'this/directory/does/not/exist',
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('not found'));
  });

  test('check_styles passes on a clean directory', () async {
    final dir = Directory.systemTemp.createTempSync('check_styles_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/ok.dart').writeAsStringSync('void main() {}\n');
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/check_styles.dart',
      dir.path,
    ]);
    expect(result.exitCode, 0);
  });
}
