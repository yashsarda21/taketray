import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Colours Material 3 has no role for. Read them as `context.tt.colors`; the
/// Material roles are on `context.scheme`.
@immutable
class TtColors {
  /// Colours with every role given. Use [TtColors.fromScheme].
  const new({
    required this.waiting,
    required this.onWaiting,
    required this.waitingContainer,
    required this.onWaitingContainer,
    required this.record,
    required this.onRecord,
    required this.recordContainer,
    required this.onRecordContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.hairline,
    required this.glass,
    required this.glassOnMedia,
    required this.onMedia,
    required this.onMediaVariant,
    required this.mediaScrimEnd,
    required this.missingOnMedia,
    required this.recordOnMedia,
    required this.readyOnMedia,
    required this.publishedOnMedia,
    required this.videoBackground,
    required this.videoScrimTop,
    required this.videoScrimBottom,
    required this.onVideo,
    required this.onVideoVariant,
  });

  /// The TakeTray colours for [scheme] (light or dark by its brightness).
  ///
  /// [scheme] is the scheme the theme uses, after the OLED override, so the
  /// glass and hairline match the surfaces they sit on.
  factory fromScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return TtColors(
      waiting: scheme.tertiary,
      onWaiting: scheme.onTertiary,
      waitingContainer: scheme.tertiaryContainer,
      onWaitingContainer: scheme.onTertiaryContainer,
      record: light ? TtColorTokens.lightRecord : TtColorTokens.darkRecord,
      onRecord: light
          ? TtColorTokens.lightOnRecord
          : TtColorTokens.darkOnRecord,
      recordContainer: light
          ? TtColorTokens.lightRecordContainer
          : TtColorTokens.darkRecordContainer,
      onRecordContainer: light
          ? TtColorTokens.lightOnRecordContainer
          : TtColorTokens.darkOnRecordContainer,
      success: light ? TtColorTokens.lightSuccess : TtColorTokens.darkSuccess,
      onSuccess: light
          ? TtColorTokens.lightOnSuccess
          : TtColorTokens.darkOnSuccess,
      successContainer: light
          ? TtColorTokens.lightSuccessContainer
          : TtColorTokens.darkSuccessContainer,
      onSuccessContainer: light
          ? TtColorTokens.lightOnSuccessContainer
          : TtColorTokens.darkOnSuccessContainer,
      hairline: scheme.onSurface.withValues(alpha: TtMetrics.hairlineOpacity),
      glass: scheme.surfaceContainerHigh.withValues(
        alpha: TtMetrics.glassOpacity,
      ),
      // tt-style.css: .style-tt .rcard .cover .pill { rgba(14,12,20,.58) }
      glassOnMedia: const Color(0x940E0C14),
      // tt-style.css: .style-tt .rcard .nm { color: #fff }
      onMedia: const Color(0xFFFFFFFF),
      onMediaVariant: const Color(0xFFFFFFFF)
          .withValues(alpha: TtMetrics.onMediaVariantOpacity),
      mediaScrimEnd: const Color(0xFF000000)
          .withValues(alpha: TtMetrics.mediaScrimEndOpacity),
      // tt-style.css: .style-tt .rcard .mt .miss { color: #FFB4AB }
      missingOnMedia: const Color(0xFFFFB4AB),
      // tt-style.css: .rcard .cover .pill.rec / .ready / .pub .ms: the dark
      // theme's record, primary and success, in both themes.
      recordOnMedia: TtColorTokens.darkRecord,
      readyOnMedia: ttDarkScheme.primary,
      publishedOnMedia: TtColorTokens.darkSuccess,
      videoBackground: TtColorTokens.videoBackground,
      videoScrimTop: TtColorTokens.videoScrimTop,
      videoScrimBottom: TtColorTokens.videoScrimBottom,
      onVideo: TtColorTokens.onVideo,
      onVideoVariant: TtColorTokens.onVideoVariant,
    );
  }

  /// "Clips waiting" marigold (the scheme's tertiary).
  final Color waiting;

  /// Content on [waiting].
  final Color onWaiting;

  /// Vivid marigold fill for "clips waiting" (the scheme's tertiary
  /// container).
  final Color waitingContainer;

  /// Content on [waitingContainer].
  final Color onWaitingContainer;

  /// REC red: Shooting mode on, "Recording" status.
  final Color record;

  /// Content on [record].
  final Color onRecord;

  /// Soft REC red fill.
  final Color recordContainer;

  /// Content on [recordContainer].
  final Color onRecordContainer;

  /// Success green: "Published", "All caught up".
  final Color success;

  /// Content on [success].
  final Color onSuccess;

  /// Soft success fill.
  final Color successContainer;

  /// Content on [successContainer].
  final Color onSuccessContainer;

  /// Hairline border on cards and floating chrome (onSurface at 9 %).
  final Color hairline;

  /// Glass fill of floating chrome (surfaceContainerHigh at 78 %), drawn over
  /// a background blur of `TtMetrics.glassBlur`.
  final Color glass;

  /// Dark glass behind badges on media.
  final Color glassOnMedia;

  /// Text and icons on media (white).
  final Color onMedia;

  /// Secondary text on media (white at 82 %).
  final Color onMediaVariant;

  /// End of the scrim gradient under text on media (black at 80 %).
  final Color mediaScrimEnd;

  /// "Missing clips" text on media.
  final Color missingOnMedia;

  /// "Recording" icon on media.
  final Color recordOnMedia;

  /// "Ready" icon on media.
  final Color readyOnMedia;

  /// "Published" icon on media.
  final Color publishedOnMedia;

  /// Behind video in the tag player and clip viewer (true black).
  final Color videoBackground;

  /// Scrim at the top of a video, under its controls.
  final Color videoScrimTop;

  /// Scrim at the bottom of a video, under its controls.
  final Color videoScrimBottom;

  /// Text and icons on video.
  final Color onVideo;

  /// Secondary text on video.
  final Color onVideoVariant;

  /// Linearly interpolates every colour between this and [other].
  TtColors lerp(TtColors other, double t) {
    final a = this;
    final b = other;
    Color mix(Color x, Color y) => Color.lerp(x, y, t)!;
    return TtColors(
      waiting: mix(a.waiting, b.waiting),
      onWaiting: mix(a.onWaiting, b.onWaiting),
      waitingContainer: mix(a.waitingContainer, b.waitingContainer),
      onWaitingContainer: mix(a.onWaitingContainer, b.onWaitingContainer),
      record: mix(a.record, b.record),
      onRecord: mix(a.onRecord, b.onRecord),
      recordContainer: mix(a.recordContainer, b.recordContainer),
      onRecordContainer: mix(a.onRecordContainer, b.onRecordContainer),
      success: mix(a.success, b.success),
      onSuccess: mix(a.onSuccess, b.onSuccess),
      successContainer: mix(a.successContainer, b.successContainer),
      onSuccessContainer: mix(a.onSuccessContainer, b.onSuccessContainer),
      hairline: mix(a.hairline, b.hairline),
      glass: mix(a.glass, b.glass),
      glassOnMedia: mix(a.glassOnMedia, b.glassOnMedia),
      onMedia: mix(a.onMedia, b.onMedia),
      onMediaVariant: mix(a.onMediaVariant, b.onMediaVariant),
      mediaScrimEnd: mix(a.mediaScrimEnd, b.mediaScrimEnd),
      missingOnMedia: mix(a.missingOnMedia, b.missingOnMedia),
      recordOnMedia: mix(a.recordOnMedia, b.recordOnMedia),
      readyOnMedia: mix(a.readyOnMedia, b.readyOnMedia),
      publishedOnMedia: mix(a.publishedOnMedia, b.publishedOnMedia),
      videoBackground: mix(a.videoBackground, b.videoBackground),
      videoScrimTop: mix(a.videoScrimTop, b.videoScrimTop),
      videoScrimBottom: mix(a.videoScrimBottom, b.videoScrimBottom),
      onVideo: mix(a.onVideo, b.onVideo),
      onVideoVariant: mix(a.onVideoVariant, b.onVideoVariant),
    );
  }
}
