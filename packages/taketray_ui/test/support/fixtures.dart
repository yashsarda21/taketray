import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

final Map<int, Uint8List> _thumbBytes = {};

/// The `taketray_ui` package folder: the nearest folder at or above the
/// working directory whose `pubspec.yaml` names the package, so fixtures load
/// whichever folder of the package `flutter test` runs from.
Directory _packageRoot() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        RegExp(
          r'^name:\s*taketray_ui\s*$',
          multiLine: true,
        ).hasMatch(pubspec.readAsStringSync())) {
      return dir;
    }
    if (dir.parent.path == dir.path) {
      throw StateError(
        'No taketray_ui pubspec.yaml at or above ${Directory.current.path}',
      );
    }
  }
}

/// Sample clip thumbnail [n] (1 to 6) from `test/fixtures/thumbs/` in the
/// package, as a [MemoryImage] (no asset bundle or file image needed in tests).
ImageProvider fixtureThumb(int n) {
  RangeError.checkValueInInterval(n, 1, 6, 'n');
  final bytes = _thumbBytes.putIfAbsent(
    n,
    () =>
        File('${_packageRoot().path}/test/fixtures/thumbs/c$n.jpg')
            .readAsBytesSync(),
  );
  return MemoryImage(bytes);
}

/// An image whose bytes fail to decode, like a clip deleted after the query
/// or a corrupt file (Review Focus 2).
ImageProvider get brokenImage => _brokenImage;

final _brokenImage = MemoryImage(
  Uint8List.fromList(const [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]),
);
