import 'package:intl/intl.dart';
import 'package:taketray/features/shooting_mode/views/waiting_duration_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// The time range of a scene, from [start] to [end], as the clock read where
/// the clips were shot (D-95, the prototype's `fmt.range`).
///
/// [start] and [end] are wall-clock values (`Scene.start`, `Scene.end`):
/// UTC-flagged `DateTime`s whose fields are the time, never converted.
/// [locale] and [use24Hour] are the app's locale and the phone's 24-hour
/// setting, as for `wallClockTimeText` (D-76).
///
/// - Under a minute apart (or [end] not after [start]): one time, "1:05 PM".
/// - 24-hour: "13:05–13:20", an en dash with no spaces.
/// - 12-hour with the same am/pm: the period is written once, after the
///   second time: "1:05–1:20 PM". The first time uses the locale's own `jm`
///   pattern with the period removed, so the digits, separators and spaces
///   stay the locale's. This is only done when the locale puts the period
///   after the time (English does; Japanese writes "午後1:05"); otherwise both
///   times are written in full, which is never wrong.
/// - 12-hour with different periods: both in full, "11:50 AM–12:10 PM".
String timeRangeText(
  DateTime start,
  DateTime end, {
  required String locale,
  required bool use24Hour,
}) {
  final formats = _RangeFormats.of(locale, use24Hour: use24Hour);

  // `inMinutes` truncates: 59.9 seconds is 0 minutes.
  if (end.difference(start).inMinutes < 1) return formats.full.format(start);

  final withoutPeriod = formats.withoutPeriod;
  if (withoutPeriod != null && _isPm(start) == _isPm(end)) {
    return '${withoutPeriod.format(start)}–${formats.full.format(end)}';
  }
  return '${formats.full.format(start)}–${formats.full.format(end)}';
}

bool _isPm(DateTime wallClock) => wallClock.hour >= 12;

/// The period at the end of a 12-hour pattern, with the spaces around it.
final RegExp _trailingPeriod = RegExp(r'[\s  ]*a[\s  ]*$');

/// The formats of one locale and clock setting, made once: To tag writes a
/// range per scene header on every build.
class _RangeFormats {
  _RangeFormats._(String locale, {required bool use24Hour})
    // The same formats as `wallClockTimeText` (D-76).
    : full = use24Hour ? DateFormat.Hm(locale) : DateFormat.jm(locale),
      withoutPeriod = use24Hour ? null : _jmWithoutTrailingPeriod(locale);

  factory _RangeFormats.of(String locale, {required bool use24Hour}) =>
      _cache.putIfAbsent((
        locale,
        use24Hour,
      ), () => _RangeFormats._(locale, use24Hour: use24Hour));

  static final Map<(String, bool), _RangeFormats> _cache = {};

  /// One time in full: "1:05 PM", or "13:05".
  final DateFormat full;

  /// The 12-hour time without its period, for the first time of a range
  /// that shares one; null in 24-hour time or when the locale does not put
  /// the period last.
  final DateFormat? withoutPeriod;
}

/// The locale's 12-hour time format without its period, or null when the
/// period is not at the end of the pattern (or there is none), where it
/// cannot be written once after the second time.
DateFormat? _jmWithoutTrailingPeriod(String locale) {
  final pattern = DateFormat.jm(locale).pattern;
  if (pattern == null) return null;
  final match = _trailingPeriod.firstMatch(pattern);
  if (match == null) return null;
  final rest = pattern.substring(0, match.start);
  return rest.contains('a') || rest.isEmpty ? null : DateFormat(rest, locale);
}

/// A length for the To tag summary ("{n} clips · {s} scenes · {mins}") in the
/// prototype's `fmt.mins`: "45 s", "12 min", "1 h 5 min". The Reels banner
/// already says the same thing, so this is `waitingDurationText` (D-76) under
/// the name the To tag summary uses; no new strings.
String minutesText(AppLocalizations l10n, int totalMs) =>
    waitingDurationText(l10n, totalMs);
