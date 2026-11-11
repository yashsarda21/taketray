import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// What the grid hands the folder list when it closes for a reason to leave
/// Add videos altogether (access lost, the target reel deleted): the folder
/// list closes too. A plain Back hands nothing, and an add its `AddResult`.
const Object addVideosLeave = _Leave();

final class _Leave {
  const _Leave();
}

/// Calls [leave] when Add videos can no longer go on (D-114): the access the
/// app reads becomes anything but full, or the target reel is deleted.
///
/// Called from a screen's `build`. [leave] runs in a microtask, never in the
/// middle of a build, and decides itself whether its screen is the one to
/// close.
void leaveWhenAddVideosEnds(
  WidgetRef ref,
  AddTarget target,
  VoidCallback leave,
) {
  ref.listen(mediaAccessControllerProvider, (_, next) {
    final level = next.value?.level;
    if (level != null && level != MediaAccessLevel.full) {
      scheduleMicrotask(leave);
    }
  });
  if (target case AddToReel(:final reelId)) {
    ref.listen(reelByIdProvider(reelId), (_, next) {
      if (next.hasValue && next.value == null) scheduleMicrotask(leave);
    });
  }
}

/// The line under Add videos' title: "to To tag", or "to {reel}" once the
/// reel's name is known (null until then).
String? addVideosTargetText(
  BuildContext context,
  WidgetRef ref,
  AddTarget target,
) {
  final l10n = AppLocalizations.of(context);
  return switch (target) {
    AddToToTag() => l10n.addVideosToToTag,
    AddToReel(:final reelId) => switch (ref
        .watch(reelByIdProvider(reelId))
        .value) {
      final reel? => l10n.addVideosToReel(reel.name),
      null => null,
    },
  };
}
