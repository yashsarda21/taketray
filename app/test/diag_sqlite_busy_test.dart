// TEMPORARY diagnostic for the CI-only "database is locked" (D-164).
// It fails on purpose so its findings show in `gh run view --log-failed`.
// ignore_for_file: depend_on_referenced_packages
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final class _Timespec extends Struct {
  @Long()
  external int sec;
  @Long()
  external int nsec;
}

typedef _NanosleepC = Int Function(
  Pointer<_Timespec> req,
  Pointer<_Timespec> rem,
);
typedef _NanosleepDart = int Function(
  Pointer<_Timespec> req,
  Pointer<_Timespec> rem,
);

String _nanosleep(int ms) {
  final fn = DynamicLibrary.process()
      .lookupFunction<_NanosleepC, _NanosleepDart>('nanosleep');
  final req = calloc<_Timespec>()
    ..ref.sec = ms ~/ 1000
    ..ref.nsec = (ms % 1000) * 1000000;
  final rem = calloc<_Timespec>();
  final sw = Stopwatch()..start();
  final r = fn(req, rem);
  final took = sw.elapsedMicroseconds;
  final out =
      'nanosleep(${ms}ms) returned $r after ${took}us, '
      'remaining ${rem.ref.sec}s ${rem.ref.nsec}ns';
  calloc
    ..free(req)
    ..free(rem);
  return out;
}

String _busyRace(String dir, {required bool wallClockHandler}) {
  final path = '$dir/race_${wallClockHandler ? 'h' : 't'}.sqlite';
  final a = sqlite3.open(path)
    ..execute('PRAGMA busy_timeout = 2000')
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('CREATE TABLE IF NOT EXISTS t (x)');
  final b = sqlite3.open(path)..execute('PRAGMA busy_timeout = 2000');
  var calls = 0;
  if (wallClockHandler) {
    final sw = Stopwatch()..start();
    b.busyHandler = (count) {
      calls++;
      if (sw.elapsedMilliseconds >= 2000) return false;
      sleep(const Duration(milliseconds: 5));
      return true;
    };
  }
  final mode = b.select('PRAGMA journal_mode').single.values.single;
  final timeout = b.select('PRAGMA busy_timeout').single.values.single;
  a.execute('BEGIN IMMEDIATE');
  final sw = Stopwatch()..start();
  String outcome;
  try {
    b.execute('BEGIN IMMEDIATE');
    outcome = 'no error';
    b.execute('ROLLBACK');
  } on SqliteException catch (e) {
    outcome = 'SqliteException(${e.extendedResultCode})';
  }
  final took = sw.elapsedMilliseconds;
  a
    ..execute('ROLLBACK')
    ..close();
  b.close();
  return '${wallClockHandler ? 'wall-clock busyHandler' : 'busy_timeout'}: '
      'journal_mode=$mode busy_timeout=$timeout -> $outcome after ${took}ms'
      '${wallClockHandler ? ' ($calls handler calls)' : ''}';
}

String _sigCgt() {
  final f = File('/proc/self/status');
  if (!f.existsSync()) return 'no /proc/self/status';
  final line = f.readAsLinesSync().firstWhere(
    (l) => l.startsWith('SigCgt'),
    orElse: () => 'SigCgt: ?',
  );
  final mask = int.tryParse(line.split(':').last.trim(), radix: 16) ?? 0;
  // SIGPROF is 27 on Linux.
  return '$line (SIGPROF handled: ${(mask >> 26) & 1 == 1})';
}

void main() {
  test('DIAG sqlite busy', () async {
    final dir = Directory.systemTemp.createTempSync('diag_busy_');
    final lines = <String>[
      'os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'exe=${Platform.executable}',
      'exeArgs=${Platform.executableArguments}',
      'sqlite=${sqlite3.version}',
      _sigCgt(),
    ];
    final mem = sqlite3.openInMemory();
    final opts = mem
        .select('PRAGMA compile_options')
        .map((r) => r.values.single)
        .join(',');
    mem.close();
    lines
      ..add('compile_options=$opts')
      ..add('main isolate: ${_nanosleep(200)}')
      ..add('main isolate: ${_busyRace(dir.path, wallClockHandler: false)}')
      ..add('main isolate: ${_busyRace(dir.path, wallClockHandler: true)}');
    final path = dir.path;
    lines.addAll(
      await Isolate.run(
        () => [
          'bg isolate: ${_nanosleep(200)}',
          'bg isolate: ${_busyRace(path, wallClockHandler: false)}',
          'bg isolate: ${_busyRace(path, wallClockHandler: true)}',
        ],
      ),
    );
    dir.deleteSync(recursive: true);
    fail('DIAG\n${lines.join('\n')}');
  });
}
