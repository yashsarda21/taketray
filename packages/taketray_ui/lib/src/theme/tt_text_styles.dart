import 'package:flutter/material.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Text styles: the Material type scale plus the TakeTray display styles.
/// Read them as `context.tt.text`.
///
/// [material] carries the scheme's colours, like Material's own `TextTheme`.
/// The TakeTray styles carry no colour: they take the ambient text colour,
/// and a component that needs another one sets it from `context.tt.colors` or
/// `context.scheme`.
@immutable
class TtTextStyles {
  /// Text styles; a TakeTray style that is not given is the design's own.
  /// Use [TtTextStyles.fromScheme].
  new({
    required this.material,
    TextStyle? pageTitle,
    TextStyle? detailTitle,
    TextStyle? screenTitle,
    TextStyle? dialogTitle,
    TextStyle? shootTitle,
    TextStyle? cardTitle,
    TextStyle? groupLabel,
    TextStyle? navLabel,
  }) : pageTitle = pageTitle ?? _pageTitle,
       detailTitle = detailTitle ?? _detailTitle,
       screenTitle = screenTitle ?? _screenTitle,
       dialogTitle = dialogTitle ?? _dialogTitle,
       shootTitle = shootTitle ?? _shootTitle,
       cardTitle = cardTitle ?? _cardTitle,
       groupLabel = groupLabel ?? _groupLabel,
       navLabel = navLabel ?? _navLabel;

  /// The type scale with [scheme]'s `onSurface` applied.
  factory fromScheme(ColorScheme scheme) => TtTextStyles(
    material: materialTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );

  /// A style with only [weight] set: `fontWeight` and the variable font's
  /// `wght` axis together. Plus Jakarta Sans is a variable font, and a
  /// `fontWeight` alone may not move the axis, so always merge this over a
  /// style instead of setting either one by hand:
  /// `style.merge(TtTextStyles.weight(FontWeight.w700))`.
  static TextStyle weight(FontWeight weight) => TextStyle(
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );

  /// The token type scale (Plus Jakarta Sans), without colours.
  static const TextTheme materialTextTheme = TextTheme(
    displaySmall: TtTypeTokens.displaySmall,
    headlineLarge: TtTypeTokens.headlineLarge,
    headlineMedium: TtTypeTokens.headlineMedium,
    headlineSmall: TtTypeTokens.headlineSmall,
    titleLarge: TtTypeTokens.titleLarge,
    titleMedium: TtTypeTokens.titleMedium,
    titleSmall: TtTypeTokens.titleSmall,
    bodyLarge: TtTypeTokens.bodyLarge,
    bodyMedium: TtTypeTokens.bodyMedium,
    bodySmall: TtTypeTokens.bodySmall,
    labelLarge: TtTypeTokens.labelLarge,
    labelMedium: TtTypeTokens.labelMedium,
    labelSmall: TtTypeTokens.labelSmall,
  );

  // tt-style.css: .style-tt .appbar.big .title
  static final TextStyle _pageTitle = _display(
    fontSize: 34,
    height: 40 / 34,
    weight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  // tt-style.css: .style-tt .rd-head h1 (also onboarding h1)
  static final TextStyle _detailTitle = _display(
    fontSize: 30,
    height: 36 / 30,
    weight: FontWeight.w800,
    letterSpacing: -1,
  );

  // tt-style.css: .style-tt .appbar .title .t-tl
  static final TextStyle _screenTitle = _display(
    fontSize: 20,
    height: 26 / 20,
    weight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  // tt-style.css: .style-tt .dlg h2
  static final TextStyle _dialogTitle = _display(
    fontSize: 22,
    height: 28 / 22,
    weight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  // tt-style.css: .style-tt .shoot.on .txt b
  static final TextStyle _shootTitle = _display(
    fontSize: 19,
    height: 24 / 19,
    weight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  // tt-style.css: .style-tt .rcard .nm
  static final TextStyle _cardTitle = _display(
    fontSize: 15,
    height: 19 / 15,
    weight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  // tt-style.css: .style-tt .li-h (shown upper case by the component)
  static final TextStyle _groupLabel = _display(
    fontSize: 12,
    height: 16 / 12,
    weight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  // tt-style.css: .style-tt .navbar .it
  static final TextStyle _navLabel = _display(
    fontSize: 11.5,
    height: 14 / 11.5,
    weight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// A TakeTray display style in the app font.
  static TextStyle _display({
    required double fontSize,
    required double height,
    required FontWeight weight,
    required double letterSpacing,
  }) => TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: fontSize,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: letterSpacing,
  ).merge(TtTextStyles.weight(weight));

  /// The token type scale, with the scheme's colours applied.
  final TextTheme material;

  /// Big page title in the top app bar: 34/40, weight 800, -1.2.
  final TextStyle pageTitle;

  /// Reel detail and onboarding heading: 30/36, weight 800, -1.0.
  final TextStyle detailTitle;

  /// Title in a standard top app bar: 20/26, weight 800, -0.4.
  final TextStyle screenTitle;

  /// Dialog title: 22/28, weight 800, -0.4.
  final TextStyle dialogTitle;

  /// Shooting mode card title when on: 19/24, weight 800, -0.3.
  final TextStyle shootTitle;

  /// Reel name on a reel card: 15/19, weight 700, -0.1.
  final TextStyle cardTitle;

  /// Grouped-list section label: 12/16, weight 700, +0.8.
  final TextStyle groupLabel;

  /// Nav pill label: 11.5/14, weight 600, +0.2.
  final TextStyle navLabel;

  /// [s] with tabular figures, so durations, counts and times line up.
  TextStyle numeric(TextStyle s) => s.copyWith(
    fontFeatures: [...?s.fontFeatures, const FontFeature.tabularFigures()],
  );

  /// Linearly interpolates every style between this and [other].
  TtTextStyles lerp(TtTextStyles other, double t) {
    TextStyle mix(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return TtTextStyles(
      material: TextTheme.lerp(material, other.material, t),
      pageTitle: mix(pageTitle, other.pageTitle),
      detailTitle: mix(detailTitle, other.detailTitle),
      screenTitle: mix(screenTitle, other.screenTitle),
      dialogTitle: mix(dialogTitle, other.dialogTitle),
      shootTitle: mix(shootTitle, other.shootTitle),
      cardTitle: mix(cardTitle, other.cardTitle),
      groupLabel: mix(groupLabel, other.groupLabel),
      navLabel: mix(navLabel, other.navLabel),
    );
  }
}
