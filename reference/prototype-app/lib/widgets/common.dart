import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import 'tt.dart';

/* ------------------------------------------------------------ formatting */
const _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtHm(DateTime t) =>
    '${((t.hour + 11) % 12) + 1}:${t.minute.toString().padLeft(2, '0')}';
String fmtAmPm(DateTime t) => t.hour < 12 ? 'am' : 'pm';
String fmtTime(DateTime t) => '${fmtHm(t)} ${fmtAmPm(t)}';
String fmtRange(DateTime a, DateTime b) {
  if (b.difference(a).inMinutes < 1) return fmtTime(a);
  return fmtAmPm(a) == fmtAmPm(b)
      ? '${fmtHm(a)}–${fmtHm(b)} ${fmtAmPm(b)}'
      : '${fmtTime(a)}–${fmtTime(b)}';
}

String fmtDay(DateTime t) =>
    '${_dow[t.weekday - 1]} ${t.day} ${_mon[t.month - 1]}';
String fmtDur(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '$m:${s.toString().padLeft(2, '0')}';
}

String fmtMins(int sec) => sec < 60
    ? '$sec s'
    : (sec / 60).round() < 60
    ? '${(sec / 60).round()} min'
    : '${sec ~/ 3600} h ${(sec % 3600) ~/ 60} min';
String plural(int n, String word, [String? many]) =>
    '$n ${n == 1 ? word : many ?? '${word}s'}';

/* --------------------------------------------------------------- status */
({String label, IconData icon}) statusInfo(ReelStatus s) => switch (s) {
  ReelStatus.recording => (
    label: 'Recording',
    icon: Symbols.radio_button_checked_rounded,
  ),
  ReelStatus.ready => (
    label: 'Ready to edit',
    icon: Symbols.content_cut_rounded,
  ),
  ReelStatus.published => (
    label: 'Published',
    icon: Symbols.check_circle_rounded,
  ),
};

