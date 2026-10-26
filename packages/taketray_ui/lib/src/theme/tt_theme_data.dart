import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_colors.dart';
import 'package:taketray_ui/src/theme/tt_motion.dart';
import 'package:taketray_ui/src/theme/tt_radii.dart';
import 'package:taketray_ui/src/theme/tt_sizes.dart';
import 'package:taketray_ui/src/theme/tt_spacing.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';

/// Everything a TakeTray widget reads from the theme besides the Material
/// colour roles: colours, text styles, spacing, radii, motion and sizes.
///
/// `TakeTrayTheme` installs one per theme as a [ThemeExtension]; widgets read
/// it with `context.tt`, which also applies "remove animations".
@immutable
class TtThemeData extends ThemeExtension<TtThemeData> {
  /// Theme data with the given parts; [spacing], [radii], [motion] and [sizes]
  /// default to the token values.
  const new({
    required this.colors,
    required this.text,
    this.spacing = const TtSpacing(),
    this.radii = const TtRadii(),
    this.motion = TtMotion.standardSet,
    this.sizes = const TtSizes(),
  });

  /// The TakeTray theme data for [scheme] (the scheme the theme uses).
  factory fromScheme(ColorScheme scheme) => TtThemeData(
    colors: TtColors.fromScheme(scheme),
    text: TtTextStyles.fromScheme(scheme),
  );

  /// Colours Material 3 has no role for.
  final TtColors colors;

  /// Material type scale and TakeTray display styles.
  final TtTextStyles text;

  /// Spacing scale.
  final TtSpacing spacing;

  /// Corner radius scale.
  final TtRadii radii;

  /// Durations and curves ([TtMotion.reduced] through `context.tt` when
  /// animations are removed).
  final TtMotion motion;

  /// Fixed sizes.
  final TtSizes sizes;

  @override
  TtThemeData copyWith({
    TtColors? colors,
    TtTextStyles? text,
    TtSpacing? spacing,
    TtRadii? radii,
    TtMotion? motion,
    TtSizes? sizes,
  }) => TtThemeData(
    colors: colors ?? this.colors,
    text: text ?? this.text,
    spacing: spacing ?? this.spacing,
    radii: radii ?? this.radii,
    motion: motion ?? this.motion,
    sizes: sizes ?? this.sizes,
  );

  /// Interpolates colours and text styles; spacing, radii, motion and sizes
  /// are the same in every theme, so they switch at the midpoint.
  @override
  TtThemeData lerp(covariant TtThemeData? other, double t) {
    if (other == null) return this;
    final near = t < 0.5 ? this : other;
    return TtThemeData(
      colors: colors.lerp(other.colors, t),
      text: text.lerp(other.text, t),
      spacing: near.spacing,
      radii: near.radii,
      motion: near.motion,
      sizes: near.sizes,
    );
  }
}

/// `context.tt` and `context.scheme`: how TakeTray widgets read the theme.
extension TtBuildContext on BuildContext {
  /// The theme's [TtThemeData], with [TtThemeData.motion] replaced by
  /// [TtMotion.reduced] when the system asks to remove animations.
  ///
  /// Throws if the theme was not built by `TakeTrayTheme`.
  TtThemeData get tt {
    final data = Theme.of(this).extension<TtThemeData>();
    if (data == null) {
      throw FlutterError(
        'context.tt found no TtThemeData.\n'
        'Use TakeTrayTheme.light(), .dark() or .video() as the theme.',
      );
    }
    if (MediaQuery.maybeDisableAnimationsOf(this) ?? false) {
      return data.copyWith(motion: TtMotion.reduced);
    }
    return data;
  }

  /// The theme's Material colour scheme.
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
