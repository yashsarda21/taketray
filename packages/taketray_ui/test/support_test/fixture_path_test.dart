import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

/// Its own file because fixtureThumb caches bytes by number for the life of
/// the test isolate: the first read here must be the one that hits the disk.
void main() {
  test('fixtureThumb loads from a working directory inside the package', () {
    final original = Directory.current;
    addTearDown(() => Directory.current = original);
    Directory.current = '${original.path}/test';

    final image = fixtureThumb(1);

    expect((image as MemoryImage).bytes, isNotEmpty);
  });
}
