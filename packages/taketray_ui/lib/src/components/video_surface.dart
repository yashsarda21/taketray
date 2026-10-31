import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taketray_ui/src/components/internal/scrim.dart';
import 'package:taketray_ui/src/components/internal/system_ui.dart';
import 'package:taketray_ui/src/theme/take_tray_theme.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The black ground of the tag player and the clip viewer.
///
/// Applies [TakeTrayTheme.video] to everything under it, whatever the app
/// theme is, so the controls on video are always the dark ones ("The tag
/// player and clip viewer are always dark, on black"). It fills the space it
/// is given, or its [child] when that is unconstrained.
///
/// With [scrims], a dark gradient fades in behind the top and the bottom
/// edge so white controls stay readable over bright footage. The scrims do
/// not take touches and are not announced.
class TtVideoSurface extends StatelessWidget {
  /// A black surface around [child].
  const new({required this.child, this.scrims = false, super.key});

  /// What is drawn on the black: the video and its controls.
  final Widget child;

  /// Whether the top and bottom gradient scrims are drawn over [child].
  final bool scrims;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TakeTrayTheme.video(),
      child: Builder(
        builder: (context) {
          final colors = context.tt.colors;
          // Black ground: light system bar icons, whatever the app theme is
          // (D-51).
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: ttSystemUiStyle(colors.videoBackground),
            child: Material(
              color: colors.videoBackground,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  child,
                  if (scrims) ...[
                    // proto.css: .viewer .vtop / .vbot gradients
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: TtMetrics.videoScrimTopHeight,
                      child: Scrim(top: true, color: colors.videoScrimTop),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: TtMetrics.videoScrimBottomHeight,
                      child: Scrim(
                        top: false,
                        color: colors.videoScrimBottom,
                        solid: TtMetrics.videoScrimBottomSolid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
