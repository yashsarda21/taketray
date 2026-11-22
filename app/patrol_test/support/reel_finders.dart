import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Finders for the references flows (D-161) that a Patrol tap or wait can
/// rely on, on the phone as in a widget test (`reel_finders_test.dart`).

/// The references badge of the Home card named [reelName], by the words a
/// screen reader says for it ([semanticLabel], `reelCardReferences`).
///
/// Not the count's text: the badge's ripple lies over it, so the text is
/// never hit-testable and a Patrol tap on it waits until it times out (the
/// S24, 2026-11-22). The badge's own button is what a finger reaches.
Finder referencesBadgeOf(String reelName, String semanticLabel) =>
    find.descendant(
      of: find.ancestor(
        of: find.text(reelName),
        matching: find.byType(TtReelCard),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == semanticLabel,
        description: 'the references badge "$semanticLabel"',
      ),
    );

/// The page of the reel [reelId], by its id.
///
/// Not by the reel's name: opened at its References (the Home badge, the
/// Shooting mode sheet's header), the page scrolls its header, with the name,
/// off the screen, and a finder skips a sliver that is off the screen.
/// [reelName] is only for the description.
Finder reelPageOf(int reelId, String reelName) => find.byWidgetPredicate(
  (w) => w is ReelDetailScreen && w.reelId == reelId,
  description: 'the page of "$reelName"',
);
