import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';
import 'media_harness.dart' show captureLogs, logText;

/// A clip shot at [shot] (a UTC instant) in [zone].
Clip clipAt(int id, DateTime shot, {String? zone}) => Clip(
  id: id,
  source: ClipSource.mediaStore,
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + id,
    durationMs: 5000,
    dateTakenUtc: shot.toUtc(),
    displayName: 'VID_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 10, 28),
  missing: false,
  mediaStoreId: id,
  volumeName: 'external_primary',
  timeZoneId: zone,
);

/// Summer and winter instants (London is +1 h, then +0).
final DateTime summer = DateTime.utc(2026, 7, 1, 12);
final DateTime winter = DateTime.utc(2026, 12, 1, 12);

/// The wall clock as [ClipLocalTime] holds it: a UTC-flagged [DateTime] whose
/// fields are the local time.
DateTime wall(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min);

/// The phone-local wall clock of [instant], as the Dart fallback gives it.
DateTime dartLocalWall(DateTime instant) {
  final l = instant.toLocal();
  return DateTime.utc(
    l.year,
    l.month,
    l.day,
    l.hour,
    l.minute,
    l.second,
    l.millisecond,
    l.microsecond,
  );
}

/// Each `zoneOffsetsMs` request as `[zoneIds, instantsMs]` (records holding
/// lists do not compare by content).
List<List<Object>> requests(FakeMediaBridge bridge) => [
  for (final (ids, ms) in bridge.zoneOffsetRequests) [ids, ms],
];

