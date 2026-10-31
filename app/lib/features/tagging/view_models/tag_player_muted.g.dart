// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_player_muted.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the tag player's sound is off (D-96). It **starts muted** (the
/// design prompt, §6.3: "muted by default, with an unmute control"), and the
/// choice is kept for the app session: the next clip, and the next time the
/// player opens, sound the same. Not stored; a restart starts
/// muted again. The clip viewer has its own switch (`ViewerMuted`, D-89).

@ProviderFor(TagPlayerMuted)
final tagPlayerMutedProvider = TagPlayerMutedProvider._();

/// Whether the tag player's sound is off (D-96). It **starts muted** (the
/// design prompt, §6.3: "muted by default, with an unmute control"), and the
/// choice is kept for the app session: the next clip, and the next time the
/// player opens, sound the same. Not stored; a restart starts
/// muted again. The clip viewer has its own switch (`ViewerMuted`, D-89).
final class TagPlayerMutedProvider
    extends $NotifierProvider<TagPlayerMuted, bool> {
  /// Whether the tag player's sound is off (D-96). It **starts muted** (the
  /// design prompt, §6.3: "muted by default, with an unmute control"), and the
  /// choice is kept for the app session: the next clip, and the next time the
  /// player opens, sound the same. Not stored; a restart starts
  /// muted again. The clip viewer has its own switch (`ViewerMuted`, D-89).
  TagPlayerMutedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagPlayerMutedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagPlayerMutedHash();

  @$internal
  @override
  TagPlayerMuted create() => TagPlayerMuted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$tagPlayerMutedHash() => r'99c0399dac37959f6fbc5aaf78bb1c246fc79952';

/// Whether the tag player's sound is off (D-96). It **starts muted** (the
/// design prompt, §6.3: "muted by default, with an unmute control"), and the
/// choice is kept for the app session: the next clip, and the next time the
/// player opens, sound the same. Not stored; a restart starts
/// muted again. The clip viewer has its own switch (`ViewerMuted`, D-89).

abstract class _$TagPlayerMuted extends $Notifier<bool> {
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
