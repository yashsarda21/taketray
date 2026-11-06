import 'package:taketray/domain/models/media.dart';

/// How long Shooting mode stays on before "Still shooting?" asks (D-105,
/// D-106): 14 days of 24 hours, as the phone's `STILL_AFTER_DAYS`.
const stillShootingAfter = Duration(days: 14);

/// Whether "Still shooting?" is due at [now] for session [s]: Shooting mode
/// is on, the question was not answered in this session, and at least
/// [stillShootingAfter] has passed since it went on. A [now] before the
/// start (the clock set back) is not due.
bool stillShootingDue(ShootingState s, DateTime now) {
  final since = s.since;
  if (!s.on || s.stillAnswered || since == null) return false;
  return now.difference(since) >= stillShootingAfter;
}
