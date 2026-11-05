import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';

/// The screen a notification tap opens (D-107).
///
/// An allow-list: Android sends a [LaunchAction], never a location, so no
/// other app can make TakeTray open an arbitrary route (D-101).
///
/// - [LaunchAction.toTag]: the new-clips notification (its body and Tag now)
///   and the evening reminder open To tag.
/// - [LaunchAction.reels]: the "Still shooting?" notification opens Reels,
///   where the dialog asks (`StillShootingPromptHost`).
String routeFor(LaunchAction action) => switch (action) {
  LaunchAction.toTag => Routes.toTag,
  LaunchAction.reels => Routes.reels,
};
