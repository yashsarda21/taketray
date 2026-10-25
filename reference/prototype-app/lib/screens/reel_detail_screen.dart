import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';
import '../widgets/common.dart';

/// Reel detail (first pass): header, shot ideas, references, clips by day, oldest first.
class ReelDetailScreen extends StatelessWidget {
  const ReelDetailScreen({super.key, required this.reelId});
  final String reelId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = context.cs;
    final reel = s.reel(reelId);
    final clips = s.clipsOf(reelId);
    final live = clips.where((c) => !c.missing);
    final days = <DateTime, List<String>>{};
    for (final c in clips) {
      days
          .putIfAbsent(DateTime(c.at.year, c.at.month, c.at.day), () => [])
          .add(c.id);
    }
    final first = days.keys.isEmpty ? null : days.keys.first;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Add videos',
            onPressed: () {},
            icon: const Icon(Symbols.library_add_rounded),
          ),
          IconButton(
            tooltip: 'More options',
            onPressed: () {},
            icon: const Icon(Symbols.more_vert_rounded),
          ),
        ],
      ),
      floatingActionButton: clips.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-reel',
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit video: next to build')),
              ),
              icon: const Icon(Symbols.movie_edit_rounded),
              label: const Text('Edit video'),
            ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reel.name, style: context.tt.headlineSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(reel.status),
                      Text(
                        clips.isEmpty
                            ? 'No clips yet'
                            : '${plural(clips.length, 'clip')} · ${fmtDur(s.totalSec(live))}',
                        style: context.tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (reel.desc.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  4,
                  Space.gutter,
                  8,
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.large),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Symbols.lightbulb_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Shot ideas',
                          style: context.tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(reel.desc, style: context.tt.bodyMedium),
                  ],
                ),
              ),
            ),
          if (reel.refs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter + 4,
                  8,
                  Space.gutter,
                  4,
                ),
                child: Text(
                  'References · ${reel.refs.length}',
                  style: context.tt.titleSmall,
                ),
              ),
            ),
          for (final r in reel.refs)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  4,
                  Space.gutter,
                  4,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.large),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(Radii.small),
                    ),
                    child: Icon(
                      Symbols.play_arrow_rounded,
                      fill: 1,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    r.label.isEmpty
                        ? r.url.replaceFirst(RegExp(r'^https?://(www\.)?'), '')
                        : r.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r.url.contains('instagram.com')
                        ? 'Instagram'
                        : r.url.contains('youtu')
                        ? 'YouTube'
                        : 'Link',
                  ),
                  trailing: Icon(
                    Symbols.open_in_new_rounded,
                    color: cs.primary,
                  ),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opens in Instagram')),
                  ),
                ),
              ),
            ),
          for (final e in days.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  20,
                  Space.gutter,
                  6,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            'Day ${e.key.difference(first!).inDays + 1} · ${fmtDay(e.key)}  ',
                        style: context.tt.titleMedium,
                      ),
                      TextSpan(
                        text: plural(e.value.length, 'clip'),
                        style: context.tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
                  childCount: e.value.length,
                  (context, i) =>
                      ClipTile(clip: s.clips[e.value[i]]!, onTap: () {}),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
