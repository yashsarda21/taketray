import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart';

/// The scrubber under a clip's video (the clip viewer and the tag player): the
/// time so far, the length, and seek, on the open [controller] of [clip].
///
/// Before the player has opened the video (a null [controller]) or when it
/// cannot (an error, no length) it shows 0:00 and the clip's own length, and
/// does not seek. [large] and [hint] are for long clips (the tag player's
/// "Drag to skim").
class ClipScrubber extends StatelessWidget {
  const new({
    required this.controller,
    required this.clip,
    this.large = false,
    this.hint,
    super.key,
  });

  final VideoPlayerController? controller;
  final Clip clip;
  final bool large;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final l10n = AppLocalizations.of(context);
    final fallback = formatClipDuration(clip.fingerprint.durationMs);
    if (player == null) {
      return TtScrubBar(
        progress: 0,
        positionText: formatClipDuration(0),
        durationText: fallback,
        semanticLabel: l10n.viewerScrubLabel,
        semanticValue: l10n.viewerScrubValue(formatClipDuration(0), fallback),
        large: large,
        hint: hint,
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) {
        final length = value.duration.inMilliseconds;
        final ready = value.isInitialized && !value.hasError && length > 0;
        final position = value.position.inMilliseconds;
        final durationText = ready ? formatClipDuration(length) : fallback;
        // What a screen reader hears after a 5 % step either way (the bar
        // does the stepping, `TtMetrics.scrubSemanticStep`).
        int stepped(double by) =>
            ((position / length + by).clamp(0.0, 1.0) * length).round();
        String valueAt(int ms) =>
            l10n.viewerScrubValue(formatClipDuration(ms), durationText);
        return TtScrubBar(
          progress: ready ? position / length : 0,
          positionText: formatClipDuration(position),
          durationText: durationText,
          semanticLabel: l10n.viewerScrubLabel,
          semanticValue: valueAt(position),
          semanticIncreasedValue: ready
              ? valueAt(stepped(TtMetrics.scrubSemanticStep))
              : null,
          semanticDecreasedValue: ready
              ? valueAt(stepped(-TtMetrics.scrubSemanticStep))
              : null,
          large: large,
          hint: hint,
          onSeek: ready
              ? (fraction) => unawaited(
                  player.seekTo(
                    Duration(milliseconds: (length * fraction).round()),
                  ),
                )
              : null,
        );
      },
    );
  }
}
