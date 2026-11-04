// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the viewer's sound is off. It starts on and is kept for the
/// session: the next clip, and the next time the viewer opens, are muted if
/// this one was. Not stored; a restart starts with sound.

@ProviderFor(ViewerMuted)
final viewerMutedProvider = ViewerMutedProvider._();

/// Whether the viewer's sound is off. It starts on and is kept for the
/// session: the next clip, and the next time the viewer opens, are muted if
/// this one was. Not stored; a restart starts with sound.
final class ViewerMutedProvider extends $NotifierProvider<ViewerMuted, bool> {
  /// Whether the viewer's sound is off. It starts on and is kept for the
  /// session: the next clip, and the next time the viewer opens, are muted if
  /// this one was. Not stored; a restart starts with sound.
  ViewerMutedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewerMutedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewerMutedHash();

  @$internal
  @override
  ViewerMuted create() => ViewerMuted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$viewerMutedHash() => r'9643a2c9748d6321805e6c2f3c6f740f7dcd6e2c';

/// Whether the viewer's sound is off. It starts on and is kept for the
/// session: the next clip, and the next time the viewer opens, are muted if
/// this one was. Not stored; a restart starts with sound.

abstract class _$ViewerMuted extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The player of the clip at [uri] (D-89): one `VideoPlayerController`
/// (ExoPlayer, from the gallery by its `content://` address, never copied),
/// opened, with the sound as the viewer's mute switch says, and playing.
///
/// - **One at a time.** The viewer watches the player of the page it shows
///   and nothing else. When the page changes it stops watching, the provider
///   is disposed, and the controller is disposed with it; when the screen is
///   popped the same happens. A page that was never shown never makes one.
/// - **A failure is an error value.** A video the phone cannot play
///   (damaged, an unsupported format, gone) makes the future throw. The
///   screen shows "This video can't be played"; it never plays another video.
/// - **It pauses when the app goes to the background** (`paused`, and
///   `hidden` just before it) and does not start again by itself when the
///   app returns: the user taps to play. The plugin's own lifecycle handling
///   is switched off (`allowBackgroundPlayback`), because it would resume a
///   video the user left.
/// - **The mute switch** is followed while the player lives.
///
/// - **[use]** says whose player it is: the clip viewer's
///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
///   clip keeps playing while the user decides.
///
/// - **[autoplay]** false opens the clip and leaves it paused (muted as the
///   switch says, looping for the tag player): the tag player keeps the next
///   clip open one ahead, and it must not be heard or move off screen. The
///   tag player always asks with it off, for the clip showing and the one
///   ahead alike (the same family entry, so the clip that comes up is the
///   controller that was opened), and plays the one showing itself.
///
/// Auto-disposes, and never retries: a video that failed once would open
/// again and again. The address is not logged.

@ProviderFor(clipPlayer)
final clipPlayerProvider = ClipPlayerFamily._();

/// The player of the clip at [uri] (D-89): one `VideoPlayerController`
/// (ExoPlayer, from the gallery by its `content://` address, never copied),
/// opened, with the sound as the viewer's mute switch says, and playing.
///
/// - **One at a time.** The viewer watches the player of the page it shows
///   and nothing else. When the page changes it stops watching, the provider
///   is disposed, and the controller is disposed with it; when the screen is
///   popped the same happens. A page that was never shown never makes one.
/// - **A failure is an error value.** A video the phone cannot play
///   (damaged, an unsupported format, gone) makes the future throw. The
///   screen shows "This video can't be played"; it never plays another video.
/// - **It pauses when the app goes to the background** (`paused`, and
///   `hidden` just before it) and does not start again by itself when the
///   app returns: the user taps to play. The plugin's own lifecycle handling
///   is switched off (`allowBackgroundPlayback`), because it would resume a
///   video the user left.
/// - **The mute switch** is followed while the player lives.
///
/// - **[use]** says whose player it is: the clip viewer's
///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
///   clip keeps playing while the user decides.
///
/// - **[autoplay]** false opens the clip and leaves it paused (muted as the
///   switch says, looping for the tag player): the tag player keeps the next
///   clip open one ahead, and it must not be heard or move off screen. The
///   tag player always asks with it off, for the clip showing and the one
///   ahead alike (the same family entry, so the clip that comes up is the
///   controller that was opened), and plays the one showing itself.
///
/// Auto-disposes, and never retries: a video that failed once would open
/// again and again. The address is not logged.

final class ClipPlayerProvider
    extends
        $FunctionalProvider<
          AsyncValue<VideoPlayerController>,
          VideoPlayerController,
          FutureOr<VideoPlayerController>
        >
    with
        $FutureModifier<VideoPlayerController>,
        $FutureProvider<VideoPlayerController> {
  /// The player of the clip at [uri] (D-89): one `VideoPlayerController`
  /// (ExoPlayer, from the gallery by its `content://` address, never copied),
  /// opened, with the sound as the viewer's mute switch says, and playing.
  ///
  /// - **One at a time.** The viewer watches the player of the page it shows
  ///   and nothing else. When the page changes it stops watching, the provider
  ///   is disposed, and the controller is disposed with it; when the screen is
  ///   popped the same happens. A page that was never shown never makes one.
  /// - **A failure is an error value.** A video the phone cannot play
  ///   (damaged, an unsupported format, gone) makes the future throw. The
  ///   screen shows "This video can't be played"; it never plays another video.
  /// - **It pauses when the app goes to the background** (`paused`, and
  ///   `hidden` just before it) and does not start again by itself when the
  ///   app returns: the user taps to play. The plugin's own lifecycle handling
  ///   is switched off (`allowBackgroundPlayback`), because it would resume a
  ///   video the user left.
  /// - **The mute switch** is followed while the player lives.
  ///
  /// - **[use]** says whose player it is: the clip viewer's
  ///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
  ///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
  ///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
  ///   clip keeps playing while the user decides.
  ///
  /// - **[autoplay]** false opens the clip and leaves it paused (muted as the
  ///   switch says, looping for the tag player): the tag player keeps the next
  ///   clip open one ahead, and it must not be heard or move off screen. The
  ///   tag player always asks with it off, for the clip showing and the one
  ///   ahead alike (the same family entry, so the clip that comes up is the
  ///   controller that was opened), and plays the one showing itself.
  ///
  /// Auto-disposes, and never retries: a video that failed once would open
  /// again and again. The address is not logged.
  ClipPlayerProvider._({
    required ClipPlayerFamily super.from,
    required (Uri, {ClipPlayerUse use, bool autoplay}) super.argument,
  }) : super(
         retry: noRetry,
         name: r'clipPlayerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clipPlayerHash();

  @override
  String toString() {
    return r'clipPlayerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<VideoPlayerController> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VideoPlayerController> create(Ref ref) {
    final argument = this.argument as (Uri, {ClipPlayerUse use, bool autoplay});
    return clipPlayer(
      ref,
      argument.$1,
      use: argument.use,
      autoplay: argument.autoplay,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ClipPlayerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clipPlayerHash() => r'381094b1be7b8f03ec973401502c6a24d97c02b2';

/// The player of the clip at [uri] (D-89): one `VideoPlayerController`
/// (ExoPlayer, from the gallery by its `content://` address, never copied),
/// opened, with the sound as the viewer's mute switch says, and playing.
///
/// - **One at a time.** The viewer watches the player of the page it shows
///   and nothing else. When the page changes it stops watching, the provider
///   is disposed, and the controller is disposed with it; when the screen is
///   popped the same happens. A page that was never shown never makes one.
/// - **A failure is an error value.** A video the phone cannot play
///   (damaged, an unsupported format, gone) makes the future throw. The
///   screen shows "This video can't be played"; it never plays another video.
/// - **It pauses when the app goes to the background** (`paused`, and
///   `hidden` just before it) and does not start again by itself when the
///   app returns: the user taps to play. The plugin's own lifecycle handling
///   is switched off (`allowBackgroundPlayback`), because it would resume a
///   video the user left.
/// - **The mute switch** is followed while the player lives.
///
/// - **[use]** says whose player it is: the clip viewer's
///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
///   clip keeps playing while the user decides.
///
/// - **[autoplay]** false opens the clip and leaves it paused (muted as the
///   switch says, looping for the tag player): the tag player keeps the next
///   clip open one ahead, and it must not be heard or move off screen. The
///   tag player always asks with it off, for the clip showing and the one
///   ahead alike (the same family entry, so the clip that comes up is the
///   controller that was opened), and plays the one showing itself.
///
/// Auto-disposes, and never retries: a video that failed once would open
/// again and again. The address is not logged.

final class ClipPlayerFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<VideoPlayerController>,
          (Uri, {ClipPlayerUse use, bool autoplay})
        > {
  ClipPlayerFamily._()
    : super(
        retry: noRetry,
        name: r'clipPlayerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The player of the clip at [uri] (D-89): one `VideoPlayerController`
  /// (ExoPlayer, from the gallery by its `content://` address, never copied),
  /// opened, with the sound as the viewer's mute switch says, and playing.
  ///
  /// - **One at a time.** The viewer watches the player of the page it shows
  ///   and nothing else. When the page changes it stops watching, the provider
  ///   is disposed, and the controller is disposed with it; when the screen is
  ///   popped the same happens. A page that was never shown never makes one.
  /// - **A failure is an error value.** A video the phone cannot play
  ///   (damaged, an unsupported format, gone) makes the future throw. The
  ///   screen shows "This video can't be played"; it never plays another video.
  /// - **It pauses when the app goes to the background** (`paused`, and
  ///   `hidden` just before it) and does not start again by itself when the
  ///   app returns: the user taps to play. The plugin's own lifecycle handling
  ///   is switched off (`allowBackgroundPlayback`), because it would resume a
  ///   video the user left.
  /// - **The mute switch** is followed while the player lives.
  ///
  /// - **[use]** says whose player it is: the clip viewer's
  ///   ([ClipPlayerUse.viewer], the default, unchanged) or the tag player's
  ///   ([ClipPlayerUse.tagging], D-96), which follows its own mute switch
  ///   (`TagPlayerMuted`, muted at first) and **loops** the clip, so a short
  ///   clip keeps playing while the user decides.
  ///
  /// - **[autoplay]** false opens the clip and leaves it paused (muted as the
  ///   switch says, looping for the tag player): the tag player keeps the next
  ///   clip open one ahead, and it must not be heard or move off screen. The
  ///   tag player always asks with it off, for the clip showing and the one
  ///   ahead alike (the same family entry, so the clip that comes up is the
  ///   controller that was opened), and plays the one showing itself.
  ///
  /// Auto-disposes, and never retries: a video that failed once would open
  /// again and again. The address is not logged.

  ClipPlayerProvider call(
    Uri uri, {
    ClipPlayerUse use = ClipPlayerUse.viewer,
    bool autoplay = true,
  }) => ClipPlayerProvider._(
    argument: (uri, use: use, autoplay: autoplay),
    from: this,
  );

  @override
  String toString() => r'clipPlayerProvider';
}
