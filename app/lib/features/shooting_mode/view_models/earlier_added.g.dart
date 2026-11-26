// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earlier_added.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Add earlier videos added clips while this Shooting mode session
/// was on: the "on" card's **Earlier videos** chip then hides (the handoff,
/// `home-calm-grid.md:46`, and the prototype's `earlierUsed`; D-196, ruling
/// R12B-2).
///
/// - [markAdded] (called by the sheet after an add) sets it.
/// - It clears whenever Shooting mode turns on or off, so a new session shows
///   the chip again, and an add made while it was off (from To tag's menu)
///   never hides the chip of a later session. A new state of the same
///   session (the stored state written again) keeps it.
/// - Undo does not clear it, and it is never stored: a restart shows the chip
///   again. The old stored `earlierAdded` flag (before D-90) is not read.
///
/// Kept alive: Home is not always on screen when the sheet adds (To tag's
/// menu opens it too).

@ProviderFor(EarlierAddedThisSession)
final earlierAddedThisSessionProvider = EarlierAddedThisSessionProvider._();

/// Whether Add earlier videos added clips while this Shooting mode session
/// was on: the "on" card's **Earlier videos** chip then hides (the handoff,
/// `home-calm-grid.md:46`, and the prototype's `earlierUsed`; D-196, ruling
/// R12B-2).
///
/// - [markAdded] (called by the sheet after an add) sets it.
/// - It clears whenever Shooting mode turns on or off, so a new session shows
///   the chip again, and an add made while it was off (from To tag's menu)
///   never hides the chip of a later session. A new state of the same
///   session (the stored state written again) keeps it.
/// - Undo does not clear it, and it is never stored: a restart shows the chip
///   again. The old stored `earlierAdded` flag (before D-90) is not read.
///
/// Kept alive: Home is not always on screen when the sheet adds (To tag's
/// menu opens it too).
final class EarlierAddedThisSessionProvider
    extends $NotifierProvider<EarlierAddedThisSession, bool> {
  /// Whether Add earlier videos added clips while this Shooting mode session
  /// was on: the "on" card's **Earlier videos** chip then hides (the handoff,
  /// `home-calm-grid.md:46`, and the prototype's `earlierUsed`; D-196, ruling
  /// R12B-2).
  ///
  /// - [markAdded] (called by the sheet after an add) sets it.
  /// - It clears whenever Shooting mode turns on or off, so a new session shows
  ///   the chip again, and an add made while it was off (from To tag's menu)
  ///   never hides the chip of a later session. A new state of the same
  ///   session (the stored state written again) keeps it.
  /// - Undo does not clear it, and it is never stored: a restart shows the chip
  ///   again. The old stored `earlierAdded` flag (before D-90) is not read.
  ///
  /// Kept alive: Home is not always on screen when the sheet adds (To tag's
  /// menu opens it too).
  EarlierAddedThisSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'earlierAddedThisSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$earlierAddedThisSessionHash();

  @$internal
  @override
  EarlierAddedThisSession create() => EarlierAddedThisSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$earlierAddedThisSessionHash() =>
    r'3d42ae7d963e7d52d7c03f2e5c956a8a8bcefc3a';

/// Whether Add earlier videos added clips while this Shooting mode session
/// was on: the "on" card's **Earlier videos** chip then hides (the handoff,
/// `home-calm-grid.md:46`, and the prototype's `earlierUsed`; D-196, ruling
/// R12B-2).
///
/// - [markAdded] (called by the sheet after an add) sets it.
/// - It clears whenever Shooting mode turns on or off, so a new session shows
///   the chip again, and an add made while it was off (from To tag's menu)
///   never hides the chip of a later session. A new state of the same
///   session (the stored state written again) keeps it.
/// - Undo does not clear it, and it is never stored: a restart shows the chip
///   again. The old stored `earlierAdded` flag (before D-90) is not read.
///
/// Kept alive: Home is not always on screen when the sheet adds (To tag's
/// menu opens it too).

abstract class _$EarlierAddedThisSession extends $Notifier<bool> {
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