void main() {
  late FakeMediaBridge bridge;
  late ClipTimeService service;

  setUp(() {
    bridge = FakeMediaBridge();
    service = ClipTimeService(bridge);
  });

  test('uses the clip zone', () async {
    bridge.currentZone = 'UTC';
    final times = await service.localTimes([
      clipAt(1, summer, zone: 'Europe/London'),
      clipAt(2, summer, zone: 'Asia/Kolkata'),
      clipAt(3, winter, zone: 'Europe/London'),
    ]);

    expect(
      times[1],
      ClipLocalTime(
        wallClock: wall(2026, 7, 1, 13),
        zoneId: 'Europe/London',
        isPhoneZone: false,
      ),
    );
    expect(
      times[2],
      ClipLocalTime(
        wallClock: wall(2026, 7, 1, 17, 30),
        zoneId: 'Asia/Kolkata',
        isPhoneZone: false,
      ),
    );
    expect(
      times[3],
      ClipLocalTime(
        wallClock: wall(2026, 12, 1, 12),
        zoneId: 'Europe/London',
        isPhoneZone: false,
      ),
    );
    expect(times.values.every((t) => t.wallClock.isUtc), isTrue);
  });

  test('null zone uses the phone zone', () async {
    bridge.currentZone = 'Asia/Kolkata';
    final times = await service.localTimes([
      clipAt(1, summer),
      clipAt(2, summer, zone: 'Asia/Kolkata'),
    ]);

    // Both are in the phone's zone: the second one names it itself.
    for (final id in [1, 2]) {
      expect(
        times[id],
        ClipLocalTime(
          wallClock: wall(2026, 7, 1, 17, 30),
          zoneId: 'Asia/Kolkata',
          isPhoneZone: true,
        ),
      );
    }
    expect(requests(bridge), [
      [
        ['Asia/Kolkata'],
        [summer.millisecondsSinceEpoch],
      ],
    ]);
  });

  test('unknown zone falls back', () async {
    bridge.currentZone = 'Europe/London';
    final records = captureLogs();

    final times = await service.localTimes([
      clipAt(1, summer, zone: 'Mars/Olympus_Mons'),
      clipAt(2, summer, zone: ''),
    ]);

    // The phone's zone (London, BST), not UTC and not the unknown one.
    for (final id in [1, 2]) {
      expect(
        times[id],
        ClipLocalTime(
          wallClock: wall(2026, 7, 1, 13),
          zoneId: 'Europe/London',
          isPhoneZone: true,
        ),
      );
    }
    expect(requests(bridge).last, [
      ['Europe/London'],
      [summer.millisecondsSinceEpoch],
    ]);
    // Counts only, never a zone id or a city (D-10).
    final text = logText(records);
    expect(text, contains('2 clips'));
    expect(text, isNot(contains('Mars')));
    expect(text, isNot(contains('Olympus')));
    expect(text, isNot(contains('London')));

    // Learned: the next call asks the phone nothing more.
    bridge.calls.clear();
    final again = await service.localTimes([
      clipAt(1, summer, zone: 'Mars/Olympus_Mons'),
    ]);
    expect(again[1]!.wallClock, wall(2026, 7, 1, 13));
    expect(bridge.calls, ['currentZoneId']);
  });

  test('one bridge call for many clips', () async {
    bridge.currentZone = 'Europe/London';
    final zones = [null, 'Europe/London', 'Asia/Kolkata', 'UTC'];
    final clips = [
      for (var i = 0; i < 300; i++)
        clipAt(
          i,
          summer.add(Duration(minutes: 7 * i)),
          zone: zones[i % zones.length],
        ),
    ];

    final times = await service.localTimes(clips);

    expect(bridge.calls, ['currentZoneId', 'zoneOffsetsMs']);
    expect(times.length, 300);
    // Null and Europe/London clips share their (zone, instant) entry only
    // when they share an instant; here every instant differs.
    expect(bridge.zoneOffsetRequests.single.$1.length, 300);
    expect(times[2]!.wallClock, wall(2026, 7, 1, 17, 44)); // 12:14 + 5:30
    expect(times[3]!.zoneId, 'UTC');
    expect(times[3]!.isPhoneZone, isFalse);
  });

  test('cache avoids a second call', () async {
    bridge.currentZone = 'UTC';
    final london = clipAt(1, summer, zone: 'Europe/London');
    final first = await service.localTimes([london]);
    bridge.calls.clear();

    final second = await service.localTimes([london]);

    expect(second, first);
    expect(bridge.calls, ['currentZoneId']);

    // The same zone at another instant is another entry: winter is GMT.
    final later = clipAt(2, winter, zone: 'Europe/London');
    final third = await service.localTimes([london, later]);
    expect(requests(bridge).last, [
      ['Europe/London'],
      [winter.millisecondsSinceEpoch],
    ]);
    expect(third[1]!.wallClock, wall(2026, 7, 1, 13));
    expect(third[2]!.wallClock, wall(2026, 12, 1, 12));
  });

  test('bridge error falls back and does not throw', () async {
    bridge.currentZone = 'Europe/London';
    final records = captureLogs();
    bridge.failNext('zoneOffsetsMs');
    final clips = [clipAt(1, summer, zone: 'Asia/Kolkata'), clipAt(2, winter)];

    final times = await service.localTimes(clips);

    // Every clip in the phone's zone, from Dart's own local time.
    expect(
      times[1],
      ClipLocalTime(
        wallClock: dartLocalWall(summer),
        zoneId: 'Europe/London',
        isPhoneZone: true,
      ),
    );
    expect(
      times[2],
      ClipLocalTime(
        wallClock: dartLocalWall(winter),
        zoneId: 'Europe/London',
        isPhoneZone: true,
      ),
    );
    expect(
      records.where((r) => r.level == Level.WARNING).map((r) => r.message),
      [contains('fake-failure')],
    );
    expect(logText(records), isNot(contains('Kolkata')));
    expect(logText(records), isNot(contains('London')));

    // The failure is not remembered: the next call asks again.
    final again = await service.localTimes(clips);
    expect(again[1]!.wallClock, wall(2026, 7, 1, 17, 30));
    expect(again[2]!.wallClock, wall(2026, 12, 1, 12));
    expect(bridge.calls.where((c) => c == 'zoneOffsetsMs'), hasLength(2));
  });

  test('a phone zone that cannot be read uses Dart local time', () async {
    final records = captureLogs();
    bridge.failNext('currentZoneId');

    final times = await service.localTimes([
      clipAt(1, summer),
      clipAt(2, summer, zone: 'Asia/Kolkata'),
      clipAt(3, summer, zone: 'Not/AZone'),
    ]);

    expect(
      times[1],
      ClipLocalTime(
        wallClock: dartLocalWall(summer),
        zoneId: null,
        isPhoneZone: true,
      ),
    );
    // The clip's own zone still works, but it cannot be compared with the
    // phone's.
    expect(
      times[2],
      ClipLocalTime(
        wallClock: wall(2026, 7, 1, 17, 30),
        zoneId: 'Asia/Kolkata',
        isPhoneZone: false,
      ),
    );
    expect(
      times[3],
      ClipLocalTime(
        wallClock: dartLocalWall(summer),
        zoneId: null,
        isPhoneZone: true,
      ),
    );
    expect(
      records.where((r) => r.level == Level.WARNING).single.message,
      contains('fake-failure'),
    );
    // Only the clip zones were asked, in one call.
    expect(bridge.zoneOffsetRequests.single.$1, ['Asia/Kolkata', 'Not/AZone']);
  });

  test('an answer of the wrong length is a failure, not a misread', () async {
    final short = _ShortBridge()..currentZone = 'UTC';
    final records = captureLogs();

    final times = await ClipTimeService(short).localTimes([
      clipAt(1, summer, zone: 'Asia/Kolkata'),
      clipAt(2, winter, zone: 'Asia/Kolkata'),
    ]);

    expect(times[1]!.wallClock, dartLocalWall(summer));
    expect(times[1]!.isPhoneZone, isTrue);
    expect(records.where((r) => r.level == Level.WARNING), hasLength(1));
  });

  test('a bridge that never answers times out to the fallback', () async {
    bridge.currentZone = 'UTC';
    final gate = bridge.gate('zoneOffsetsMs');
    addTearDown(gate.complete);
    final quick = ClipTimeService(
      bridge,
      bridgeTimeout: const Duration(milliseconds: 20),
    );

    final times = await quick.localTimes([
      clipAt(1, summer, zone: 'Asia/Kolkata'),
    ]);

    expect(
      times[1],
      ClipLocalTime(
        wallClock: dartLocalWall(summer),
        zoneId: 'UTC',
        isPhoneZone: true,
      ),
    );
  });

  test('no clips: no bridge call', () async {
    expect(await service.localTimes(const []), isEmpty);
    expect(bridge.calls, isEmpty);
  });

  test('two clips at one (zone, instant) are asked once', () async {
    await service.localTimes([
      clipAt(1, summer, zone: 'Asia/Kolkata'),
      clipAt(2, summer, zone: 'Asia/Kolkata'),
    ]);
    expect(bridge.zoneOffsetRequests.single.$1, ['Asia/Kolkata']);
  });

  test('cache evicts beyond 4096', () async {
    expect(clipTimeCacheSize, 4096);
    final clips = [
      for (var i = 0; i < 4097; i++)
        clipAt(i, summer.add(Duration(seconds: i)), zone: 'Asia/Kolkata'),
    ];

    final times = await service.localTimes(clips);

    // This call's answers are all used, even the one already evicted.
    expect(times.length, 4097);
    expect(times[0]!.wallClock, wall(2026, 7, 1, 17, 30));
    expect(bridge.zoneOffsetRequests.single.$1, hasLength(4097));

    // The newest 4096 stay; the oldest is gone and is asked again.
    await service.localTimes([clips[1], clips[4096]]);
    expect(bridge.zoneOffsetRequests, hasLength(1));
    await service.localTimes([clips[0]]);
    expect(bridge.zoneOffsetRequests, hasLength(2));
    expect(bridge.zoneOffsetRequests.last.$2, [summer.millisecondsSinceEpoch]);
  });

  test('a cache hit counts as recent use (least recently used goes)', () async {
    final small = ClipTimeService(bridge, cacheSize: 2);
    final a = clipAt(1, summer, zone: 'UTC');
    final b = clipAt(2, winter, zone: 'UTC');
    final c = clipAt(3, summer.add(const Duration(hours: 1)), zone: 'UTC');
    await small.localTimes([a]);
    await small.localTimes([b]);
    await small.localTimes([a]); // a is now newer than b
    await small.localTimes([c]); // evicts b, not a
    final before = bridge.zoneOffsetRequests.length;

    await small.localTimes([a]);
    expect(bridge.zoneOffsetRequests, hasLength(before));
    await small.localTimes([b]);
    expect(bridge.zoneOffsetRequests, hasLength(before + 1));
  });

  test('clipTimeServiceProvider is one service for the app', () {
    final container = ProviderContainer.test(
      overrides: [mediaBridgeProvider.overrideWithValue(bridge)],
    );
    final first = container.read(clipTimeServiceProvider);
    expect(first, isA<ClipTimeService>());
    expect(container.read(clipTimeServiceProvider), same(first));
  });

  test('ClipLocalTime equality and text', () {
    final a = ClipLocalTime(
      wallClock: wall(2026, 7, 1, 13),
      zoneId: 'Europe/London',
      isPhoneZone: false,
    );
    expect(
      a,
      ClipLocalTime(
        wallClock: wall(2026, 7, 1, 13),
        zoneId: 'Europe/London',
        isPhoneZone: false,
      ),
    );
    expect(
      a.hashCode,
      isNot(
        ClipLocalTime(
          wallClock: wall(2026, 7, 1, 13),
          zoneId: 'Europe/London',
          isPhoneZone: true,
        ).hashCode,
      ),
    );
    expect(
      a,
      isNot(
        ClipLocalTime(
          wallClock: wall(2026, 7, 1, 14),
          zoneId: 'Europe/London',
          isPhoneZone: false,
        ),
      ),
    );
    expect(a.toString(), contains('2026-07-01 13:00'));
  });
}

/// Answers one entry too few.
class _ShortBridge extends FakeMediaBridge {
  @override
  Future<List<int?>> zoneOffsetsMs(
    List<String> zoneIds,
    List<int> instantsMs,
  ) async => (await super.zoneOffsetsMs(zoneIds, instantsMs)).sublist(1);
}