/// Status is always icon + word, never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final ReelStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, tc = context.tc;
    final (bg, fg, ic) = switch (status) {
      ReelStatus.recording => (
        tc.recordColorContainer,
        tc.recordOnColorContainer,
        tc.recordColor,
      ),
      ReelStatus.ready => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        cs.onPrimaryContainer,
      ),
      ReelStatus.published => (
        tc.successColorContainer,
        tc.successOnColorContainer,
        tc.successOnColorContainer,
      ),
    };
    final i = statusInfo(status);
    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i.icon, size: 16, color: ic, fill: 1),
          const SizedBox(width: 4),
          Text(i.label, style: context.tt.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Small dark badge used on top of video thumbnails.
class ThumbBadge extends StatelessWidget {
  const ThumbBadge({super.key, required this.icon, this.text});
  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: EdgeInsets.symmetric(horizontal: text == null ? 4 : 6),
    decoration: BoxDecoration(
      color: const Color(0xB8100E16),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white, fill: 1),
        if (text != null) ...[
          const SizedBox(width: 2),
          Text(
            text!,
            style: const TextStyle(
              fontFamily: fontFamily,
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontVariations: [FontVariation('wght', 700)],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Clip tile: 3:4, time bottom-left, duration bottom-right, "in N reels" badge, selection state.
class ClipTile extends StatelessWidget {
  const ClipTile({
    super.key,
    required this.clip,
    this.onTap,
    this.onLongPress,
    this.selected,
  });
  final VideoClip clip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    if (clip.missing) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.small),
          border: Border.all(color: cs.outline, style: BorderStyle.solid),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.videocam_off_rounded, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              'Missing from phone',
              textAlign: TextAlign.center,
              style: context.tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final sel = selected == true;
    final label =
        'Clip, ${fmtTime(clip.at)}, ${fmtDur(clip.durationSec)}${clip.horizontal ? ', horizontal' : ''}${clip.reels.length > 1 ? ', in ${clip.reels.length} reels' : ''}';
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Material(
        color: sel ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                scale: sel ? 0.86 : 1,
                duration: Motion.short4,
                curve: Motion.standard,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(sel ? 12 : 0),
                  child: Image.asset(clip.thumb, fit: BoxFit.cover),
                ),
              ),
              if (!sel)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.1),
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xA8000000)],
                    ),
                  ),
                ),
              if (!sel)
                Positioned(
                  left: 7,
                  right: 7,
                  bottom: 5,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontFamily: fontFamily,
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation('wght', 700)],
                      fontFeatures: tabularFigures,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            fmtTime(clip.at),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(fmtDur(clip.durationSec)),
                      ],
                    ),
                  ),
                ),
              if (clip.reels.length > 1)
                Positioned(
                  left: 5,
                  top: 5,
                  child: ThumbBadge(
                    icon: Symbols.layers_rounded,
                    text: '${clip.reels.length}',
                  ),
                ),
              if (clip.horizontal && clip.reels.length <= 1)
                const Positioned(
                  right: 5,
                  top: 5,
                  child: ThumbBadge(icon: Symbols.crop_16_9_rounded),
                ),
              if (selected != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? cs.primary : Colors.black26,
                      border: Border.all(
                        color: sel ? cs.primary : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: sel
                        ? Icon(
                            Symbols.check_rounded,
                            size: 18,
                            color: cs.onPrimary,
                            weight: 700,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reel card (TakeTray style): full-bleed cover with the name on the image, glass status pill,
/// VN and reference badges. The reference badge is its own tap target.
class ReelCard extends StatelessWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.onTap,
    this.onRefs,
  });
  final Reel reel;
  final VoidCallback onTap;
  final VoidCallback? onRefs;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    final clips = s.clipsOf(reel.id);
    final live = clips.where((c) => !c.missing);
    final missing = clips.length - live.length;
    final cover = s.coverOf(reel.id);
    final onImage = cover != null;
    final nameColor = onImage ? Colors.white : cs.onSurface;
    final metaColor = onImage
        ? Colors.white.withValues(alpha: 0.82)
        : cs.onSurfaceVariant;
    final st = statusInfo(reel.status);
    final stColor = switch (reel.status) {
      ReelStatus.recording => const Color(0xFFFF888C),
      ReelStatus.ready => brandSchemes[s.brand]!.dark.primary,
      ReelStatus.published => const Color(0xFF89D7A0),
    };
    return Semantics(
      button: true,
      label:
          '${reel.name}. ${st.label}. ${plural(clips.length, 'clip')}${missing > 0 ? ', $missing missing' : ''}${reel.vn != null ? '. Editing in VN' : ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (onImage)
              Image.asset(cover.thumb, fit: BoxFit.cover)
            else
              ColoredBox(color: cs.surfaceContainerHigh),
            if (onImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, -0.2),
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              )
            else
              Align(
                alignment: const Alignment(0, -0.25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.movie_rounded,
                      size: 32,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No clips yet',
                      style: context.tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: GlassPill(
                  icon: st.icon,
                  iconColor: stColor,
                  text: st.label,
                ),
              ),
            ),
            if (reel.vn != null)
              Positioned(
                left: 8,
                top: 38,
                child: IgnorePointer(
                  child: GlassPill(
                    icon: Symbols.folder_copy_rounded,
                    iconColor: Colors.white,
                    text: 'Editing in VN',
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: reel.refs.isNotEmpty ? 50 : 12,
              bottom: 11,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: weight(context.tt.titleSmall!, 700).copyWith(
                        fontSize: 15,
                        height: 19 / 15,
                        color: nameColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          clips.isEmpty
                              ? '0 clips'
                              : '${plural(clips.length, 'clip')} · ${fmtDur(s.totalSec(live))}',
                          style: context.tt.bodySmall?.copyWith(
                            color: metaColor,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        if (missing > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.error_rounded,
                                size: 14,
                                color: onImage
                                    ? const Color(0xFFFFB4AB)
                                    : cs.error,
                                fill: 1,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$missing missing',
                                style: weight(context.tt.bodySmall!, 600)
                                    .copyWith(
                                      color: onImage
                                          ? const Color(0xFFFFB4AB)
                                          : cs.error,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (reel.refs.isNotEmpty)
              Positioned(
                right: 4,
                bottom: 4,
                child: Semantics(
                  button: true,
                  label:
                      '${plural(reel.refs.length, 'reference')} in ${reel.name}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onRefs ?? onTap,
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: GlassPill(
                        icon: Symbols.link_rounded,
                        iconColor: Colors.white,
                        text: '${reel.refs.length}',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing REC dot (static with reduced motion).
class RecDot extends StatefulWidget {
  const RecDot({super.key, this.size = 10, this.ring});
  final double size;
  final Color? ring;

  @override
  State<RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = context.tc.recordColor;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOut.transform((_c.value / 0.6).clamp(0, 1));
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red,
            boxShadow: [
              if (widget.ring != null)
                BoxShadow(color: widget.ring!, spreadRadius: 2),
              BoxShadow(
                color: red.withValues(alpha: 0.6 * (1 - t)),
                spreadRadius: 7 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
