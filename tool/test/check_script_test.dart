import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('tool/check fails when a member is in both member lists', () {
    // A copy of the script in a throwaway repo, with `app` added to the Dart
    // list as well. The check runs before anything slow, so nothing else
    // needs to exist.
    final repo = Directory.systemTemp.createTempSync('check_script_test');
    addTearDown(() => repo.deleteSync(recursive: true));
    Directory('${repo.path}/tool').createSync();
    final script = File('check')
        .readAsStringSync()
        .replaceFirst('DART_MEMBERS=(tool)', 'DART_MEMBERS=(tool app)');
    expect(script, contains('DART_MEMBERS=(tool app)'));
    final copy = File('${repo.path}/tool/check')..writeAsStringSync(script);
    Process.runSync('chmod', ['+x', copy.path]);

    final result = Process.runSync(copy.path, const []);
    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains('member app is listed in both FLUTTER_MEMBERS and DART_MEMBERS'),
    );
  });
}
