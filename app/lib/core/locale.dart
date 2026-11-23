import 'package:flutter/widgets.dart';

/// The phone's own locale when the app has its language, so dates follow the
/// phone: an English (India) phone gets "8 Oct", an English (United States)
/// phone "Oct 8" (D-79). Without it Flutter would pick the plain `en` the app
/// lists, and every English phone would read "Oct 8".
///
/// The first of the phone's [preferred] locales whose language is in
/// [supported], whole (region and all); if none is, the first supported one.
Locale resolvePhoneLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (supported.any((s) => s.languageCode == locale.languageCode)) {
      return locale;
    }
  }
  return supported.first;
}
