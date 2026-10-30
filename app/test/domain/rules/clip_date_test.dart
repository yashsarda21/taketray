import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';

import '../../support/fake_media_bridge.dart';

void main() {
  // A whole second, so "now + 1 day" is a whole number of seconds too.
  final now = DateTime.utc(2026, 10, 28, 12);
  final dayAheadMs = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
  final dayAheadSec = dayAheadMs ~/ 1000;

  final takenMs = DateTime.utc(
    2026,
    10,
    20,
    9,
    30,
    15,
    250,
  ).millisecondsSinceEpoch;
  final addedSec = DateTime.utc(2026, 10, 21, 8).millisecondsSinceEpoch ~/ 1000;
  final modifiedSec =
      DateTime.utc(2026, 10, 22, 7).millisecondsSinceEpoch ~/ 1000;

  MediaVideo dated({
    required int? taken,
    required int? added,
    required int? modified,
  }) => fakeVideo(
    id: 1,
    dateTakenMs: taken,
    dateAddedSec: added,
    dateModifiedSec: modified,
  );

  DateTime utcMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  DateTime utcSec(int sec) => utcMs(sec * 1000);

  test('uses DATE_TAKEN when plausible', () {
    final v = dated(taken: takenMs, added: addedSec, modified: modifiedSec);
    expect(shotAt(v, now: now), utcMs(takenMs));
  });

  test('falls back to DATE_ADDED when DATE_TAKEN is null', () {
    final v = dated(taken: null, added: addedSec, modified: modifiedSec);
    expect(shotAt(v, now: now), utcSec(addedSec));
  });

  test('falls back to DATE_ADDED when DATE_TAKEN is before 1970', () {
    final v = dated(taken: -1, added: addedSec, modified: modifiedSec);
    expect(shotAt(v, now: now), utcSec(addedSec));
  });

  test('falls back to DATE_ADDED when DATE_TAKEN is a QuickTime-epoch value '
      '(1904)', () {
    final quickTime = DateTime.utc(1904).millisecondsSinceEpoch;
    final v = dated(taken: quickTime, added: addedSec, modified: modifiedSec);
    expect(shotAt(v, now: now), utcSec(addedSec));
  });

  test('falls back to DATE_ADDED when DATE_TAKEN is more than a day ahead', () {
    final tooFar = dated(
      taken: dayAheadMs + 1,
      added: addedSec,
      modified: modifiedSec,
    );
    expect(shotAt(tooFar, now: now), utcSec(addedSec));

    // Exactly one day ahead is still plausible.
    final edge = dated(
      taken: dayAheadMs,
      added: addedSec,
      modified: modifiedSec,
    );
    expect(shotAt(edge, now: now), utcMs(dayAheadMs));
  });

  test('one day ahead is exactly 24 hours after now', () {
    expect(utcMs(dayAheadMs).difference(now), const Duration(hours: 24));
  });

  test('falls back to DATE_MODIFIED when DATE_ADDED is also bad', () {
    final nullAdded = dated(taken: null, added: null, modified: modifiedSec);
    expect(shotAt(nullAdded, now: now), utcSec(modifiedSec));

    final negativeAdded = dated(taken: -1, added: -1, modified: modifiedSec);
    expect(shotAt(negativeAdded, now: now), utcSec(modifiedSec));

    final futureAdded = dated(
      taken: null,
      added: dayAheadSec + 1,
      modified: modifiedSec,
    );
    expect(shotAt(futureAdded, now: now), utcSec(modifiedSec));
  });

  test('uses now when all three are bad or null', () {
    final allNull = dated(taken: null, added: null, modified: null);
    expect(shotAt(allNull, now: now), now);

    final allBad = dated(
      taken: dayAheadMs + 1,
      added: -1,
      modified: dayAheadSec + 1,
    );
    expect(shotAt(allBad, now: now), now);
  });

  test('result is UTC', () {
    final sources = [
      dated(taken: takenMs, added: null, modified: null),
      dated(taken: null, added: addedSec, modified: null),
      dated(taken: null, added: null, modified: modifiedSec),
      dated(taken: null, added: null, modified: null),
    ];
    for (final v in sources) {
      expect(shotAt(v, now: now).isUtc, isTrue);
    }

    // Even when the caller's now is a local DateTime.
    final fromLocalNow = shotAt(sources.last, now: now.toLocal());
    expect(fromLocalNow.isUtc, isTrue);
    expect(fromLocalNow, now);
  });

  test('the epoch itself (0) is plausible for each of the three dates', () {
    final epoch = DateTime.utc(1970);
    expect(
      shotAt(dated(taken: 0, added: addedSec, modified: null), now: now),
      epoch,
    );
    expect(
      shotAt(dated(taken: null, added: 0, modified: modifiedSec), now: now),
      epoch,
    );
    expect(
      shotAt(dated(taken: null, added: null, modified: 0), now: now),
      epoch,
    );
    expect(shotAt(dated(taken: 0, added: 0, modified: 0), now: now), epoch);
  });

  test('DATE_ADDED and DATE_MODIFIED exactly one day ahead are kept', () {
    expect(
      shotAt(
        dated(taken: null, added: dayAheadSec, modified: modifiedSec),
        now: now,
      ),
      utcMs(dayAheadMs),
    );
    expect(
      shotAt(
        dated(taken: null, added: dayAheadSec + 1, modified: dayAheadSec),
        now: now,
      ),
      utcMs(dayAheadMs),
    );
    expect(
      shotAt(
        dated(taken: null, added: null, modified: dayAheadSec + 1),
        now: now,
      ),
      now,
    );
  });

  test('with a now that has milliseconds, the seconds bound rounds down', () {
    // The bound is 12:00:00.500 tomorrow: 12:00:00 is inside, 12:00:01 is
    // half a second past it.
    final halfNow = DateTime.utc(2026, 10, 28, 12, 0, 0, 500);
    expect(
      shotAt(
        dated(taken: null, added: dayAheadSec, modified: modifiedSec),
        now: halfNow,
      ),
      utcSec(dayAheadSec),
    );
    expect(
      shotAt(
        dated(taken: null, added: dayAheadSec + 1, modified: modifiedSec),
        now: halfNow,
      ),
      utcSec(modifiedSec),
    );
    expect(
      shotAt(
        dated(taken: null, added: null, modified: dayAheadSec + 1),
        now: halfNow,
      ),
      halfNow,
    );
  });

  test('seconds so large that × 1000 overflows are not plausible', () {
    // 18446745853709552 × 1000 is 2^64 + 1780000000384: in 64-bit
    // arithmetic it wraps around to 1780000000384, a date in 2026.
    const wraps = 18446745853709552;
    expect(wraps * 1000, 1780000000384);
    expect(
      shotAt(
        dated(taken: null, added: wraps, modified: modifiedSec),
        now: now,
      ),
      utcSec(modifiedSec),
    );
    expect(
      shotAt(dated(taken: null, added: null, modified: wraps), now: now),
      now,
    );
  });
}
