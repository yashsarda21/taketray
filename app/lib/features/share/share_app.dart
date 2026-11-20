import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/app.dart' show resolvePhoneLocale;
import 'package:taketray/app/database_refresh.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/share_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The share screen's whole app (D-163), run by `shareMain` in its own
/// engine over the app that shared. It has the app's themes, following the
/// phone's light or dark setting, and the app's strings, and it paints
/// nothing of its own: the window is see-through, so the sharing app shows
/// behind it.
///
/// [DatabaseRefresh] re-reads the reels when the share comes back to the
/// front, in case the app saved one meanwhile (D-164).
///
/// For now (Task 2) it is empty, and Back closes it. Task 6 puts the Save
/// reference sheet over a dim background here.
class ShareApp extends StatelessWidget {
  /// Creates the share screen's app.
  const ShareApp({super.key});

  /// The key of the screen's body, for tests.
  @visibleForTesting
  static const Key bodyKey = Key('shareBody');

  @override
  Widget build(BuildContext context) => DatabaseRefresh(
    child: MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolvePhoneLocale,
      theme: TakeTrayTheme.light(),
      darkTheme: TakeTrayTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const _ShareBody(key: bodyKey),
    ),
  );
}

/// Nothing yet; Back closes the share screen.
class _ShareBody extends ConsumerWidget {
  const _ShareBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      unawaited(ref.read(shareBridgeProvider).finish());
    },
    child: const SizedBox.expand(),
  );
}
