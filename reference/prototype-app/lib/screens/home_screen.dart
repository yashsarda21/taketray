import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/common.dart';
import '../widgets/tt.dart';
import 'reel_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ReelStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.reelsNewestFirst
        .where((r) => _filter == null || r.status == _filter)
        .toList();
    final counts = {
      for (final st in ReelStatus.values)
        st: s.reels.where((r) => r.status == st).length,
    };
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 80,
        ), // above the floating navigation pill
        child: FloatingActionButton.extended(
          heroTag: 'fab-home',
          onPressed: () => showNewReelSheet(context),
          icon: const Icon(Symbols.add_rounded),
          label: const Text('New reel'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  20,
                  Space.gutter,
                  12,
                ),
                child: Text('Reels', style: pageTitle(context)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: ShootingCard()),
          SliverToBoxAdapter(
            child: PillTabs<ReelStatus?>(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
              items: [
                (null, 'All  ${s.reels.length}'),
                for (final st in ReelStatus.values)
                  (st, '${statusInfo(st).label}  ${counts[st]}'),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              4,
              Space.gutter,
              120,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, c) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final cols = scale >= 1.5 ? 1 : 2;
                final w = (c.crossAxisExtent - 12 * (cols - 1)) / cols;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: w * 5 / 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: list.length,
                    (context, i) => ReelCard(
                      reel: list[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReelDetailScreen(reelId: list[i].id),
                        ),
                      ),
                      onRefs: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReelDetailScreen(reelId: list[i].id),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The first thing on Home. Off: a quiet card. On (TakeTray style): a media hero with your
/// latest clip behind a brand tint, a live REC dot, Open camera, References and the waiting strip.
class ShootingCard extends StatelessWidget {
  const ShootingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = s.shootingOn;
    final n = s.toTag.length;
    final refs = s.recordingRefCount;
    // Component token: primary in light, primaryContainer in dark (no big bright blocks at night).
    final tint = dark ? cs.primaryContainer : cs.primary;
    final latest = s.toTag.isNotEmpty
        ? s.clips[s.toTag.last]
        : s.clips.values.where((c) => !c.missing).firstOrNull;
    final fg = on ? Colors.white : cs.onSurface;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: on
                      ? Colors.white.withValues(alpha: 0.16)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Symbols.videocam_rounded,
                  fill: 1,
                  color: on ? Colors.white : cs.onPrimaryContainer,
                ),
              ),
              if (on)
                const Positioned(
                  right: 5,
                  top: 5,
                  child: RecDot(ring: Colors.black),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on ? 'Shooting mode on' : 'Shooting mode',
                  style: on
                      ? weight(context.tt.titleMedium!, 800).copyWith(
                          fontSize: 19,
                          height: 24 / 19,
                          letterSpacing: -0.3,
                          color: fg,
                        )
                      : context.tt.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  on ? 'On since ${fmtTime(s.shootingSince)}' : 'Off. Turn on before you start filming, and new videos wait in To tag.',
                  style: context.tt.bodyMedium?.copyWith(
                    color: on
                        ? Colors.white.withValues(alpha: 0.85)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Shooting mode',
            child: Switch(
              value: on,
              onChanged: (_) => s.toggleShooting(),
              activeThumbColor: Colors.black,
              activeTrackColor: Colors.white,
              thumbIcon: WidgetStateProperty.resolveWith(
                (st) => st.contains(WidgetState.selected)
                    ? const Icon(Symbols.check_rounded, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (on)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111111),
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opens your camera app')),
                ),
                icon: const Icon(Symbols.videocam_rounded, size: 18),
                label: const Text('Open camera'),
              ),
            ),
          ),
        if (on && refs > 0)
          Material(
            color: Colors.black.withValues(alpha: 0.25),
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('References sheet: next to build'),
                ),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Symbols.link_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'References · $refs',
                        style: context.tt.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Symbols.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (on && n > 0)
          Material(
            color: cs.tertiaryContainer,
            child: InkWell(
              onTap: () => s.setTab(1),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  children: [
                    Icon(
                      Symbols.sell_rounded,
                      fill: 1,
                      color: cs.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${plural(n, 'clip')} to tag',
                        style: context.tt.titleSmall?.copyWith(
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                    Text(
                      'Tag now',
                      style: context.tt.labelLarge?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Symbols.arrow_forward_rounded,
                      color: cs.onTertiaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 4, Space.gutter, 4),
      child: AnimatedContainer(
        duration: Motion.medium2,
        curve: Motion.standard,
        decoration: BoxDecoration(
          color: on ? Colors.black : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          border: on ? null : Border.all(color: hairline(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (on && latest != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.62,
                  child: Image.asset(latest.thumb, fit: BoxFit.cover),
                ),
              ),
            if (on)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.withValues(alpha: 0.78),
                        tint.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// New reel bottom sheet: name (required, 40 characters).
Future<String?> showNewReelSheet(BuildContext context, {String? subtitle}) {
  final s = AppScope.of(context);
  final ctrl = TextEditingController();
  String? err;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        void save() {
          final e = s.validateName(ctrl.text);
          if (e != null) return setSheet(() => err = e);
          final id = s.newReel(ctrl.text);
          Navigator.of(ctx).pop(id);
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: FloatingSheet(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New reel', style: ctx.tt.titleLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: ctx.tt.bodyMedium?.copyWith(
                          color: ctx.cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => save(),
                    decoration: InputDecoration(
                      labelText: 'Reel name',
                      hintText: 'For example: London Food',
                      errorText: err,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: save,
                        child: Text(
                          subtitle != null ? 'Create and add' : 'Create reel',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
