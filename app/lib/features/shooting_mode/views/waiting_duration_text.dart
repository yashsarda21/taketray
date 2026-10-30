import 'package:taketray/l10n/gen/app_localizations.dart';

/// The total length of the waiting clips, [totalMs] milliseconds, as the Reels
/// banner says it ("45 s", "3 min", "1 h 5 min"): the prototype's `fmt.mins`
/// (D-76).
///
/// - under 60 seconds: whole seconds, rounded ("0 s", "45 s");
/// - else whole minutes, rounded, while they are under 60 ("3 min");
/// - else hours and the minutes left ("1 h 5 min").
///
/// The roundings are the prototype's, so they show its edges: 59.5 s is
/// "60 s" (the seconds are rounded before the choice of unit is made), and
/// 59.5 min is "1 h 0 min". Half rounds up.
String waitingDurationText(AppLocalizations l10n, int totalMs) {
  final seconds = totalMs / 1000;
  if (seconds < 60) return l10n.durationSeconds(seconds.round());
  final minutes = (seconds / 60).round();
  if (minutes < 60) return l10n.durationMinutes(minutes);
  return l10n.durationHoursMinutes(minutes ~/ 60, minutes % 60);
}
