import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/references/view_models/source_icons.dart';
import 'package:taketray/platform/editors_bridge.dart';

import '../../../support/fake_editors_bridge.dart';

Uint8List _png(int n) => Uint8List.fromList([137, 80, 78, 71, n]);

void main() {
  late FakeEditorsBridge bridge;
  late ProviderContainer container;

  setUp(() {
    bridge = FakeEditorsBridge();
    container = ProviderContainer(
      overrides: [editorsBridgeProvider.overrideWithValue(bridge)],
    );
    addTearDown(container.dispose);
  });

  Future<Map<ReferenceSource, Uint8List>> icons() =>
      container.read(sourceIconsProvider.future);

  test('the packages of each source are the ones the manifest names', () {
    expect(sourceAppPackages, {
      ReferenceSource.instagram: ['com.instagram.android'],
      ReferenceSource.youtube: ['com.google.android.youtube'],
      ReferenceSource.tiktok: [
        'com.zhiliaoapp.musically',
        'com.ss.android.ugc.trill',
      ],
      ReferenceSource.link: <String>[],
    });
  });

  test('asks the phone once, for every package, at 48 px', () async {
    final recorded = <(List<String>, int)>[];
    final spy = _SpyBridge(bridge, recorded);
    final c = ProviderContainer(
      overrides: [editorsBridgeProvider.overrideWithValue(spy)],
    );
    addTearDown(c.dispose);
    await c.read(sourceIconsProvider.future);
    await c.read(sourceIconsProvider.future);
    expect(recorded, hasLength(1));
    expect(recorded.single.$1, [
      'com.instagram.android',
      'com.google.android.youtube',
      'com.zhiliaoapp.musically',
      'com.ss.android.ugc.trill',
    ]);
    expect(recorded.single.$2, 48);
  });

  test('each installed source gets its own icon', () async {
    bridge
      ..installed = {
        'com.instagram.android': true,
        'com.google.android.youtube': true,
        'com.zhiliaoapp.musically': true,
      }
      ..icons = {
        'com.instagram.android': _png(1),
        'com.google.android.youtube': _png(2),
        'com.zhiliaoapp.musically': _png(3),
      };
    expect(await icons(), {
      ReferenceSource.instagram: _png(1),
      ReferenceSource.youtube: _png(2),
      ReferenceSource.tiktok: _png(3),
    });
  });

  test(
    'TikTok takes its second package when only that one is installed',
    () async {
      bridge
        ..installed = {'com.ss.android.ugc.trill': true}
        ..icons = {'com.ss.android.ugc.trill': _png(9)};
      expect(await icons(), {ReferenceSource.tiktok: _png(9)});
    },
  );

  test('both TikTok packages installed: the first listed wins', () async {
    bridge
      ..installed = {
        'com.zhiliaoapp.musically': true,
        'com.ss.android.ugc.trill': true,
      }
      ..icons = {
        'com.zhiliaoapp.musically': _png(1),
        'com.ss.android.ugc.trill': _png(2),
      };
    expect(await icons(), {ReferenceSource.tiktok: _png(1)});
  });

  test('a source that is not installed is left out', () async {
    bridge
      ..installed = {'com.google.android.youtube': true}
      ..icons = {'com.google.android.youtube': _png(2)};
    final result = await icons();
    expect(result.keys, [ReferenceSource.youtube]);
  });

  test('nothing installed: an empty map, and never a link icon', () async {
    expect(await icons(), isEmpty);
  });

  test('an installed app that gave no icon is left out', () async {
    bridge.installed = {'com.instagram.android': true};
    expect(await icons(), isEmpty);
  });

  test(
    'an installed first package with no icon falls to the next one',
    () async {
      bridge
        ..installed = {
          'com.zhiliaoapp.musically': true,
          'com.ss.android.ugc.trill': true,
        }
        ..icons = {'com.ss.android.ugc.trill': _png(4)};
      expect(await icons(), {ReferenceSource.tiktok: _png(4)});
    },
  );

  test(
    'a failing phone call gives an empty map and logs the error type only',
    () async {
      bridge.failNext('apps');
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final old = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = old);

      expect(await icons(), isEmpty);

      expect(records, isNotEmpty);
      expect(
        records.map((r) => r.message).join(),
        contains('PlatformException'),
      );
      expect(
        records.map((r) => '${r.message} ${r.error}').join(),
        isNot(contains('apps failed')),
      );
    },
  );

  test('a failure is kept for the life of the app, not retried', () async {
    bridge.failNext('apps');
    expect(await icons(), isEmpty);
    expect(await icons(), isEmpty);
    expect(bridge.calls.where((c) => c == 'apps'), hasLength(1));
  });
}

/// Records what `apps` is asked, then answers from [_inner].
class _SpyBridge extends FakeEditorsBridge {
  _SpyBridge(this._inner, this._recorded);

  final FakeEditorsBridge _inner;
  final List<(List<String>, int)> _recorded;

  @override
  Future<List<InstalledApp>> apps(
    List<String> packageNames, {
    required int iconPx,
  }) {
    _recorded.add((List.of(packageNames), iconPx));
    return _inner.apps(packageNames, iconPx: iconPx);
  }
}
