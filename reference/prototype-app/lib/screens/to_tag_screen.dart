import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/common.dart';
import '../widgets/tt.dart';
import 'tag_player_screen.dart';

class ToTagScreen extends StatelessWidget {
  const ToTagScreen({super.key});

  void _play(BuildContext context, String fromId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Motion.medium2,
        pageBuilder: (_, _, _) => TagPlayerScreen(startId: fromId),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    final scenes = s.scenes(s.toTag);
    final total = s.totalSec(s.toTag.map((id) => s.clips[id]!));
    return Scaffold(
      floatingActionButton: s.toTag.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(
                bottom: 80,
              ), // above the floating navigation pill
              child: FloatingActionButton.extended(
                heroTag: 'fab-totag',
                onPressed: () => _play(context, s.toTag.first),
                icon: const Icon(Symbols.play_arrow_rounded, fill: 1),
                label: const Text('Start tagging'),
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
                  4,
                ),
                child: Text('To tag', style: pageTitle(context)),
              ),
            ),
          ),
          if (s.shootingOn)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, 8, 0),
                child: Row(
                  children: [
                    const RecDot(size: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shooting since ${fmtTime(s.shootingSince)}',
                        style: context.tt.labelLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Symbols.videocam_rounded, size: 18),
                      label: const Text('Open camera'),
                    ),
                  ],
                ),
              ),
            ),
          if (s.toTag.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.check_circle_rounded,
                      size: 72,
                      fill: 1,
                      color: context.tc.successColor,
                    ),
                    const SizedBox(height: 16),
                    Text('All caught up', style: context.tt.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'New clips you shoot will show up here.',
                      textAlign: TextAlign.center,
                      style: context.tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  8,
                  Space.gutter,
                  0,
                ),
                child: Text(
                  '${plural(s.toTag.length, 'clip')} · ${plural(scenes.length, 'scene')} · ${fmtMins(total)}',
                  style: context.tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            for (final sc in scenes) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    16,
                    Space.gutter,
                    8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmtRange(sc.start, sc.end),
                              style: context.tt.titleSmall?.copyWith(
                                fontFeatures: tabularFigures,
                              ),
                            ),
                            Text(
                              '${plural(sc.ids.length, 'clip')} · ${fmtDur(s.totalSec(sc.ids.map((id) => s.clips[id]!)))}',
                              style: context.tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => showTagSceneSheet(context, sc.ids),
                        icon: const Icon(Symbols.sell_rounded, size: 18),
                        label: const Text('Tag scene'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: Space.gridGap,
                    mainAxisSpacing: Space.gridGap,
                    childAspectRatio: 3 / 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: sc.ids.length,
                    (context, i) => ClipTile(
                      clip: s.clips[sc.ids[i]]!,
                      onTap: () => _play(context, sc.ids[i]),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ],
      ),
    );
  }
}

/// Reel picker for "Tag scene": multi-select, Recording reels first; the button says what happens.
Future<void> showTagSceneSheet(
  BuildContext context,
  List<String> clipIds,
) async {
  final s = AppScope.of(context);
  final picked = <String>{};
  final messenger = ScaffoldMessenger.of(context);
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final reels = s.orderedReels;
        Widget row(Reel r) {
          final c = s.coverOf(r.id);
          final on = picked.contains(r.id);
          return CheckboxListTile(
            value: on,
            onChanged: (_) =>
                set(() => on ? picked.remove(r.id) : picked.add(r.id)),
            secondary: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.small),
              child: SizedBox(
                width: 40,
                height: 52,
                child: c == null
                    ? ColoredBox(
                        color: ctx.cs.surfaceContainerHigh,
                        child: const Icon(Symbols.movie_rounded),
                      )
                    : Image.asset(c.thumb, fit: BoxFit.cover),
              ),
            ),
            title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(plural(s.clipsOf(r.id).length, 'clip')),
          );
        }

        final rec = reels.where((r) => r.status == ReelStatus.recording);
        final other = reels.where((r) => r.status != ReelStatus.recording);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (ctx, scroll) => FloatingSheet(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag ${plural(clipIds.length, 'clip')}',
                        style: ctx.tt.titleLarge,
                      ),
                      Text(
                        'Pick one or more reels.',
                        style: ctx.tt.bodyMedium?.copyWith(
                          color: ctx.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: [
                      _head(ctx, 'Recording'),
                      ...rec.map(row),
                      _head(ctx, 'Other reels'),
                      ...other.map(row),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: picked.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, true),
                            child: Text(
                              picked.length > 1
                                  ? 'Tag into ${picked.length} reels'
                                  : 'Tag ${plural(clipIds.length, 'clip')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (done == true) {
    final names = picked.map((id) => s.reel(id).name).join(' and ');
    s.tag(clipIds, picked.toList());
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text('${plural(clipIds.length, 'clip')} added to $names'),
        action: SnackBarAction(label: 'Undo', onPressed: s.undo),
      ),
    );
  }
}

Widget _head(BuildContext ctx, String t) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
  child: Text(t, style: ctx.tt.titleSmall?.copyWith(color: ctx.cs.primary)),
);
