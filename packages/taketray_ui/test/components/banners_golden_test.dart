import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of a callout in a page with 16 dp margins.
const _callout = 328.0;

TtBanner _banner(TtBannerKind kind, {bool action = false}) {
  final (icon, title, body, label) = switch (kind) {
    TtBannerKind.warning => (
      Symbols.no_photography_rounded,
      "TakeTray can't see your videos",
      'Allow access to find new clips.',
      'Allow',
    ),
    TtBannerKind.info => (
      Symbols.lock_rounded,
      'Manual mode',
      "New clips aren't found automatically.",
      'Allow full access',
    ),
    TtBannerKind.attention => (
      Symbols.sell_rounded,
      '3 clips to tag',
      '4 min of video waiting',
      '',
    ),
    TtBannerKind.vn => (
      Symbols.folder_copy_rounded,
      'Editing in VN · 84 MB',
      '7 copies in Movies/TakeTray/London Food',
      '',
    ),
  };
  return TtBanner(
    kind: kind,
    icon: icon,
    title: title,
    body: body,
    // The prototype fills the icon of "clips to tag" and leaves the icons of
    // Manual mode and "can't see your videos" outlined (screens.js, app.js).
    iconFilled: kind == TtBannerKind.attention || kind == TtBannerKind.vn,
    onTap: kind == TtBannerKind.attention && !action ? () {} : null,
    action: action
        ? kind == TtBannerKind.vn
              ? _vnActions()
              : TtButton(
                  label: kind == TtBannerKind.attention ? 'Open' : label,
                  kind: TtButtonKind.text,
                  onPressed: () {},
                )
        : null,
  );
}

Widget _vnActions() => Wrap(
  spacing: 4,
  children: [
    TtButton(label: 'Done editing', size: TtButtonSize.small, onPressed: () {}),
    TtButton(
      label: 'Add more clips',
      size: TtButtonSize.small,
      kind: TtButtonKind.text,
      onPressed: () {},
    ),
  ],
);

void main() {
  ttGoldenTest(
    'Banners',
    fileName: 'banners',
    scenarios: [
      for (final kind in TtBannerKind.values) ...[
        TtScenario('${kind.name}, no action', _banner(kind)),
        TtScenario('${kind.name}, with action', _banner(kind, action: true)),
      ],
      TtScenario(
        'long text',
        TtBanner(
          kind: TtBannerKind.warning,
          icon: Symbols.info_rounded,
          title: 'Already saved in Autumn recipes from the old town market',
          body: 'Pick another reel, or open the one it is already saved in.',
          action: TtButton(
            label: 'Open reel',
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
      ),
    ],
  );

  ttGoldenTest(
    'Callouts and info bar',
    fileName: 'callouts',
    scenarios: [
      const TtScenario(
        'callout',
        TtCallout(
          icon: Symbols.shield_rounded,
          title: 'Your videos stay on your phone',
          body:
              'TakeTray only reads them. It never uploads, moves or deletes '
              'them.',
        ),
        width: _callout,
      ),
      const TtScenario(
        'callout, warning',
        TtCallout(
          icon: Symbols.info_rounded,
          title: 'Moving to a new phone?',
          body:
              "That isn't supported yet. A backup only links to videos on "
              'this phone.',
          warning: true,
        ),
        width: _callout,
      ),
      const TtScenario(
        'callout, rich body',
        TtCallout(
          icon: Symbols.info_rounded,
          title: 'Want new clips found for you?',
          richBody: TextSpan(
            children: [
              TextSpan(text: 'Choose '),
              TextSpan(
                text: 'Allow all',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontVariations: [FontVariation('wght', 700)],
                ),
              ),
              TextSpan(text: ' in the next step or in Android settings.'),
            ],
          ),
          warning: true,
        ),
        width: _callout,
      ),
      TtScenario(
        'callout, warning, with action',
        TtCallout(
          icon: Symbols.smartphone_rounded,
          title: 'Moving to a new phone?',
          body: "That isn't supported yet.",
          warning: true,
          action: TtButton(
            label: 'Learn more',
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
        width: _callout,
      ),
      const TtScenario(
        'callout, success',
        TtCallout(
          icon: Symbols.verified_rounded,
          title: 'Your clips are never lost',
          body: 'They show up in To tag when you open the app.',
          success: true,
        ),
        width: _callout,
      ),
      TtScenario(
        'callout, success, with action',
        TtCallout(
          icon: Symbols.verified_rounded,
          title: 'Your clips are never lost',
          body: 'They show up in To tag when you open the app.',
          success: true,
          action: TtButton(
            label: 'Got it',
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
        width: _callout,
      ),
      TtScenario(
        'callout, with action, no title',
        TtCallout(
          icon: Symbols.tips_and_updates_rounded,
          body:
              'Ask friends to send videos as HD or by Quick Share to keep '
              'full quality.',
          action: TtButton(
            label: 'Got it',
            kind: TtButtonKind.text,
            onPressed: () {},
          ),
        ),
        width: _callout,
      ),
      const TtScenario(
        'info bar',
        TtInfoBar(
          icon: Symbols.info_rounded,
          text:
              'Skipped clips are still in your gallery. Restore any you '
              'want to tag.',
        ),
      ),
    ],
  );
}
