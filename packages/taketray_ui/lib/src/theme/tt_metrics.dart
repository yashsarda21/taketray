/// Component numbers that are not design tokens: blur radii, opacities and
/// corner radii that the TakeTray style (`design/prototype/assets/tt-style.css`)
/// sets for one component.
///
/// The style rule (`tool/check_styles`, D-19) forbids raw numbers in
/// `lib/src/components`; a component that needs one adds it here, named after
/// the component (`navPillHeight`, `glassBlur`), with a comment naming its CSS
/// source. Spacing, radii, sizes, colours, text styles and durations that are
/// tokens come from `context.tt` instead.
abstract final class TtMetrics {
  // ---- Glass (floating chrome) ----

  /// Background blur behind glass chrome (nav pill, glass circles).
  // tt-style.css: .style-tt .navbar { backdrop-filter: blur(18px) }
  static const double glassBlur = 18;

  /// Opacity of `surfaceContainerHigh` in the glass fill.
  // tt-style.css: .style-tt .ph { --glass: … surface-container-high 78% }
  static const double glassOpacity = 0.78;

  /// Opacity of `onSurface` in the hairline border.
  // tt-style.css: .style-tt .ph { --hair: … on-surface 9% }
  static const double hairlineOpacity = 0.09;

  // ---- Text and badges on media (covers, video) ----

  /// Opacity of white secondary text on media.
  // tt-style.css: .style-tt .rcard .mt { color: rgba(255,255,255,.82) }
  static const double onMediaVariantOpacity = 0.82;

  /// Opacity of black at the end of the media scrim gradient.
  // tt-style.css: .style-tt .rcard .cover::after { … rgba(0,0,0,.8) }
  static const double mediaScrimEndOpacity = 0.8;

  // ---- Buttons ----

  /// Minimum height of a standard button (the 48 dp target is kept by
  /// Material's padded tap target).
  // tt-style.css: .style-tt .btn { min-height: 44px }
  static const double buttonMinHeight = 44;

  /// Horizontal padding inside a standard button.
  // tt-style.css: .style-tt .btn { padding: 0 22px }
  static const double buttonPaddingHorizontal = 22;

  /// Minimum height of a small button (the tap target stays 48 dp).
  // tt-style.css: .style-tt .btn.sm { min-height: 36px; padding: 0 16px }
  static const double buttonMinHeightSmall = 36;

  /// Horizontal padding inside a small button.
  // tt-style.css: .style-tt .btn.sm { min-height: 36px; padding: 0 16px }
  static const double buttonPaddingHorizontalSmall = 16;

  /// Minimum height of a large button.
  // tt-style.css: .style-tt .btn.lg { min-height: 56px }
  static const double buttonMinHeightLarge = 56;

  /// Horizontal padding inside a large button.
  // proto.css: .btn.lg { min-height: 56px; padding: 0 28px }
  static const double buttonPaddingHorizontalLarge = 28;

  /// Horizontal padding inside a text button.
  // proto.css: .btn.text { padding: 0 12px }
  static const double buttonPaddingHorizontalText = 12;

  /// Horizontal padding inside a ghost button (on video).
  // proto.css: .qrow .btn.ghost { padding: 0 18px }
  static const double buttonPaddingHorizontalGhost = 18;

  /// How far a leading icon sits inside the button's side padding.
  // proto.css: .btn .ms { margin-left: -8px }
  static const double buttonIconInset = 8;

  /// How far a leading icon sits inside a text button's side padding.
  // proto.css: .btn.text .ms { margin-left: -4px }
  static const double buttonIconInsetText = 4;

  /// Icon size inside a large button.
  // proto.css: .btn.lg .ms { font-size: 22px }
  static const double buttonIconSizeLarge = 22;

  /// Opacity of white in the ghost button's border.
  // proto.css: .qrow .btn.ghost { border: 1px solid rgba(255,255,255,.35) }
  static const double buttonGhostBorderOpacity = 0.35;

  /// Opacity of `onSurface` in a disabled button's content.
  // proto.css: .btn[disabled] { color: … on-surface 38% }
  static const double disabledContentOpacity = 0.38;

  /// Opacity of `onSurface` in a disabled button's fill and border.
  // proto.css: .btn[disabled] { background: … on-surface 12% }
  static const double disabledContainerOpacity = 0.12;

  // ---- Icon buttons ----

  /// Gap between the 48 dp tap target and the glass circle drawn inside it.
  // tt-style.css: .style-tt .appbar:not(.sel) .ib::before { inset: 5px }
  static const double iconButtonGlassInset = 5;

  // ---- Floating action button ----

  /// Height of the extended FAB.
  // tt-style.css: .style-tt .fab { height: 52px }
  static const double fabHeight = 52;

  /// Blur radius of the FAB's primary-tinted shadow.
  // tt-style.css: .style-tt .fab { box-shadow: 0 12px 26px -8px … }
  static const double fabShadowBlur = 26;

