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

  // ---- Switch ----

  /// Width of the switch track.
  // proto.css: .sw { width: 52px; height: 32px; border-radius: 16px }
  static const double switchTrackWidth = 52;

  /// Height of the switch track (half of it is its corner radius).
  // proto.css: .sw { width: 52px; height: 32px; border-radius: 16px }
  static const double switchTrackHeight = 32;

  /// Width of the switch track's border.
  // proto.css: .sw { border: 2px solid var(--md-outline) }
  static const double switchTrackBorder = 2;

  /// Diameter of the thumb when the switch is off.
  // proto.css: .sw::after { width: 16px; height: 16px }
  static const double switchThumbSizeOff = 16;

  /// Diameter of the thumb when the switch is on.
  // proto.css: .sw.on::after { width: 24px; height: 24px }
  static const double switchThumbSizeOn = 24;

  /// Gap between the track's inside edge and the off thumb (left and top).
  // proto.css: .sw::after { left: 6px; top: 6px }
  static const double switchThumbInsetOff = 6;

  /// Gap between the track's inside left edge and the on thumb.
  // proto.css: .sw.on::after { left: 22px; top: 2px }
  static const double switchThumbInsetOnStart = 22;

  /// Gap between the track's inside top edge and the on thumb.
  // proto.css: .sw.on::after { left: 22px; top: 2px }
  static const double switchThumbInsetOnTop = 2;

  /// Size of the check icon in the on thumb.
  // proto.css: .sw.on .ms { font-size: 16px }
  static const double switchCheckSize = 16;

  /// Opacity of the foreground colour in the inverted switch's off track.
  // proto.css: .sw.inv { background: color-mix(… --c-shoot-fg 20% …) }
  static const double switchInvertedTrackOpacity = 0.2;

  // ---- Check and radio marks ----

  /// Side of the check mark box.
  // proto.css: .cbox { width: 18px; height: 18px }
  static const double checkMarkSize = 18;

  /// Corner radius of the check mark box.
  // proto.css: .cbox { border-radius: 3px }
  static const double checkMarkRadius = 3;

  /// Width of the check mark box's border.
  // proto.css: .cbox { border: 2px solid … }
  static const double checkMarkBorder = 2;

  /// Size of the tick inside the check mark box.
  // proto.css: .cbox .ms { font-size: 16px }
  static const double checkMarkTickSize = 16;

  /// Weight of the tick inside the check mark box.
  // proto.css: .cbox .ms { font-variation-settings: … 'wght' 700 … }
  static const double checkMarkTickWeight = 700;

  /// Diameter of the radio mark.
  // proto.css: .radio { width: 20px; height: 20px }
  static const double radioMarkSize = 20;

  /// Width of the radio mark's ring.
  // proto.css: .radio { border: 2px solid … }
  static const double radioMarkBorder = 2;

  /// Gap between the radio ring's inside edge and its dot.
  // proto.css: .radio.on::after { inset: 3px }
  static const double radioMarkDotInset = 3;

  // ---- Pill tabs and suggestion chip ----

  /// Visual height of a pill tab or suggestion chip (the tap target stays
  /// 48 dp).
  // tt-style.css: .style-tt .fchip { height: 36px }
  static const double pillTabHeight = 36;

  /// Horizontal padding inside a pill tab or suggestion chip.
  // tt-style.css: .style-tt .fchip { padding: 0 15px }
  static const double pillTabPaddingHorizontal = 15;

  /// Gap between a chip's icon and its label.
  // proto.css: .fchip { gap: 6px }
  static const double pillTabIconGap = 6;

  /// Width of the suggestion chip's dashed outline.
  // tt-style.css: .style-tt .sugg .fchip { border: 1.5px dashed … }
  static const double suggestionBorderWidth = 1.5;

  /// Length of one dash of the suggestion chip's outline (the browser's
  /// dashed border for a 1.5 px line, 3 x the width).
  // tt-style.css: .style-tt .sugg .fchip { border: 1.5px dashed … }
  static const double suggestionDashLength = 4.5;

  /// Gap between the dashes of the suggestion chip's outline.
  // tt-style.css: .style-tt .sugg .fchip { border: 1.5px dashed … }
  static const double suggestionDashGap = 3;

  // ---- Text field ----

  /// Corner radius of the text field box.
  // proto.css: .tf .box { border-radius: 12px }
  static const double textFieldRadius = 12;

  /// Padding inside the text field box (on every side; the 2 dp focus border
  /// is drawn outside it).
  // proto.css: .tf .box { padding: 16px 16px; min-height: 56px }
  static const double textFieldPadding = 16;

  /// Width of the text field border at rest.
  // proto.css: .tf .box { border: 1px solid var(--md-outline) }
  static const double textFieldBorder = 1;

  /// Width of the text field border when focused or in error.
  // proto.css: .tf.focus .box { border: 2px solid var(--md-primary) }
  static const double textFieldBorderActive = 2;

  /// Lines a multiline field shows at least (72 dp of 24 dp lines).
  // proto.css: .tf textarea { min-height: 72px; line-height: 24px }
  static const double textFieldMultilineLines = 3;

  /// Lines a multiline field grows to before it scrolls.
  // (not in the prototype: a limit so the field cannot take the screen)
  static const double textFieldMultilineMaxLines = 6;

  /// Size of the error icon in the help row.
  // proto.css: .tf .help .ms { font-size: 16px }
  static const double textFieldHelpIconSize = 16;

  /// Gap between the error icon and the error text.
  // proto.css: .tf .help .ms { margin-right: 2px }
  static const double textFieldHelpIconGap = 2;

  /// Gap between the box and the help row.
  // proto.css: .tf .help { padding: 4px 16px 0 }
  static const double textFieldHelpGap = 4;

  /// Horizontal padding of the help row (aligns it with the text).
  // proto.css: .tf .help { padding: 4px 16px 0 }
  static const double textFieldHelpPaddingHorizontal = 16;

  // ---- Status pill ----

  /// Height of a status pill.
  // proto.css: .pill { height: 24px }
  static const double statusPillHeight = 24;

  /// Height of a large status pill.
  // proto.css: .pill.big { height: 32px }
  static const double statusPillHeightLarge = 32;

  /// Padding before the icon of a status pill.
  // proto.css: .pill { padding: 0 8px 0 6px }
  static const double statusPillPaddingStart = 6;

  /// Padding after the label of a status pill.
  // proto.css: .pill { padding: 0 8px 0 6px }
  static const double statusPillPaddingEnd = 8;

  /// Padding before the icon of a large status pill.
  // proto.css: .pill.big { padding: 0 10px 0 8px }
  static const double statusPillPaddingStartLarge = 8;

  /// Padding after the label of a large status pill.
  // proto.css: .pill.big { padding: 0 10px 0 8px }
  static const double statusPillPaddingEndLarge = 10;

  /// Icon size in a status pill.
  // proto.css: .pill .ms { font-size: 16px }
  static const double statusPillIconSize = 16;

  /// Icon size in a large status pill.
  // proto.css: .pill.big .ms { font-size: 18px }
  static const double statusPillIconSizeLarge = 18;

  /// Size of the caret that marks a pressable status pill.
  // proto.css: .pill .caret { font-size: 18px }
  static const double statusPillCaretSize = 18;

  /// Gap between the label and the caret: the pill's 4 dp gap plus the
  /// caret's 2 dp margin.
  // proto.css: .pill { gap: 4px }  .pill .caret { margin-left: 2px }
  static const double statusPillCaretGap = 6;

  /// How far the caret sits inside the pill's end padding.
  // proto.css: .pill .caret { margin-right: -4px }
  static const double statusPillCaretInset = 4;

  // ---- Clip tile ----

  /// Height of the dark scrim behind the time and duration, as a fraction of
  /// the tile.
  // proto.css: .tile .scr-b { height: 44% }
  static const double clipTileScrimHeightFactor = 0.44;

  /// Opacity of black at the bottom of the scrim.
  // proto.css: .tile .scr-b { … linear-gradient(transparent, rgba(0,0,0,.66)) }
  static const double clipTileScrimOpacity = 0.66;

  /// Gap between the tile's bottom edge and the time and duration.
  // proto.css: .tile .tm, .tile .du { bottom: 5px }
  static const double clipTileTextBottom = 5;

  /// Gap between the tile's side edges and the time and duration.
  // proto.css: .tile .tm { left: 7px }  .tile .du { right: 7px }
  static const double clipTileTextInset = 7;

  /// Weight of the time and duration.
  // proto.css: .tile .tm, .tile .du { font: 700 12px/16px … }
  static const double clipTileTextWeight = 700;

  /// Blur of the shadow under the time and duration.
  // proto.css: .tile .tm, .tile .du { text-shadow: 0 1px 2px rgba(0,0,0,.5) }
  static const double clipTileTextShadowBlur = 2;

  /// Vertical offset of the shadow under the time and duration.
  // proto.css: .tile .tm, .tile .du { text-shadow: 0 1px 2px rgba(0,0,0,.5) }
  static const double clipTileTextShadowOffsetY = 1;

  /// Opacity of black in the shadow under the time and duration.
  // proto.css: .tile .tm, .tile .du { text-shadow: 0 1px 2px rgba(0,0,0,.5) }
  static const double clipTileTextShadowOpacity = 0.5;

  /// Gap between the tile's edge and the corner badges (reel count,
  /// horizontal, VN folder).
  // proto.css: .tile .multi { left: 5px; top: 5px }  .tile .hz { right: 5px }
  static const double clipTileBadgeInset = 5;

  /// Height of the reel count badge and side of the horizontal badge.
  // proto.css: .tile .multi { height: 22px }  .tile .hz { width: 22px }
  static const double clipTileBadgeSize = 22;

  /// Corner radius of the reel count and horizontal badges.
  // proto.css: .tile .multi { border-radius: 6px }
  static const double clipTileBadgeRadius = 6;

  /// Opacity of the badge fill (dark, over the picture).
  // proto.css: .tile .multi { background: rgba(16,14,22,.72) }
  static const double clipTileBadgeOpacity = 0.72;

  /// Padding before the layers icon in the reel count badge.
  // proto.css: .tile .multi { padding: 0 6px 0 4px }
  static const double clipTileMultiPaddingStart = 4;

  /// Padding after the count in the reel count badge.
  // proto.css: .tile .multi { padding: 0 6px 0 4px }
  static const double clipTileMultiPaddingEnd = 6;

  /// Gap between the layers icon and the count.
  // proto.css: .tile .multi { gap: 2px }
  static const double clipTileMultiGap = 2;

  /// Size of the layers icon in the reel count badge.
  // proto.css: .tile .multi .ms { font-size: 14px }
  static const double clipTileMultiIconSize = 14;

  /// Size of the crop icon in the horizontal badge.
  // proto.css: .tile .hz .ms { font-size: 15px }
  static const double clipTileHorizontalIconSize = 15;

  /// Weight of the count in the reel count badge and the text of the mark.
  // proto.css: .tile .multi { font: 700 11.5px/1 … }
  static const double clipTileBadgeTextWeight = 700;

  /// Diameter of the selection circle.
  // proto.css: .tile .selc { width: 24px; height: 24px }
  static const double clipTileSelectSize = 24;

  /// Gap between the tile's edge and the selection circle.
  // proto.css: .tile .selc { right: 6px; top: 6px }
  static const double clipTileSelectInset = 6;

  /// Width of the selection circle's ring.
  // proto.css: .tile .selc { border: 2px solid #fff }
  static const double clipTileSelectBorder = 2;

  /// Opacity of black in the empty selection circle.
  // proto.css: .tile .selc { background: rgba(0,0,0,.25) }
  static const double clipTileSelectFillOpacity = 0.25;

  /// Size of the tick in the selected circle.
  // proto.css: .tile .selc .ms { font-size: 18px }
  static const double clipTileSelectTickSize = 18;

  /// Weight of the tick in the selected circle.
  // proto.css: .tile .selc .ms { font-variation-settings: … 'wght' 700 … }
  static const double clipTileSelectTickWeight = 700;

  /// How much the picture shrinks in a selected tile.
  // proto.css: .tile.sel .img { transform: scale(.86) }
  static const double clipTileSelectedScale = 0.86;

  /// Opacity of the surface colour over a marked tile.
  // proto.css: .tile .mark { background: color-mix(… surface 55% …) }
  static const double clipTileMarkScrimOpacity = 0.55;

  /// Padding around the mark label inside a marked tile.
  // proto.css: .tile .mark { padding: 8px }
  static const double clipTileMarkInset = 8;

  /// Corner radius of the mark label.
  // proto.css: .tile .mark > span { border-radius: 6px }
  static const double clipTileMarkRadius = 6;

  /// Horizontal padding inside the mark label.
  // proto.css: .tile .mark > span { padding: 3px 6px }
  static const double clipTileMarkPaddingHorizontal = 6;

  /// Vertical padding inside the mark label.
  // proto.css: .tile .mark > span { padding: 3px 6px }
  static const double clipTileMarkPaddingVertical = 3;

  /// Gap between the mark's icon and its text.
  // proto.css: .tile .mark > span { gap: 3px }
  static const double clipTileMarkGap = 3;

  /// Size of the mark's icon.
  // proto.css: .tile .mark .ms { font-size: 14px }
  static const double clipTileMarkIconSize = 14;

  /// Gap between the tile's left edge and the VN folder mark.
  // proto.css: .tile .vnmark { left: 5px; bottom: 24px }
  static const double clipTileVnInsetStart = 5;

  /// Gap between the VN folder mark and the time and length below it
  /// (24 from the bottom, less the 5 + 16 of the text line).
  // proto.css: .tile .vnmark { bottom: 24px }, .tile .tm { bottom: 5px }
  static const double clipTileVnGap = 3;

  /// Height of the time and length line (kept free for the VN mark when
  /// they are hidden).
  // proto.css: .tile .tm { font: 700 12px/16px … }
  static const double clipTileTextHeight = 16;

  /// Height of the VN folder mark.
  // screens/ui.js: the vnmark pill, style="height:20px"
  static const double clipTileVnHeight = 20;

  /// Padding before the icon of the VN folder mark.
  // ui.js: the vnmark pill, style="padding:0 6px 0 4px"
  static const double clipTileVnPaddingStart = 4;

  /// Padding after the text of the VN folder mark.
  // ui.js: the vnmark pill, style="padding:0 6px 0 4px"
  static const double clipTileVnPaddingEnd = 6;

  /// Font size of the VN folder mark's label (`label-medium` at 11 px).
  // ui.js: h.tile's vnmark pill, style="height:20px;font-size:11px;…"
  static const double clipTileVnFontSize = 11;

  /// Size of the VN folder mark's icon.
  // ui.js: icon('folder_copy', 's16')
  static const double clipTileVnIconSize = 16;

  // ---- Missing clip tile ----

  /// Width of the dashed border.
  // proto.css: .tile.miss { border: 1px dashed var(--md-outline) }
  static const double clipTileMissingBorder = 1;

  /// Length of one dash of the border (the browser's dashed border, 3 x the
  /// width).
  // proto.css: .tile.miss { border: 1px dashed var(--md-outline) }
  static const double clipTileMissingDashLength = 3;

  /// Gap between the dashes of the border.
  // proto.css: .tile.miss { border: 1px dashed var(--md-outline) }
  static const double clipTileMissingDashGap = 2;

  /// Horizontal padding inside the missing tile.
  // proto.css: .tile.miss { padding: 8px 6px }
  static const double clipTileMissingPaddingHorizontal = 6;

  /// Size of the missing tile's icon.
  // proto.css: .tile.miss .ms { font-size: 26px }
  static const double clipTileMissingIconSize = 26;

  /// Extra gap above the Remove button.
  // proto.css: .tile.miss .btn { margin-top: 2px }
  static const double clipTileMissingButtonGap = 2;

  /// Lines of the missing tile's label before it ends in an ellipsis.
  // (not in the prototype: a limit so the label cannot take the tile)
  static const double clipTileMissingLabelLines = 2;

  /// The text scale above which the missing tile's label gets one line only.
  // (not in the prototype: two lines no longer fit the 3:4 tile above this)
  static const double clipTileMissingLabelScaleLimit = 1.15;

  // ---- Skeleton ----

  /// Height of a skeleton line.
  // proto.css: .skel-line { height: 12px }
  static const double skeletonLineHeight = 12;

  /// Corner radius of a skeleton line.
  // proto.css: .skel-line { border-radius: 6px }
  static const double skeletonLineRadius = 6;

  /// Angle of the shimmer's gradient, in degrees (CSS: 0 is up, 90 right).
  // proto.css: .tile.skel::before { background: linear-gradient(100deg, … }
  static const double skeletonShimmerAngle = 100;

  /// Where the shimmer's bright band starts to fade in.
  // proto.css: .tile.skel::before { … transparent 20%, … 50%, transparent 80% }
  static const double skeletonShimmerStart = 0.2;

  /// Where the shimmer's bright band is brightest.
  // proto.css: .tile.skel::before { … transparent 20%, … 50%, transparent 80% }
  static const double skeletonShimmerMiddle = 0.5;

  /// Where the shimmer's bright band has faded out.
  // proto.css: .tile.skel::before { … transparent 20%, … 50%, transparent 80% }
  static const double skeletonShimmerEnd = 0.8;

  /// Opacity of `onSurface` at the brightest point of the shimmer.
  // proto.css: .tile.skel::before { … on-surface 7% … }
  static const double skeletonShimmerOpacity = 0.07;

  /// Width of the shimmer's gradient layer, as a multiple of the tile.
  // proto.css: .tile.skel::before { background-size: 220% 100% }
  static const double skeletonShimmerLayerWidth = 2.2;

  /// Where the layer starts (as a CSS background position, 1.2 = 120 %); it
  /// ends at the negative of this.
  // proto.css: @keyframes shimmer { from { background-position: 120% 0 } … }
  static const double skeletonShimmerTravel = 1.2;

  /// Length of one shimmer sweep, in milliseconds.
  // proto.css: .tile.skel::before { animation: shimmer 1.4s linear infinite }
  static const double skeletonShimmerMillis = 1400;
}
