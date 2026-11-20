import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/database/connection.dart';

/// Re-reads what the other engine may have written, each time this engine
/// comes back to the front (D-164).
///
/// The app and the share screen each have their own connection to
/// `taketray.sqlite`, and drift's `watch` streams only see their own
/// connection's writes. On every resume this tells this engine's database
/// that the reels and their references changed, so every stream on them
/// (Home, a reel's page, the share sheet's reel list) runs its query again
/// and shows what the other engine saved meanwhile. A share can write
/// nothing else.
///
/// Nothing happens at start (the first queries read the file anyway), and
/// nothing on a resume before this engine has opened the database. Each
/// engine has exactly one: `TakeTrayApp` and `ShareApp` put it above their
/// `MaterialApp`.
class DatabaseRefresh extends ConsumerStatefulWidget {
  const DatabaseRefresh({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DatabaseRefresh> createState() => _DatabaseRefreshState();
}

class _DatabaseRefreshState extends ConsumerState<DatabaseRefresh> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!ref.exists(appDatabaseProvider)) return;
    final db = ref.read(appDatabaseProvider);
    db.notifyUpdates({
      TableUpdate.onTable(db.reels),
      TableUpdate.onTable(db.reelReferences),
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
