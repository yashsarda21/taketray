import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/to_tag_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/tt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await SampleData.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(TakeTrayApp(state: AppState(data, prefs)));
}

class TakeTrayApp extends StatelessWidget {
  const TakeTrayApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'TakeTray',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(state.brand, Brightness.light),
          darkTheme: buildTheme(state.brand, Brightness.dark),
          themeMode: state.themeMode,
          home: const AppShell(),
        ),
      ),
    );
  }
}

/// Floating navigation pill: Reels, To tag (count badge in the "clips waiting" colour), Settings.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = s.toTag.length;
    return Scaffold(
      extendBody: true, // content scrolls under the floating navigation pill
      body: IndexedStack(
        index: s.tab,
        children: const [HomeScreen(), ToTagScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: FloatingNavBar(
        index: s.tab,
        onTap: s.setTab,
        items: [
          const NavItem(Symbols.video_library_rounded, 'Reels'),
          NavItem(Symbols.sell_rounded, 'To tag', badge: n),
          const NavItem(Symbols.settings_rounded, 'Settings'),
        ],
      ),
    );
  }
}
