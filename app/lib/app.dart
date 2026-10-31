import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/app/media_lifecycle.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Root widget: the TakeTray light and dark themes, following the system
/// (`themeMode` defaults to [ThemeMode.system]).
///
/// [MediaLifecycle] wraps the router: it starts the zone sync, the access
/// check and the scan at app start and on resume (D-75).
class TakeTrayApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaLifecycle(
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        routerConfig: ref.watch(appRouterProvider),
        // The one root messenger, so a snack outlives its screen (D-85).
        scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolvePhoneLocale,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

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
