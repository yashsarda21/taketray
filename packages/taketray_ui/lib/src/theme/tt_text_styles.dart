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
  /// Text styles with every style given. Use [TtTextStyles.fromScheme].
  const new({
    required this.material,
    this.pageTitle = _pageTitle,
    this.detailTitle = _detailTitle,
    this.screenTitle = _screenTitle,
    this.dialogTitle = _dialogTitle,
    this.shootTitle = _shootTitle,
    this.cardTitle = _cardTitle,
    this.groupLabel = _groupLabel,
    this.navLabel = _navLabel,
  });

  /// The type scale with [scheme]'s `onSurface` applied.
  factory fromScheme(ColorScheme scheme) => TtTextStyles(
    material: materialTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
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
  static const _pageTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 34,
    height: 40 / 34,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -1.2,
  );

  // tt-style.css: .style-tt .rd-head h1 (also onboarding h1)
  static const _detailTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 30,
    height: 36 / 30,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -1,
  );

  // tt-style.css: .style-tt .appbar .title .t-tl
  static const _screenTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 20,
    height: 26 / 20,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -0.4,
  );

  // tt-style.css: .style-tt .dlg h2
  static const _dialogTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 22,
    height: 28 / 22,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -0.4,
  );

  // tt-style.css: .style-tt .shoot.on .txt b
  static const _shootTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 19,
    height: 24 / 19,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -0.3,
  );

  // tt-style.css: .style-tt .rcard .nm
  static const _cardTitle = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 15,
    height: 19 / 15,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: -0.1,
  );

  // tt-style.css: .style-tt .li-h (shown upper case by the component)
  static const _groupLabel = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 12,
    height: 16 / 12,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: 0.8,
  );

  // tt-style.css: .style-tt .navbar .it
  static const _navLabel = TextStyle(
    fontFamily: TtTypeTokens.fontFamily,
    package: TtTypeTokens.fontPackage,
    fontSize: 11.5,
    height: 14 / 11.5,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: 0.2,
  );

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