  /// Vertical offset of the FAB's shadow.
  // tt-style.css: .style-tt .fab { box-shadow: 0 12px 26px -8px … }
  static const double fabShadowOffsetY = 12;

  /// Spread of the FAB's shadow (negative: it shrinks).
  // tt-style.css: .style-tt .fab { box-shadow: 0 12px 26px -8px … }
  static const double fabShadowSpread = -8;

  /// Opacity of `primary` in the FAB's shadow.
  // tt-style.css: .style-tt .fab { … primary 70% }
  static const double fabShadowOpacity = 0.7;

  // ---- Glass panel shadow ----

  /// Blur radius of a glass panel's shadow.
  // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
  static const double glassShadowBlur = 30;

  /// Vertical offset of a glass panel's shadow.
  // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
  static const double glassShadowOffsetY = 10;

  /// Spread of a glass panel's shadow (negative: it shrinks).
  // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
  static const double glassShadowSpread = -8;

  /// Opacity of black in a glass panel's shadow.
  // tt-style.css: .style-tt .navbar { box-shadow: 0 10px 30px -8px … }
  static const double glassShadowOpacity = 0.35;

  // ---- Glass pill (status badge on media) ----

  /// Height of a glass pill.
  // proto.css: .pill { height: 24px }
  static const double glassPillHeight = 24;

  /// Background blur behind a glass pill.
  // tt-style.css: .style-tt .rcard .cover .pill { backdrop-filter: blur(8px) }
  static const double glassPillBlur = 8;

  /// Padding before the icon of a glass pill.
  // proto.css: .pill { padding: 0 8px 0 6px }
  static const double glassPillPaddingStart = 6;

  /// Icon size in a glass pill.
  // proto.css: .pill .ms { font-size: 16px }
  static const double glassPillIconSize = 16;

  // ---- Count badge ----

  /// Minimum width of a count badge.
  // proto.css: .badge { min-width: 20px }
  static const double badgeMinWidth = 20;

  /// Minimum height of a count badge (half of it is its corner radius).
  // proto.css: .badge { height: 18px; border-radius: 9px }
  static const double badgeMinHeight = 18;

  /// Horizontal padding inside a count badge.
  // proto.css: .badge { padding: 0 5px }
  static const double badgePaddingHorizontal = 5;

  /// Width of the ring that separates a count badge from the glass behind it.
  // tt-style.css: .style-tt .badge { box-shadow: 0 0 0 2px … }
  static const double badgeRingWidth = 2;

  /// Weight of the count badge's digits.
  // proto.css: .badge { font: 700 11.5px/18px … }
  static const double badgeFontWeight = 700;

  // ---- Record dot ----

  /// Diameter of the record dot.
  // proto.css: .recdot { width: 10px; height: 10px }
  static const double recDotSize = 10;

  /// Width of the static ring around the record dot.
  // proto.css: .recdot { box-shadow: 0 0 0 3px … record 30% }
  static const double recDotRingWidth = 3;

  /// Opacity of `record` in the static ring.
  // proto.css: .recdot { box-shadow: 0 0 0 3px … record 30% }
  static const double recDotRingOpacity = 0.3;

  /// Furthest the pulse ring spreads.
  // proto.css: @keyframes pulse { 60% { box-shadow: 0 0 0 7px transparent } }
  static const double recDotPulseSpread = 7;

  /// Opacity of `record` in the pulse ring when it starts.
  // proto.css: @keyframes pulse { 0% { box-shadow: 0 0 0 0 … record 60% } }
  static const double recDotPulseOpacity = 0.6;

  /// Fraction of the pulse during which the ring spreads out.
  // proto.css: @keyframes pulse { 60% { … } }
  static const double recDotPulseSpreadFraction = 0.6;

  /// Length of one pulse, in milliseconds.
  // proto.css: .recdot.live { animation: pulse 1.6s … infinite }
  static const double recDotPulseMillis = 1600;

  // ---- Snackbar ----

  /// Corner radius of the floating snackbar.
  // tt-style.css: .style-tt .snack { border-radius: 18px }
  static const double snackbarRadius = 18;

  /// Opacity of `inverseSurface` in the snackbar fill.
  // tt-style.css: .style-tt .snack { background: … inverse-surface 94% }
  static const double snackbarOpacity = 0.94;

  /// Gap between the snackbar and the screen's left and right edges.
  // tt-style.css: .style-tt .snack { left: 16px; right: 16px }
  static const double snackbarInsetSide = 16;

  /// Gap between the snackbar and the bottom of the screen.
  // proto.css: .snack { bottom: 12px }
  static const double snackbarInsetBottom = 12;

  // ---- Dialog ----

  /// Corner radius of a dialog.
  // tt-style.css: .style-tt .dlg { border-radius: 32px }
  static const double dialogRadius = 32;
}
