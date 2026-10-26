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

  /// Minimum height of a dialog action button.
  // tt-style.css: .style-tt .dlg .acts .btn { min-height: 48px }
  static const double buttonMinHeightDialog = 48;

  /// Horizontal padding inside a dialog action button.
  // tt-style.css: .style-tt .dlg .acts .btn { padding: 0 12px }
  static const double buttonPaddingHorizontalDialog = 12;

  /// Gap between two buttons of a `TtButtonRow`, across or down.
  // tt-style.css: .style-tt .dlg .acts { gap: 8px }
  // proto.css: .sheet .sh-foot { gap: 8px }
  static const double buttonRowSpacing = 8;

  /// Most lines a dialog action label wraps to before it ends in an
  /// ellipsis (a stacked action at large text keeps its whole label).
  // (not in the prototype: .btn is one line; added for 2x text, D-48)
  static const double buttonDialogMaxLines = 2;

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

  /// Diameter of the compact record dot.
  // proto.css: .stat-strip .recdot { width: 8px; height: 8px }
  static const double recDotCompactSize = 8;

  /// Width of the outline ring around a record dot that has one.
  // proto.css: .shoot .ico .recdot { box-shadow: 0 0 0 2px … }
  static const double recDotOutlineWidth = 2;

  /// Opacity of `record` in the pulse ring of an outlined dot when it starts.
  // proto.css: @keyframes pulseOn { 0% { … 0 0 0 2px … record 70% } }
  static const double recDotOutlinePulseOpacity = 0.7;

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

  /// Widest a dialog gets (it is narrower on a narrow screen).
  // proto.css: .dlg { width: 100%; max-width: 312px }
  static const double dialogMaxWidth = 312;

  /// Padding above the title of a dialog.
  // tt-style.css: .style-tt .dlg { padding: 26px 22px 18px }
  static const double dialogPaddingTop = 26;

  /// Padding at the sides of a dialog.
  // tt-style.css: .style-tt .dlg { padding: 26px 22px 18px }
  static const double dialogPaddingHorizontal = 22;

  /// Padding under the actions of a dialog.
  // tt-style.css: .style-tt .dlg { padding: 26px 22px 18px }
  static const double dialogPaddingBottom = 18;

  /// Gap between the title of a dialog and what follows it.
  // proto.css: .dlg h2 { margin: 0 0 16px }
  static const double dialogTitleGap = 16;

  /// Gap between the body of a dialog and its custom content.
  // proto.css: .dlg p { margin: 0 0 12px }
  static const double dialogBodyGap = 12;

  /// Gap between the content of a dialog and its actions.
  // tt-style.css: .style-tt .dlg .acts { margin-top: 18px }
  static const double dialogActionsGap = 18;

  // ---- Overlays (sheet, dialog, menu) ----

  /// Opacity of the scrim (the page's scrim colour) behind a sheet or dialog.
  // tt-style.css: .style-tt .scrim { background: rgba(0,0,0,.5) }
  static const double scrimOpacity = 0.5;

  /// Background blur behind a sheet or dialog scrim.
  // tt-style.css: .style-tt .scrim { backdrop-filter: blur(3px) }
  static const double scrimBlur = 3;

  /// Blur radius of the shadow of a sheet or dialog.
  // tt-style.css: .style-tt .sheet { box-shadow: 0 20px 50px -10px … }
  static const double overlayShadowBlur = 50;

  /// Vertical offset of the shadow of a sheet or dialog.
  // tt-style.css: .style-tt .sheet { box-shadow: 0 20px 50px -10px … }
  static const double overlayShadowOffsetY = 20;

  /// Spread of the shadow of a sheet or dialog (negative: it shrinks).
  // tt-style.css: .style-tt .sheet { box-shadow: 0 20px 50px -10px … }
  static const double overlayShadowSpread = -10;

  /// Opacity of black in the shadow of a sheet or dialog.
  // tt-style.css: .style-tt .sheet { box-shadow: … rgba(0,0,0,.5) }
  static const double overlayShadowOpacity = 0.5;

  // ---- Sheet ----

  /// Gap between a floating sheet and the screen's sides and bottom.
  // tt-style.css: .style-tt .sheet { left: 8px; right: 8px; bottom: 8px }
  static const double sheetInset = 8;

  /// Corner radius of a floating sheet.
  // tt-style.css: .style-tt .sheet { border-radius: 32px }
  static const double sheetRadius = 32;

  /// Largest share of the screen's height a floating sheet takes.
  // proto.css: .sheet { max-height: 92% }
  static const double sheetMaxHeightFraction = 0.92;

  /// Width of the drag handle.
  // proto.css: .sheet .handle { width: 32px; height: 4px }
  static const double sheetHandleWidth = 32;

  /// Height of the drag handle (half of it is its corner radius).
  // proto.css: .sheet .handle { width: 32px; height: 4px; border-radius: 2px }
  static const double sheetHandleHeight = 4;

  /// Opacity of `onSurfaceVariant` in the drag handle.
  // proto.css: .sheet .handle { … opacity: .4 }
  static const double sheetHandleOpacity = 0.4;

  /// Space above the drag handle.
  // proto.css: .sheet .handle { margin: 16px auto 8px }
  static const double sheetHandleMarginTop = 16;

  /// Space under the drag handle.
  // proto.css: .sheet .handle { margin: 16px auto 8px }
  static const double sheetHandleMarginBottom = 8;

  /// Padding above the title of a sheet.
  // proto.css: .sheet .sh-head { padding: 4px 24px 12px }
  static const double sheetHeaderPaddingTop = 4;

  /// Padding at the sides of the title of a sheet.
  // proto.css: .sheet .sh-head { padding: 4px 24px 12px }
  static const double sheetHeaderPaddingHorizontal = 24;

  /// Padding under the title of a sheet.
  // proto.css: .sheet .sh-head { padding: 4px 24px 12px }
  static const double sheetHeaderPaddingBottom = 12;

  /// Padding above the footer of a sheet.
  // proto.css: .sheet .sh-foot { padding: 12px 16px 16px }
  static const double sheetFooterPaddingTop = 12;

  /// Padding at the sides of the footer of a sheet.
  // proto.css: .sheet .sh-foot { padding: 12px 16px 16px }
  static const double sheetFooterPaddingHorizontal = 16;

  /// Padding under the footer of a sheet.
  // proto.css: .sheet .sh-foot { padding: 12px 16px 16px }
  static const double sheetFooterPaddingBottom = 16;

  // ---- Snack ----

  /// Padding before the content of a snack.
  // proto.css: .snack { padding: 6px 8px 6px 16px }
  static const double snackPaddingStart = 16;

  /// Padding after the content (the action) of a snack.
  // proto.css: .snack { padding: 6px 8px 6px 16px }
  static const double snackPaddingEnd = 8;

  /// Padding above and under the content of a snack.
  // proto.css: .snack { padding: 6px 8px 6px 16px }
  static const double snackPaddingVertical = 6;

  /// Gap between the parts of a snack.
  // proto.css: .snack { gap: 8px }
  static const double snackGap = 8;

  /// Padding above and under the message of a snack.
  // proto.css: .snack .grow { padding: 8px 0 }
  static const double snackMessagePadding = 8;

  /// How far the snack's action colour moves from `inversePrimary` towards
  /// `onInverseSurface`. The 94 % fill lets 6 % of a dark page through, which
  /// takes the dark theme's action to 4.4:1; this brings it above 4.5:1.
  // (not in the prototype: proto.css: .snack .btn.text uses inverse-primary)
  static const double snackActionContrastMix = 0.15;

  /// How long a snack stays, in milliseconds.
  // proto: app.js snack(): opts.undo ? 6000 : 4000
  static const double snackDurationMillis = 4000;

  /// How long a snack with an action (Undo) stays, in milliseconds: time to
  /// undo a bulk action.
  // proto: app.js snack(): opts.undo ? 6000 : 4000
  static const double snackDurationWithActionMillis = 6000;

  /// Size of the leading icon of a snack.
  // proto.css: .snack .ms.lead { font-size: 20px }
  static const double snackIconSize = 20;

  // ---- Menu ----

  /// Corner radius of a menu.
  // tt-style.css: .style-tt .menu { border-radius: 20px }
  static const double menuRadius = 20;

  /// Corner radius of a menu item.
  // tt-style.css: .style-tt .menu .mi { border-radius: 14px }
  static const double menuItemRadius = 14;

  /// Padding around the items of a menu.
  // tt-style.css: .style-tt .menu { padding: 6px }
  static const double menuPadding = 6;

  /// Narrowest a menu gets.
  // proto.css: .menu { min-width: 200px }
  static const double menuMinWidth = 200;

  /// Widest a menu gets.
  // proto.css: .menu { max-width: 300px }
  static const double menuMaxWidth = 300;

  /// Horizontal padding inside a menu item.
  // proto.css: .menu .mi { padding: 0 16px }
  static const double menuItemPaddingHorizontal = 16;

  /// Elevation of a menu. Flutter has no spread or offset on a Material's
  /// shadow, so this approximates the CSS shadow.
  // tt-style.css: .style-tt .menu { box-shadow: 0 12px 30px -6px … .4 }
  static const double menuElevation = 6;

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

  // ---- Reel card ----

  /// Width over height of a reel card's cover.
  // tt-style.css: .style-tt .rcard .cover { aspect-ratio: 4 / 5 }
  static const double reelCardAspect = 0.8;

  /// Corner radius of a reel card.
  // tt-style.css: .style-tt .rcard { border-radius: 22px }
  static const double reelCardRadius = 22;

  /// Where the bottom gradient starts, as a fraction of the cover's height.
  // tt-style.css: .style-tt .rcard .cover::after { inset: 40% 0 0 }
  static const double reelCardScrimStart = 0.4;

  /// Distance of the status pill from the cover's top and start edges (the
  /// "Editing in VN" pill sits under it, 8 dp down).
  // proto.css: .rcard .cover .pill { left: 8px; top: 8px }
  static const double reelCardPillInset = 8;

  /// Largest text scale a reel card follows.
  // Not in the prototype (it has no text scaling): the 4:5 tile has a fixed
  // size. At 1.6 the 158 dp tile with a two-line name, an Editing in VN pill,
  // a missing mark and a two-digit badge still has the name below both pills
  // and the badge clear of the meta; at 1.7 the name starts 5 dp under the
  // second pill. See D-46.
  static const double reelCardMaxTextScale = 1.6;

  /// Distance of the name and meta from the cover's bottom edge.
  // tt-style.css: .style-tt .rcard .cap { bottom: 11px }
  static const double reelCardCaptionBottom = 11;

  /// Distance of the name and meta from the cover's end edge when the
  /// references badge is shown (otherwise 12 dp).
  // tt-style.css: .style-tt .rcard-wrap:has(.refbadge) .cap { right: 50px }
  static const double reelCardCaptionInsetEndWithBadge = 50;

  /// Gap between the name and the meta, between meta lines, and between the
  /// missing-clips icon and its text.
  // tt-style.css: .style-tt .rcard .cap { gap: 2px }, proto.css:
  // .rcard .mt { gap: 2px 8px }, .rcard .mt .miss { gap: 2px }
  static const double reelCardCaptionGap = 2;

  /// Size of the error icon before the missing-clips text.
  // proto.css: .rcard .mt .miss .ms { font-size: 14px }
  static const double reelCardMissingIconSize = 14;

  /// Weight of the missing-clips text.
  // proto.css: .rcard .mt .miss { font-weight: 600 }
  static const double reelCardMissingWeight = 600;

  /// Gap between the empty art's icon and its label.
  // proto.css: .rcard .ph-empty { gap: 6px }
  static const double reelCardEmptyGap = 6;

  /// Opacity of the empty art's icon.
  // proto.css: .rcard .ph-empty .ms { opacity: .8 }
  static const double reelCardEmptyIconOpacity = 0.8;

  // ---- References badge (on a reel card) ----

  /// Height of the references badge.
  // proto.css: .refbadge { height: 26px }
  static const double refBadgeHeight = 26;

  /// Distance of the badge from the cover's bottom and end edges.
  // tt-style.css: .style-tt .refbadge { bottom: 10px; right: 10px }
  static const double refBadgeInset = 10;

  /// How far the badge's tap target reaches past it, sideways.
  // proto.css: .refbadge::before { inset: -11px -8px }
  static const double refBadgeHitInset = 8;

  /// Padding before the badge's icon.
  // proto.css: .refbadge { padding: 0 8px 0 6px }
  static const double refBadgePaddingStart = 6;

  /// Padding after the badge's count.
  // proto.css: .refbadge { padding: 0 8px 0 6px }
  static const double refBadgePaddingEnd = 8;

  /// Gap between the badge's icon and its count.
  // proto.css: .refbadge { gap: 3px }
  static const double refBadgeGap = 3;

  /// Size of the badge's icon.
  // proto.css: .refbadge .ms { font-size: 16px }
  static const double refBadgeIconSize = 16;

  /// Weight of the badge's count.
  // proto.css: .refbadge { font: 700 12px/1 var(--font) }
  static const double refBadgeWeight = 700;

  // ---- Reference card ----

  /// Least height of the tappable part of a reference card.
  // proto.css: .ref-main { min-height: 66px }
  static const double referenceCardMinHeight = 66;

  /// Padding before the art of a reference card.
  // proto.css: .ref-main { padding: 8px 4px 8px 10px }
  static const double referenceCardPaddingStart = 10;

  /// Padding after the "Open" mark of a reference card.
  // proto.css: .ref-main { padding: 8px 4px 8px 10px }
  static const double referenceCardPaddingEnd = 4;

  /// Width of a reference's art.
  // proto.css: .ref-art { width: 36px; height: 48px }
  static const double referenceArtWidth = 36;

  /// Height of a reference's art.
  // proto.css: .ref-art { width: 36px; height: 48px }
  static const double referenceArtHeight = 48;

  /// Size of the play icon on a reference's art.
  // proto.css: .ref-art > .ms { font-size: 22px }
  static const double referenceArtIconSize = 22;

  /// Width of one stripe of a reference's art.
  // proto.css: .ref-art { repeating-linear-gradient(135deg, … 5px, … 10px) }
  static const double referenceArtStripe = 5;

  /// Direction of the art's stripes, in degrees (CSS: 135deg).
  // proto.css: .ref-art { repeating-linear-gradient(135deg, …) }
  static const double referenceArtStripeAngle = 135;

  /// Share of `secondaryContainer` in the art's darker stripe.
  // proto.css: .ref-art { … color-mix(in srgb, secondary-container 60%, … ) }
  static const double referenceArtStripeMix = 0.6;

  /// How far the source icon hangs past the art's bottom and end corner.
  // proto.css: .ref-src { right: -6px; bottom: -6px }
  static const double referenceSourceOffset = 6;

  /// Gap between the title and the subtitle.
  // proto.css: .ref-t > span { margin-top: 2px }
  static const double referenceSubtitleGap = 2;

  /// Widest the "Open" mark may grow (not in the prototype, which never
  /// wraps it; this keeps a long label from squeezing the title away).
  static const double referenceOpenMaxWidth = 120;

  // ---- Add-reference tile ----

  /// Least height of the add-reference tile.
  // proto.css: .ref-add { min-height: 56px }
  static const double addReferenceMinHeight = 56;

  /// Padding after the add-reference tile's plus.
  // proto.css: .ref-add { padding: 8px 12px 8px 16px }
  static const double addReferencePaddingEnd = 12;

  /// Width of the add-reference tile's dashed outline.
  // proto.css: .ref-add { border: 1.5px dashed … }
  static const double addReferenceBorder = 1.5;

  /// Length of a dash in the add-reference tile's outline (3 x the width, as
  /// in the missing-clip tile).
  // proto.css: .ref-add { border: 1.5px dashed … }
  static const double addReferenceDash = 4.5;

  /// Gap between dashes in the add-reference tile's outline.
  // proto.css: .ref-add { border: 1.5px dashed … }
  static const double addReferenceDashGap = 3;

  // ---- Shooting mode card ----

  /// Side of the Shooting mode card's icon tile.
  // proto.css: .shoot .ico { width: 48px; height: 48px }
  static const double shootingIconSize = 48;

  /// Corner radius of the Shooting mode card's icon tile.
  // proto.css: .shoot .ico { border-radius: 14px }
  static const double shootingIconRadius = 14;

  /// Gap between the icon tile, the texts and the switch.
  // proto.css: .shoot .top { gap: 14px }
  static const double shootingTopGap = 14;

  /// Gap between the title and the subtitle.
  // proto.css: .shoot .txt span { margin-top: 2px }
  static const double shootingSubtitleGap = 2;

  /// Distance of the record dot from the icon tile's top and end edges.
  // proto.css: .shoot .ico .recdot { right: 5px; top: 5px }
  static const double shootingRecDotInset = 5;

  /// Opacity of the backdrop picture on the "on" card.
  // tt-style.css: .style-tt .shoot.on .shoot-media img { opacity: .62 }
  static const double shootingBackdropOpacity = 0.62;

  /// Opacity of white in the icon tile on the "on" card.
  // tt-style.css: .shoot.on .ico { background: rgba(255,255,255,.16) } and
  // proto.css: .shoot.on .ico { … fg 16 % }
  static const double shootingIconFillOpacity = 0.16;

  /// Blur behind the icon tile on the "on" card.
  // tt-style.css: .style-tt .shoot.on .ico { backdrop-filter: blur(8px) }
  static const double shootingIconBlur = 8;

  /// Opacity of white in the subtitle on the "on" card.
  // tt-style.css: .shoot.on .txt span { color: rgba(255,255,255,.85) }
  static const double shootingSubtitleOpacity = 0.85;

  /// Angle of the brand tint over the backdrop, in degrees.
  // tt-style.css: .style-tt .shoot.on::before { linear-gradient(160deg, … }
  static const double shootingTintAngle = 160;

  /// Opacity of the brand colour at the start of the tint.
  // tt-style.css: .style-tt .shoot.on::before { … bg 78% 0% … }
  static const double shootingTintStartOpacity = 0.78;

  /// Opacity of the brand colour in the middle of the tint.
  // tt-style.css: .style-tt .shoot.on::before { … bg 35% 55% … }
  static const double shootingTintMiddleOpacity = 0.35;

  /// Where the middle of the tint is.
  // tt-style.css: .style-tt .shoot.on::before { … bg 35% 55% … }
  static const double shootingTintMiddleStop = 0.55;

  /// Opacity of black at the end of the tint.
  // tt-style.css: .style-tt .shoot.on::before { … rgba(0,0,0,.55) 100% }
  static const double shootingTintEndOpacity = 0.55;

  // ---- Card rows (references row, to-tag strip) ----

  /// Least height of a references row.
  // proto.css: .refrow { min-height: 56px }
  static const double cardRowMinHeight = 56;

  /// Least height of a to-tag strip.
  // proto.css: .shoot .strip { min-height: 52px }
  static const double cardStripMinHeight = 52;

  /// Gap between the parts of a references row.
  // proto.css: .refrow { gap: 12px }
  static const double cardRowGap = 12;

  /// Gap between the parts of a to-tag strip.
  // proto.css: .shoot .strip { gap: 10px }
  static const double cardStripGap = 10;

  /// Opacity of white in the top border of a references row.
  // tt-style.css: .shoot.on .refrow { border-top-color: rgba(255,255,255,.18) }
  static const double cardRowBorderOpacity = 0.18;

  /// Opacity of black behind a references row.
  // tt-style.css: .style-tt .shoot.on .refrow { background: rgba(0,0,0,.25) }
  static const double cardRowFillOpacity = 0.25;

  /// Blur behind a references row.
  // tt-style.css: .style-tt .shoot.on .refrow { backdrop-filter: blur(6px) }
  static const double cardRowBlur = 6;

  /// Opacity of the subtitle in a references row.
  // proto.css: .refrow .grow > span { opacity: .85 }
  static const double cardRowSubtitleOpacity = 0.85;

  // ---- Stat strip ----

  /// Padding after the stat strip's action.
  // proto.css: .stat-strip { padding: 0 8px 0 16px }
  static const double statStripPaddingEnd = 8;

  // ---- Video surface ----

  /// Height of the gradient scrim under the top controls on video.
  // proto.css: .viewer .vtop { padding: 32px 4px 24px } around a 56 px row
  static const double videoScrimTopHeight = 112;

  /// Height of the gradient scrim under the bottom controls on video.
  // proto.css: .viewer .vbot { padding: 40px 0 28px } around its content
  static const double videoScrimBottomHeight = 168;

  // ---- Segment progress bar ----

  /// Height of the segment progress bar.
  // proto.css: .player .pbar { height: 3px }
  static const double segmentBarHeight = 3;

  /// Gap between two segments.
  // proto.css: .player .pbar { gap: 2px }
  static const double segmentBarGap = 2;

  /// Corner radius of a segment.
  // proto.css: .player .pbar i { border-radius: 2px }
  static const double segmentBarRadius = 2;

  /// Opacity of white in a segment that is not yet reached.
  // proto.css: .player .pbar i { background: rgba(255,255,255,.25) }
  static const double segmentBarTrackOpacity = 0.25;

  /// The most clips that get one segment each; above this the bar collapses
  /// to three segments.
  // screens.js: routes.player `total <= 40`
  static const int segmentBarMaxClips = 40;

  // ---- Player header ----

  /// Minimum height of the tag player header.
  // proto.css: .player .ptop { height: 56px }
  static const double playerHeaderHeight = 56;

  // ---- Stage arrows ----

  /// Opacity of black in the stage arrow's disc.
  // proto.css: .stage .arrow { background: rgba(0,0,0,.35) }
  static const double stageArrowFillOpacity = 0.35;

  /// Opacity of a disabled stage arrow, disc and chevron together.
  // proto.css: .stage .arrow[disabled] { opacity: .3 }
  static const double stageArrowDisabledOpacity = 0.3;

  // ---- Scrub bar ----

  /// Height of the track.
  // proto.css: .scrub .trk { height: 4px }
  static const double scrubTrackHeight = 4;

  /// Height of the track when the clip is long.
  // proto.css: .scrub.big .trk { height: 6px }
  static const double scrubTrackHeightLarge = 6;

  /// Corner radius of the track.
  // proto.css: .scrub .trk { border-radius: 2px }
  static const double scrubTrackRadius = 2;

  /// Diameter of the thumb.
  // proto.css: .scrub .trk b { width: 14px; height: 14px }
  static const double scrubThumbSize = 14;

  /// Diameter of the thumb when the clip is long.
  // proto.css: .scrub.big .trk b { width: 20px; height: 20px }
  static const double scrubThumbSizeLarge = 20;

  /// Width of the halo around the large thumb.
  // proto.css: .scrub.big .trk b { box-shadow: 0 0 0 6px rgba(255,255,255,.2) }
  static const double scrubThumbHalo = 6;

  /// Opacity of white in the large thumb's halo.
  // proto.css: .scrub.big .trk b { box-shadow: 0 0 0 6px rgba(255,255,255,.2) }
  static const double scrubThumbHaloOpacity = 0.2;

  /// Opacity of white in the part of the track not yet played.
  // proto.css: .scrub .trk { background: rgba(255,255,255,.25) }
  static const double scrubTrackOpacity = 0.25;

  /// Opacity of white in the time texts.
  // proto.css: .scrub { color: rgba(255,255,255,.85) }
  static const double scrubTextOpacity = 0.85;

  /// Gap between the times and the track.
  // proto.css: .scrub { gap: 10px }
  static const double scrubGap = 10;

  /// Weight of the time texts and the hint.
  // proto.css: .scrub { font: 600 12px/1 var(--font) }
  static const double scrubTextWeight = 600;

  /// How far the hint's bottom edge sits above the middle of the track.
  // proto.css: .scrub .hint { bottom: 18px } on a 22 px bar whose track is
  // centred 6 px above its bottom
  static const double scrubHintLift = 12;

  /// Opacity of black behind the hint.
  // proto.css: .scrub .hint { background: rgba(0,0,0,.6) }
  static const double scrubHintOpacity = 0.6;

  /// Corner radius of the hint.
  // proto.css: .scrub .hint { border-radius: 6px }
  static const double scrubHintRadius = 6;

  /// How far a screen reader's increase or decrease moves the scrub bar, as
  /// a fraction of the clip.
  // No CSS source: the prototype has no adjustable slider semantics.
  static const double scrubSemanticStep = 0.05;

  // ---- Same as previous ----

  /// Corner radius of the "Same as previous" button.
  // tt-style.css: .style-tt .qrow .btn.same { border-radius: 24px }
  static const double sameButtonRadius = 24;

  /// Opacity of white in the button's fill.
  // proto.css: .qrow .btn.same { background: rgba(255,255,255,.14) }
  static const double sameButtonFillOpacity = 0.14;

  /// Opacity of the detail line.
  // proto.css: .qrow .btn.same .two small { opacity: .8 }
  static const double sameButtonDetailOpacity = 0.8;

  /// Line height of the label, as a multiple of its size.
  // proto.css: .qrow .btn.same .two { line-height: 1.2 }
  static const double sameButtonLabelHeight = 1.2;

  // ---- Tag panel ----

  /// Width of the highlight along the panel's top edge.
  // tt-style.css: .style-tt .tagpanel { box-shadow: inset 0 1px 0 var(--hair) }
  static const double tagPanelHairline = 1;

  /// Opacity of the panel's surface container fill.
  // tt-style.css: .style-tt .tagpanel { background: color-mix(…92%…) }
  static const double tagPanelOpacity = 0.92;

  /// Background blur behind the panel.
  // tt-style.css: .style-tt .tagpanel { backdrop-filter: blur(20px) }
  static const double tagPanelBlur = 20;

  /// Padding under the panel's content.
  // proto.css: .tagpanel { padding: 12px 12px 26px }
  static const double tagPanelPaddingBottom = 26;

  /// Tallest the panel gets before its chips scroll, at normal text size.
  // proto.css: .tagpanel { max-height: 340px }
  static const double tagPanelMaxHeight = 340;

  /// The text scale from which the panel lays its chips out one per row and
  /// a chip's name may take two lines. Below it: two columns, one line.
  // Not in the prototype: large-text layout (D-47). At 2x a 164 dp cell shows
  // about 5 letters of a name, so reel names that share a first word cannot
  // be told apart; one full-width chip shows about 12.
  static const double tagPanelSingleColumnTextScale = 1.5;

  /// Tallest the panel gets at large text: the cap grows with the text scale
  /// (340 dp at 1x, times the scale) up to this.
  // Not in the prototype: large-text layout (D-47). At 2x, three one-column
  // chips with two-line names are 3 x 126 dp, plus 12 padding, 48 header,
  // 2 x 8 gaps, 4 and 26 under the grid = 484 dp, so 520 shows three whole
  // chips under the header and leaves 260 dp of a 780 dp screen for the
  // video and controls.
  static const double tagPanelMaxHeightLarge = 520;

  /// Minimum height of the panel's header row.
  // proto.css: .tagpanel .ph-h { min-height: 40px }
  static const double tagPanelHeaderHeight = 40;

  // ---- Reel chip ----

  /// Corner radius of a chip.
  // tt-style.css: .style-tt .rchip { border-radius: 18px }
  static const double reelChipRadius = 18;

  /// Width of the cover.
  // proto.css: .rchip .cv { width: 34px }
  static const double reelChipCoverWidth = 34;

  /// Height of the cover.
  // proto.css: .rchip .cv { height: 44px }
  static const double reelChipCoverHeight = 44;

  /// Corner radius of the cover.
  // tt-style.css: .style-tt .rchip .cv { border-radius: 10px }
  static const double reelChipCoverRadius = 10;

  /// Padding before the cover and above and below the content.
  // proto.css: .rchip { padding: 6px 10px 6px 6px }
  static const double reelChipPaddingStart = 6;

  /// Padding after the content.
  // proto.css: .rchip { padding: 6px 10px 6px 6px }
  static const double reelChipPaddingEnd = 10;

  /// Gap between the cover, the texts and the check mark.
  // proto.css: .rchip { gap: 10px }
  static const double reelChipGap = 10;

  /// Width of the border (transparent unless picked).
  // proto.css: .rchip { border: 1px solid transparent }
  static const double reelChipBorder = 1;

  /// Scale of a chip that has just been tagged.
  // proto.css: .rchip.done { transform: scale(.97) }
  static const double reelChipDoneScale = 0.97;

  /// Opacity of the count under the name on a picked chip.
  // proto.css: .rchip.pick .t span { opacity: .8 }
  static const double reelChipPickedCountOpacity = 0.8;

  /// Opacity of the count under the name on a tagged chip.
  // proto.css: .rchip.done .t span { opacity: .85 }
  static const double reelChipDoneCountOpacity = 0.85;

  /// Size of the film icon that stands in for a missing cover.
  // proto.css: .rchip .cv .ms { font-size: 20px }
  static const double reelChipCoverIconSize = 20;

  /// Size of the check that replaces the cover on a tagged chip.
  // proto.css: .rchip.done .cv .ms { font-size: 24px }
  static const double reelChipDoneIconSize = 24;

  /// Weight of that check.
  // proto.css: .rchip.done .cv .ms { 'wght' 700 }
  static const double reelChipDoneIconWeight = 700;

  // ---- Grouped rows and list rows ----

  /// Corner radius of the outer corners of a group of rows.
  // tt-style.css: .style-tt .scroll > .li { border-radius: 6px }, and the
  // first/last row's outer corners { 22px }
  static const double groupedRowsOuterRadius = 22;

  /// Corner radius of the inner corners of a group of rows.
  // tt-style.css: .style-tt .scroll > .li { border-radius: 6px }
  static const double groupedRowsInnerRadius = 6;

  /// Gap between the rows of a group.
  // tt-style.css: .style-tt .scroll > .li + .li { margin-top: 2px }
  static const double groupedRowsGap = 2;

  /// Space above a group label.
  // tt-style.css: .style-tt .li-h { padding: 22px 28px 8px }
  static const double groupLabelPaddingTop = 22;

  /// Space before and after a group label.
  // tt-style.css: .style-tt .li-h { padding: 22px 28px 8px }
  static const double groupLabelPaddingHorizontal = 28;

  /// Minimum height of a list row.
  // proto.css: .li { min-height: 56px }
  static const double listRowMinHeight = 56;

  /// Weight of a list row's title.
  // proto.css: .li .txt b { font-weight: 500 }
  static const double listRowTitleWeight = 500;

  /// Text scale from which a list row's trailing value or button moves
  /// under the text, because beside it the title would break inside words.
  /// Not in the prototype (it has no text scaling); the same threshold as
  /// [tagPanelSingleColumnTextScale].
  static const double listRowStackTrailingTextScale = 1.5;

  /// Side of the box behind a boxed row icon.
  // proto.css: .li .lead.box { width: 40px; height: 40px }
  static const double rowIconBoxSize = 40;

  /// Corner radius of the box behind a boxed row icon.
  // tt-style.css: .style-tt .li .lead.box { border-radius: 14px }
  static const double rowIconBoxRadius = 14;

  // ---- Banners, callouts and the info bar ----

  /// Minimum height of a banner.
  // proto.css: .banner { min-height: 56px }
  static const double bannerMinHeight = 56;

  /// Space above a banner.
  // proto.css: .banner { margin: 4px 16px 8px }
  static const double bannerMarginTop = 4;

  /// Space between the title and the body of a banner.
  // proto.css: .banner .grow span { margin-top: 1px }
  static const double bannerBodyGap = 1;

  /// Space above and below the content of a VN banner.
  // proto.css: .banner.vn { padding: 14px 16px }
  static const double bannerVnPaddingVertical = 14;

  /// Text scale from which a banner's action moves under its text, because
  /// beside it the action would squeeze the text to a few letters per line.
  /// Not in the prototype (it has no text scaling); the same threshold as
  /// [tagPanelSingleColumnTextScale].
  static const double bannerActionBelowTextScale = 1.5;

  /// Space before and after the content of a callout.
  // proto.css: .callout { padding: 12px 14px }
  static const double calloutPaddingHorizontal = 14;

  /// Space under the title of a callout.
  // proto.css: .callout > div > b:first-child { margin-bottom: 2px }
  static const double calloutTitleGap = 2;

  /// Gap between the icon and the text of an info bar.
  // proto.css: .infobar { gap: 10px }
  static const double infoBarGap = 10;

  /// Space above and below the text of an info bar.
  // proto.css: .infobar { padding: 10px 16px }
  static const double infoBarPaddingVertical = 10;

  // ---- Progress bar ----

  /// Height of the progress bar.
  // proto.css: .prog { height: 4px }
  static const double progressHeight = 4;

  /// Corner radius of the progress bar.
  // proto.css: .prog { border-radius: 2px }
  static const double progressRadius = 2;

  /// Share of the track the moving bar of an indeterminate progress bar
  /// covers. Not in the prototype (`.prog` has no indeterminate look).
  static const double progressIndeterminateFraction = 0.4;

  /// Time the moving bar of an indeterminate progress bar takes to cross the
  /// track. Not in the prototype; the same pace as the skeleton shimmer.
  static const double progressIndeterminateMillis = 1400;

  // ---- Illustrations and empty states ----

  /// Width of an illustration.
  // proto.css: .empty .ill { width: 168px } (viewBox 0 0 168 140)
  static const double illustrationWidth = 168;

  /// Height of an illustration.
  // proto.css: .empty .ill { height: 140px } (viewBox 0 0 168 140)
  static const double illustrationHeight = 140;

  /// Space under the illustration of an empty state, on top of the gap.
  // proto.css: .empty .ill { margin-bottom: 12px }
  static const double emptyIllustrationMargin = 12;

  /// Space under the body text of an empty state, on top of the gap.
  // proto.css: .empty p { margin: 0 0 12px }
  static const double emptyBodyMargin = 12;

  /// Widest the body text of an empty state grows.
  // proto.css: .empty p { max-width: 280px }
  static const double emptyBodyMaxWidth = 280;
}
