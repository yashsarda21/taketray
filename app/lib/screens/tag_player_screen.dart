import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Tag player: always dark, on black. One tap on a reel tags the clip and moves on.
class TagPlayerScreen extends StatelessWidget {
  const TagPlayerScreen({super.key, required this.startId});
  final String startId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Theme(
      data: buildTheme(s.brand, Brightness.dark),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _Player(startId: startId),
        ),
      ),
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({required this.startId});
  final String startId;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> with SingleTickerProviderStateMixin {
  late AppState s;
  late List<String> session;
  int i = 0;
  bool forward = true;
  bool multi = false;
  bool othersOpen = false;
  bool muted = true;
  bool paused = false;
  bool done = false;
  String? confirming;
  final picked = <String>[];
  final tagged = <String, int>{};
  int skippedN = 0;
  String? snack;
  bool snackUndo = false;
  Timer? _snackTimer;
  int? _undoIndex;
  late final AnimationController play = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    s = AppScope.of(context);
    if (!_started) {
      _started = true;
      session = List.of(s.toTag);
      i = session.indexOf(widget.startId).clamp(0, session.length - 1);
      _startClip();
    }
  }

  bool _started = false;

  VideoClip get clip => s.clips[session[i]]!;

  void _startClip() {
    play.duration = Duration(seconds: clip.durationSec.clamp(3, 600));
    play.forward(from: 0);
    paused = false;
  }

  @override
  void dispose() {
    play.dispose();
    _snackTimer?.cancel();
    super.dispose();
  }

  int _find(int from, int dir) {
    for (var j = from + dir; j >= 0 && j < session.length; j += dir) {
      if (s.toTag.contains(session[j])) return j;
    }
    return -1;
  }

  void _go(int j, {bool fwd = true}) {
    if (j < 0) return;
    setState(() {
      forward = fwd;
      i = j;
      multi = false;
      picked.clear();
      confirming = null;
    });
    _startClip();
  }

  void _advance() {
    var j = _find(i, 1);
    if (j < 0) j = _find(-1, 1);
    if (j < 0) {
      setState(() => done = true);
      play.stop();
      return;
    }
    _go(j);
  }

  void _showSnack(String text, {bool undo = false}) {
    _snackTimer?.cancel();
    setState(() {
      snack = text;
      snackUndo = undo;
    });
    _snackTimer = Timer(
      Duration(seconds: undo ? 6 : 4),
      () => mounted ? setState(() => snack = null) : null,
    );
  }

  void _tag(List<String> reelIds) {
    _undoIndex = i;
    s.tag([session[i]], reelIds);
    for (final r in reelIds) {
      tagged[r] = (tagged[r] ?? 0) + 1;
    }
    _advance();
    if (!done) {
      _showSnack(
        'Added to ${reelIds.map((r) => s.reel(r).name).join(', ')}',
        undo: true,
      );
    }
  }

  Future<void> _tapChip(String reelId) async {
    if (confirming != null) return;
    HapticFeedback.lightImpact();
    setState(() => confirming = reelId);
    final reduce = MediaQuery.of(context).disableAnimations;
    await Future<void>.delayed(Duration(milliseconds: reduce ? 120 : 400));
    if (mounted) _tag([reelId]);
  }

  void _skip() {
    HapticFeedback.selectionClick();
    _undoIndex = i;
    s.skip([session[i]]);
    skippedN++;
    _advance();
    if (!done) _showSnack('Skipped', undo: true);
  }

  void _undo() {
    s.undo();
    final back = _undoIndex;
    _snackTimer?.cancel();
    setState(() => snack = null);
    if (back != null) _go(back, fwd: false);
  }

  Future<void> _newReel() async {
    final id = await showNewReelSheet(
      context,
      subtitle: 'This clip will be added to it.',
    );
    if (id != null && mounted) _tag([id]);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (done) return _Done(session: session, tagged: tagged, skipped: skippedN);
    final scenes = s.scenes(session);
    final scIdx = scenes.indexWhere((sc) => sc.ids.contains(session[i]));
    final sc = scenes[scIdx];
    return SafeArea(
      child: Column(
        children: [
          _ProgressSegments(session: session, index: i, toTag: s.toTag),
          _TopBar(
            title: '${i + 1} of ${session.length}',
            subtitle:
                'Scene ${scIdx + 1} of ${scenes.length} · ${fmtRange(sc.start, sc.end)}',
            muted: muted,
            onClose: () => Navigator.of(context).pop(),
            onMute: () => setState(() => muted = !muted),
          ),
          Expanded(child: _stage()),
          _Scrubber(clip: clip, play: play),
          _quickRow(),
          _panel(),
        ],
      ),
    );
  }

  Widget _stage() {
    final c = clip;
    final hasPrev = _find(i, -1) >= 0, hasNext = _find(i, 1) >= 0;
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) _go(_find(i, 1));
        if (v > 300) _go(_find(i, -1), fwd: false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x8C000000),
                BlendMode.darken,
              ),
              child: Image.asset(c.thumb, fit: BoxFit.cover),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: Motion.medium2,
              switchInCurve: Motion.emphasizedDecelerate,
              switchOutCurve: Motion.emphasizedAccelerate,
              transitionBuilder: (child, a) {
                final incoming = child.key == ValueKey(c.id);
                final begin = Offset(
                  (incoming ? 0.7 : -0.7) * (forward ? 1 : -1),
                  0,
                );
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: begin, end: Offset.zero).animate(a),
                    child: child,
                  ),
                );
              },
              child: _Video(
                key: ValueKey(c.id),
                clip: c,
                play: play,
                paused: paused,
                onTap: () {
                  setState(() => paused = !paused);
                  paused ? play.stop() : play.forward();
                },
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _RoundBtn(
                icon: Symbols.chevron_left_rounded,
                label: 'Previous clip',
                onTap: hasPrev ? () => _go(_find(i, -1), fwd: false) : null,
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _RoundBtn(
                icon: Symbols.chevron_right_rounded,
                label: 'Next clip',
                onTap: hasNext ? () => _go(_find(i, 1)) : null,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: AnimatedSwitcher(
              duration: Motion.medium1,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: snack == null
                  ? const SizedBox.shrink()
                  : _InlineSnack(
                      key: ValueKey(snack),
                      text: snack!,
                      onUndo: snackUndo ? _undo : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickRow() {
    final prev = s.lastTags
        .where((r) => s.reels.any((x) => x.id == r))
        .toList();
    final names = prev.map((r) => s.reel(r).name).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: _skip,
            icon: const Icon(Symbols.redo_rounded, size: 18),
            label: const Text('Skip'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: prev.isEmpty
                  ? 'Same as previous'
                  : 'Same as previous: $names',
              button: true,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: prev.isEmpty ? null : () => _tag(prev),
                child: Row(
                  children: [
                    const Icon(Symbols.repeat_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Same as previous'),
                          if (prev.isNotEmpty)
                            Text(
                              names,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    final cs = context.cs;
    final ordered = s.orderedReels;
    final rec = ordered.where((r) => r.status == ReelStatus.recording).toList();
    final other = ordered
        .where((r) => r.status != ReelStatus.recording)
        .toList();
    final showOthers = othersOpen || rec.isEmpty;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    Widget grid(List<Widget> kids) => GridView.count(
      crossAxisCount: scale > 1.3 ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: (scale > 1.3 ? 320 : 160) / (56 * scale),
      children: kids,
    );
    _ReelChip chip(Reel r) => _ReelChip(
      reel: r,
      state: confirming == r.id
          ? _ChipState.done
          : multi && picked.contains(r.id)
          ? _ChipState.picked
          : _ChipState.normal,
      multi: multi,
      onTap: () => multi
          ? setState(
              () => picked.contains(r.id)
                  ? picked.remove(r.id)
                  : picked.add(r.id),
            )
          : _tapChip(r.id),
      onLongPress: multi
          ? null
          : () {
              HapticFeedback.mediumImpact();
              setState(() {
                multi = true;
                picked
                  ..clear()
                  ..add(r.id);
              });
            },
    );
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      constraints: const BoxConstraints(maxHeight: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    multi ? 'Pick reels for this clip' : 'Add to reel',
                    style: context.tt.titleSmall,
                  ),
                ),
                if (multi)
                  TextButton(
                    onPressed: () => setState(() => multi = false),
                    child: const Text('Cancel'),
                  )
                else if (s.reels.length > 1)
                  TextButton.icon(
                    onPressed: () => setState(() => multi = true),
                    icon: const Icon(
                      Symbols.library_add_check_rounded,
                      size: 18,
                    ),
                    label: const Text('Pick several'),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  grid([...rec.map(chip), _NewReelChip(onTap: _newReel)]),
                  if (other.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() => othersOpen = !othersOpen),
                      icon: Icon(
                        showOthers
                            ? Symbols.expand_less_rounded
                            : Symbols.expand_more_rounded,
                        size: 18,
                      ),
                      label: Text(
                        showOthers
                            ? 'Other reels'
                            : 'Other reels (${other.length})',
                      ),
                    ),
                  if (showOthers) grid(other.map(chip).toList()),
                ],
              ),
            ),
          ),
          if (multi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: picked.isEmpty
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _tag(List.of(picked));
                        },
                  child: Text(
                    picked.isEmpty
                        ? 'Pick one or more reels'
                        : 'Add to ${plural(picked.length, 'reel')} & next',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ parts */

class _Video extends StatelessWidget {
  const _Video({
    super.key,
    required this.clip,
    required this.play,
    required this.paused,
    required this.onTap,
  });
  final VideoClip clip;
  final AnimationController play;
  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label:
          '${paused ? 'Play' : 'Pause'} clip, ${fmtTime(clip.at)}, ${fmtDur(clip.durationSec)}',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: clip.horizontal ? 16 / 9 : 9 / 16,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: clip.horizontal ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Stand-in for video playback: a slow push-in over the clip's length.
                AnimatedBuilder(
                  animation: play,
                  builder: (_, child) => Transform.scale(
                    scale: reduce ? 1 : 1 + 0.12 * play.value,
                    alignment: const Alignment(0, -0.2),
                    child: child,
                  ),
                  child: Image.asset(clip.thumb, fit: BoxFit.cover),
                ),
                if (paused)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.play_arrow_rounded,
                        fill: 1,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({
    required this.session,
    required this.index,
    required this.toTag,
  });
  final List<String> session;
  final int index;
  final List<String> toTag;

  @override
  Widget build(BuildContext context) {
    final waiting = context.cs.tertiaryContainer;
    Color col(int k) => k == index
        ? Colors.white
        : !toTag.contains(session[k])
        ? waiting
        : Colors.white24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: SizedBox(
        height: 3,
        child: session.length <= 40
            ? Row(
                children: [
                  for (var k = 0; k < session.length; k++) ...[
                    if (k > 0) const SizedBox(width: 2),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: col(k),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : LinearProgressIndicator(
                value: (index + 1) / session.length,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.muted,
    required this.onClose,
    required this.onMute,
  });
  final String title, subtitle;
  final bool muted;
  final VoidCallback onClose, onMute;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close tagging',
          onPressed: onClose,
          icon: const Icon(Symbols.close_rounded, color: Colors.white),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: context.tt.titleSmall?.copyWith(
                    color: Colors.white,
                    fontFeatures: tabularFigures,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.tt.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: muted ? 'Unmute' : 'Mute',
          isSelected: !muted,
          onPressed: onMute,
          icon: Icon(
            muted ? Symbols.volume_off_rounded : Symbols.volume_up_rounded,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.clip, required this.play});
  final VideoClip clip;
  final AnimationController play;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: fontFamily,
      color: Colors.white70,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
      fontFeatures: tabularFigures,
    );
    return AnimatedBuilder(
      animation: play,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            Text(fmtDur((clip.durationSec * play.value).round()), style: style),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: play.value,
                  minHeight: clip.durationSec > 120 ? 6 : 4,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(fmtDur(clip.durationSec), style: style),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.3 : 1,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    ),
  );
}

class _InlineSnack extends StatelessWidget {
  const _InlineSnack({super.key, required this.text, this.onUndo});
  final String text;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(
              Symbols.check_circle_rounded,
              fill: 1,
              size: 20,
              color: cs.inversePrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: context.tt.bodyMedium?.copyWith(
                  color: cs.onInverseSurface,
                ),
              ),
            ),
            if (onUndo != null)
              TextButton(
                onPressed: onUndo,
                style: TextButton.styleFrom(foregroundColor: cs.inversePrimary),
                child: const Text('Undo'),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ChipState { normal, picked, done }

class _ReelChip extends StatelessWidget {
  const _ReelChip({
    required this.reel,
    required this.state,
    required this.multi,
    required this.onTap,
    this.onLongPress,
  });
  final Reel reel;
  final _ChipState state;
  final bool multi;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    final cover = s.coverOf(reel.id);
    final n = s.clipsOf(reel.id).length;
    final (bg, fg) = switch (state) {
      _ChipState.done => (cs.primary, cs.onPrimary),
      _ChipState.picked => (cs.primaryContainer, cs.onPrimaryContainer),
      _ChipState.normal => (cs.surfaceContainerHighest, cs.onSurface),
    };
    return Semantics(
      label: '${multi ? '' : 'Add to '}${reel.name}, ${plural(n, 'clip')}',
      checked: multi ? state == _ChipState.picked : null,
      child: AnimatedScale(
        scale: state == _ChipState.done ? 0.97 : 1,
        duration: Motion.short3,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: state == _ChipState.picked
                ? BorderSide(color: cs.primary)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.small),
                    child: SizedBox(
                      width: 34,
                      height: 44,
                      child: state == _ChipState.done
                          ? ColoredBox(
                              color: cs.onPrimary,
                              child: Icon(
                                Symbols.check_rounded,
                                weight: 700,
                                color: cs.primary,
                              ),
                            )
                          : cover == null
                          ? ColoredBox(
                              color: cs.surfaceContainerHigh,
                              child: Icon(
                                Symbols.movie_rounded,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            )
                          : Image.asset(cover.thumb, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelLarge?.copyWith(color: fg),
                        ),
                        Text(
                          plural(n, 'clip'),
                          style: context.tt.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (multi)
                    Icon(
                      state == _ChipState.picked
                          ? Symbols.check_box_rounded
                          : Symbols.check_box_outline_blank_rounded,
                      fill: state == _ChipState.picked ? 1 : 0,
                      color: state == _ChipState.picked
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewReelChip extends StatelessWidget {
  const _NewReelChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outline, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(Radii.small),
                ),
                child: Icon(
                  Symbols.add_rounded,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New reel',
                      style: context.tt.labelLarge?.copyWith(color: cs.primary),
                    ),
                    Text(
                      'Add this clip to it',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.session,
    required this.tagged,
    required this.skipped,
  });
  final List<String> session;
  final Map<String, int> tagged;
  final int skipped;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tc = context.tc;
    final sorted = session.where((id) => !s.toTag.contains(id)).length;
    final row = context.tt.bodyMedium!.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
    );
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: Motion.long2,
                curve: Motion.emphasizedDecelerate,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: tc.successColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.check_rounded,
                    size: 48,
                    color: tc.successOnColor,
                    weight: 600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All done!',
                style: context.tt.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${plural(sorted, 'clip')} sorted. Nice work.',
                style: context.tt.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    for (final e in tagged.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(s.reel(e.key).name, style: row),
                            ),
                            Text(
                              '+${e.value}',
                              style: weight(
                                row,
                                700,
                              ).copyWith(fontFeatures: tabularFigures),
                            ),
                          ],
                        ),
                      ),
                    if (skipped > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text('Skipped', style: row)),
                            Text('$skipped', style: weight(row, 700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
                onPressed: () {
                  Navigator.of(context).pop();
                  s.setTab(0);
                },
                child: const Text('See your reels'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Back to To tag'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
