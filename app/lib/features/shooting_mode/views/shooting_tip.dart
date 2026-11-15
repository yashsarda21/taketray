import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// `.tooltip { width: 240px }` of proto.css.
const double _tipWidth = 240;

/// `.tooltip { border-radius: 12px }`.
const double _tipRadius = 12;

/// `.tooltip { padding: 12px 14px }`: the sides.
const double _tipPaddingSide = 14;

/// `.tooltip::before { width: 12px; height: 12px; transform: rotate(45deg) }`.
const double _arrowSize = 12;

/// `.tooltip::before { top: -6px }`: the arrow's centre is on the top edge.
const double _arrowTop = -_arrowSize / 2;

/// `.tooltip.right::before { right: 34px }`: under the switch.
const double _arrowEnd = 34;

/// `.tooltip b { margin-bottom: 2px }`.
const double _titleGap = 2;

/// `.shoot.hint { box-shadow: 0 0 0 3px surface, 0 0 0 6px
/// tertiary-container }`.
const double _ringGap = 3;
const double _ringWidth = 6;

/// The Home tip of the first launch (D-142): "Going out to shoot?", under
/// the Shooting mode card's switch, with a **Got it** button.
///
/// The prototype's `.tooltip.right` (an inverse-surface note, 240 dp wide, its
/// arrow 34 dp from the right edge, under the switch), but in the flow of the
/// column under the card instead of floating over what follows, so it can
/// never cover a switch, a banner or a chip: it takes the room it needs and
/// nothing outside its own box is blocked. Its right edge is the card's.
///
/// The title and the text read as one note to TalkBack, after the card; Got it
/// is a button of its own.
class ShootingTip extends StatelessWidget {
  /// A tip whose **Got it** calls [onGotIt].
  const new({required this.onGotIt, super.key});

  /// Called when **Got it** is tapped.
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final text = Theme.of(context).textTheme;
    final onInverse = scheme.onInverseSurface;
    final corners = BorderRadius.circular(_tipRadius);
    return Padding(
      // Room for the arrow above the box.
      padding: EdgeInsets.only(top: tt.spacing.xs, bottom: tt.spacing.xs),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _tipWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                end: _arrowEnd,
                top: _arrowTop,
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: SizedBox.square(
                      dimension: _arrowSize,
                      child: ColoredBox(color: scheme.inverseSurface),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.inverseSurface,
                  borderRadius: corners,
                  // proto.css: .tooltip { box-shadow: var(--elev-2) }
                  boxShadow: TtElevationTokens.level2,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    _tipPaddingSide,
                    tt.spacing.s,
                    _tipPaddingSide,
                    tt.spacing.s,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: _titleGap,
                          children: [
                            Text(
                              l10n.shootingTipTitle,
                              style: text.titleSmall!.copyWith(
                                color: onInverse,
                              ),
                            ),
                            Text(
                              l10n.shootingTipBody,
                              style: text.bodyMedium!.copyWith(
                                color: onInverse,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // `.tooltip .btn.text { color: inverse-primary }`
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: scheme.copyWith(
                            primary: scheme.inversePrimary,
                          ),
                        ),
                        child: TtButton(
                          label: l10n.shootingTipGotIt,
                          kind: TtButtonKind.text,
                          onPressed: onGotIt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring round the Shooting mode card while its tip shows: the
/// prototype's `.shoot.hint`, a 3 dp ring of the surface and a 6 dp ring of
/// the tertiary container outside it.
///
/// It only paints outside [child] (the card is opaque), so it changes no
/// layout and no touch.
class ShootingCardHighlight extends StatelessWidget {
  /// [child] with the hint ring round it.
  const new({required this.child, super.key});

  /// The card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tt.radii.xxl),
        boxShadow: [
          BoxShadow(color: scheme.tertiaryContainer, spreadRadius: _ringWidth),
          BoxShadow(color: scheme.surface, spreadRadius: _ringGap),
        ],
      ),
      child: child,
    );
  }
}
