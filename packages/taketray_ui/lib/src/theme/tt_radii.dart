import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Corner radius scale from the design tokens. Read it as `context.tt.radii`.
///
/// Radii that only one component uses (the dialog's 32 dp, the snackbar's
/// 18 dp) live in `TtMetrics`.
class TtRadii {
  /// The token radius scale; the same in every theme.
  const new();

  /// 4 dp.
  double get xs => TtRadiusTokens.extraSmall;

  /// 8 dp.
  double get s => TtRadiusTokens.small;

  /// 12 dp.
  double get m => TtRadiusTokens.medium;

  /// 16 dp.
  double get l => TtRadiusTokens.large;

  /// 20 dp.
  double get xl => TtRadiusTokens.largeIncreased;

  /// 28 dp.
  double get xxl => TtRadiusTokens.extraLarge;

  /// Fully rounded (pill, circle).
  double get full => TtRadiusTokens.full;
}
