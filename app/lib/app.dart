import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/app/media_lifecycle.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
