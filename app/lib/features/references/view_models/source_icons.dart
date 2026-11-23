import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/platform/editors_bridge.dart';

part 'source_icons.g.dart';

// The error type only (D-10).
final Logger _log = Logger('sourceIcons');

/// The Android packages of each source's own app, in the order to try them
/// (D-155). TikTok ships as two packages by region. A plain link has no app.
///
/// `<queries>` in the manifest names every one of these, so the phone tells us
/// whether they are installed; `editor_packages_manifest_test.dart` checks it.
const Map<ReferenceSource, List<String>> sourceAppPackages = {
  ReferenceSource.instagram: ['com.instagram.android'],
  ReferenceSource.youtube: ['com.google.android.youtube'],
  ReferenceSource.tiktok: [
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
  ],
  ReferenceSource.link: [],
};

/// The size, in pixels, the icons are asked for.
const int _iconPx = 48;

/// Each source's own app icon as PNG bytes, for the sources whose app is
/// installed (D-155). Never a drawn logo: a source with no installed app is
/// left out, and the card shows the generic link symbol.
///
/// Asks the phone once for the life of the app. A source maps to the icon of
/// its first installed package (in [sourceAppPackages] order) that gave one.
/// When asking fails the map is empty, and the error type is logged.
@Riverpod(keepAlive: true)
Future<Map<ReferenceSource, Uint8List>> sourceIcons(Ref ref) async {
  final bridge = ref.watch(editorsBridgeProvider);
  final packages = [for (final names in sourceAppPackages.values) ...names];
  final List<InstalledApp> apps;
  try {
    apps = await bridge.apps(packages, iconPx: _iconPx);
  } on Object catch (error) {
    _log.warning(
      'Asking the phone for the source icons failed: '
      '${error.runtimeType}',
    );
    return const {};
  }
  final iconOf = {
    for (final app in apps)
      if (app.installed && app.iconPng != null) app.packageName: app.iconPng!,
  };
  final icons = <ReferenceSource, Uint8List>{};
  for (final MapEntry(key: source, value: names) in sourceAppPackages.entries) {
    for (final name in names) {
      final icon = iconOf[name];
      if (icon != null) {
        icons[source] = icon;
        break;
      }
    }
  }
  return icons;
}
