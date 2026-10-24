import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../theme/tokens.g.dart';

/// Clips shot close together (gap under 10 minutes, same day) form a scene.
class Scene {
  Scene(this.ids, this.start, this.end);
  final List<String> ids;
  final DateTime start;
  DateTime end;
}

/// What Undo restores: the To tag list, skipped list, last tags and clip memberships.
class _Snapshot {
  _Snapshot(AppState s)
    : toTag = List.of(s.toTag),
      skipped = List.of(s.skipped),
      lastTags = List.of(s.lastTags),
      reels = {for (final c in s.clips.values) c.id: Set.of(c.reels)};
  final List<String> toTag;
  final List<String> skipped;
  final List<String> lastTags;
  final Map<String, Set<String>> reels;
}

class AppState extends ChangeNotifier {
  AppState(SampleData d, this._prefs)
    : reels = d.reels,
      clips = d.clips,
      toTag = d.toTag,
      skipped = d.skipped,
      shootingSince = d.shootingSince {
    brand = shippedBrand; // Graphite & marigold, chosen 2026-10-23
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString('themeMode'),
      orElse: () => ThemeMode.system,
    );
  }

  final SharedPreferences _prefs;
  final List<Reel> reels;
  final Map<String, VideoClip> clips;
  List<String> toTag;
  List<String> skipped;
  List<String> lastTags = [];
  bool shootingOn = true;
  int tab = 0;
  DateTime shootingSince;
  late BrandOption brand;
  late ThemeMode themeMode;
  _Snapshot? _undo;

  /* ---------------------------------------------------------- settings */
  void setTab(int t) {
    tab = t;
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString('themeMode', m.name);
    notifyListeners();
  }

  /* ----------------------------------------------------------- queries */
  Reel reel(String id) => reels.firstWhere((r) => r.id == id);

  List<VideoClip> clipsOf(String reelId) =>
      clips.values.where((c) => c.reels.contains(reelId)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  VideoClip? coverOf(String reelId) =>
      clipsOf(reelId).where((c) => !c.missing).firstOrNull;

  List<Reel> get reelsNewestFirst =>
      List.of(reels)..sort((a, b) => b.created.compareTo(a.created));

  /// Recording reels first, then the rest (newest first inside each group).
  List<Reel> get orderedReels {
    int rank(ReelStatus s) => s.index;
    return List.of(reels)..sort(
      (a, b) => rank(a.status) != rank(b.status)
          ? rank(a.status) - rank(b.status)
          : b.created.compareTo(a.created),
    );
  }

  int get recordingRefCount => reels
      .where((r) => r.status == ReelStatus.recording)
      .fold(0, (n, r) => n + r.refs.length);

  int totalSec(Iterable<VideoClip> cs) =>
      cs.fold(0, (t, c) => t + c.durationSec);

  List<Scene> scenes(List<String> ids) {
    final list = ids.map((id) => clips[id]!).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final out = <Scene>[];
    for (final c in list) {
      final cur = out.lastOrNull;
      final last = cur == null ? null : clips[cur.ids.last]!;
      final gap = last == null
          ? null
          : c.at.difference(last.at.add(Duration(seconds: last.durationSec)));
      final sameDay =
          last != null &&
          last.at.year == c.at.year &&
          last.at.month == c.at.month &&
          last.at.day == c.at.day;
      if (cur == null || !sameDay || gap!.inMinutes >= 10) {
        out.add(Scene([c.id], c.at, c.at));
      } else {
        cur.ids.add(c.id);
        cur.end = c.at;
      }
    }
    return out;
  }

  /* ----------------------------------------------------------- actions */
  void toggleShooting() {
    shootingOn = !shootingOn;
    if (shootingOn) shootingSince = DateTime.now();
    notifyListeners();
  }

  /// Tag clips into reels and remember the reels for "Same as previous".
  void tag(List<String> clipIds, List<String> reelIds, {bool remember = true}) {
    _undo = _Snapshot(this);
    for (final id in clipIds) {
      clips[id]!.reels.addAll(reelIds);
    }
    toTag = toTag.where((id) => !clipIds.contains(id)).toList();
    if (remember) lastTags = List.of(reelIds);
    notifyListeners();
  }

  void skip(List<String> clipIds) {
    _undo = _Snapshot(this);
    toTag = toTag.where((id) => !clipIds.contains(id)).toList();
    skipped = [...skipped, ...clipIds];
    notifyListeners();
  }

  bool get canUndo => _undo != null;

  void undo() {
    final u = _undo;
    if (u == null) return;
    toTag = u.toTag;
    skipped = u.skipped;
    lastTags = u.lastTags;
    u.reels.forEach(
      (id, r) => clips[id]!.reels
        ..clear()
        ..addAll(r),
    );
    _undo = null;
    notifyListeners();
  }

  String newReel(String name) {
    final id = 'n${DateTime.now().microsecondsSinceEpoch}';
    reels.add(
      Reel(
        id: id,
        name: name.trim(),
        status: ReelStatus.recording,
        created: DateTime.now(),
      ),
    );
    notifyListeners();
    return id;
  }

  String? validateName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'Give this reel a name';
    if (n.length > 40) return 'Use 40 characters or fewer';
    final dup = reels
        .where((r) => r.name.toLowerCase() == n.toLowerCase())
        .firstOrNull;
    return dup == null ? null : 'You already have a reel called ${dup.name}';
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
