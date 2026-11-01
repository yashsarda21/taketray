import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Material 3 durations and easing curves from the design tokens.
///
/// Read it as `context.tt.motion`, which is [reduced] when the system asks to
/// remove animations, so a widget that animates with these durations stops
/// animating without its own check.
@immutable
class TtMotion {
  /// Motion with the given durations and curves. Use [standardSet] or
  /// [reduced].
  const new({
    required this.short1,
    required this.short2,
    required this.short3,
    required this.short4,
    required this.medium1,
    required this.medium2,
    required this.medium3,
    required this.medium4,
    required this.long1,
    required this.long2,
    required this.stagger,
    this.standard = TtMotionTokens.standard,
    this.standardDecelerate = TtMotionTokens.standardDecelerate,
    this.standardAccelerate = TtMotionTokens.standardAccelerate,
    this.emphasizedDecelerate = TtMotionTokens.emphasizedDecelerate,
    this.emphasizedAccelerate = TtMotionTokens.emphasizedAccelerate,
  });

  /// The token durations and curves.
  static const TtMotion standardSet = TtMotion(
    short1: TtMotionTokens.short1,
    short2: TtMotionTokens.short2,
    short3: TtMotionTokens.short3,
    short4: TtMotionTokens.short4,
    medium1: TtMotionTokens.medium1,
    medium2: TtMotionTokens.medium2,
    medium3: TtMotionTokens.medium3,
    medium4: TtMotionTokens.medium4,
    long1: TtMotionTokens.long1,
    long2: TtMotionTokens.long2,
    // The prototype's Motion note ("Scene tagging").
    stagger: Duration(milliseconds: 30),
  );

  /// "Remove animations": every duration is zero; the curves are unchanged.
  static const TtMotion reduced = TtMotion(
    short1: Duration.zero,
    short2: Duration.zero,
    short3: Duration.zero,
    short4: Duration.zero,
    medium1: Duration.zero,
    medium2: Duration.zero,
    medium3: Duration.zero,
    medium4: Duration.zero,
    long1: Duration.zero,
    long2: Duration.zero,
    stagger: Duration.zero,
  );

  /// 50 ms.
  final Duration short1;

  /// 100 ms.
  final Duration short2;

  /// 150 ms.
  final Duration short3;

  /// 200 ms.
  final Duration short4;

  /// 250 ms.
  final Duration medium1;

  /// 300 ms.
  final Duration medium2;

  /// 350 ms.
  final Duration medium3;

  /// 400 ms.
  final Duration medium4;

  /// 450 ms.
  final Duration long1;

  /// 500 ms.
  final Duration long2;

  /// The delay between one item of a staggered run and the next (30 ms),
  /// such as tiles leaving a list one after another.
  final Duration stagger;

  /// Standard easing: begins and ends on screen.
  final Curve standard;

  /// Standard decelerate: enters the screen.
  final Curve standardDecelerate;

  /// Standard accelerate: leaves the screen.
  final Curve standardAccelerate;

  /// Emphasized decelerate: an emphasized element enters.
  final Curve emphasizedDecelerate;

  /// Emphasized accelerate: an emphasized element leaves.
  final Curve emphasizedAccelerate;

  /// Whether every duration is zero (as in [reduced]).
  bool get isReduced => this == reduced;

  @override
  bool operator ==(Object other) =>
      other is TtMotion &&
      other.short1 == short1 &&
      other.short2 == short2 &&
      other.short3 == short3 &&
      other.short4 == short4 &&
      other.medium1 == medium1 &&
      other.medium2 == medium2 &&
      other.medium3 == medium3 &&
      other.medium4 == medium4 &&
      other.long1 == long1 &&
      other.long2 == long2 &&
      other.stagger == stagger &&
      other.standard == standard &&
      other.standardDecelerate == standardDecelerate &&
      other.standardAccelerate == standardAccelerate &&
      other.emphasizedDecelerate == emphasizedDecelerate &&
      other.emphasizedAccelerate == emphasizedAccelerate;

  @override
  int get hashCode => Object.hash(
    short1,
    short2,
    short3,
    short4,
    medium1,
    medium2,
    medium3,
    medium4,
    long1,
    long2,
    stagger,
    standard,
    standardDecelerate,
    standardAccelerate,
    emphasizedDecelerate,
    emphasizedAccelerate,
  );
}
