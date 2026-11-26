// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'choosing_reel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reel whose page is choosing clips, if any: AppShell shows its dock in
/// place of the nav pill (D-191).
///
/// The reel's page says so: [show] while its selection is choosing, [hide]
/// when choosing ends or the page goes. Neither is called while a widget
/// builds (a provider must not change then): the page calls them from a
/// listener on its selection, and after a frame.

@ProviderFor(ChoosingReel)
final choosingReelProvider = ChoosingReelProvider._();

/// The reel whose page is choosing clips, if any: AppShell shows its dock in
/// place of the nav pill (D-191).
///
/// The reel's page says so: [show] while its selection is choosing, [hide]
/// when choosing ends or the page goes. Neither is called while a widget
/// builds (a provider must not change then): the page calls them from a
/// listener on its selection, and after a frame.
final class ChoosingReelProvider extends $NotifierProvider<ChoosingReel, int?> {
  /// The reel whose page is choosing clips, if any: AppShell shows its dock in
  /// place of the nav pill (D-191).
  ///
  /// The reel's page says so: [show] while its selection is choosing, [hide]
  /// when choosing ends or the page goes. Neither is called while a widget
  /// builds (a provider must not change then): the page calls them from a
  /// listener on its selection, and after a frame.
  ChoosingReelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'choosingReelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$choosingReelHash();

  @$internal
  @override
  ChoosingReel create() => ChoosingReel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$choosingReelHash() => r'2802b8e3a9a6a1039093682eb078dcba05ed6ec4';

/// The reel whose page is choosing clips, if any: AppShell shows its dock in
/// place of the nav pill (D-191).
///
/// The reel's page says so: [show] while its selection is choosing, [hide]
/// when choosing ends or the page goes. Neither is called while a widget
/// builds (a provider must not change then): the page calls them from a
/// listener on its selection, and after a frame.

abstract class _$ChoosingReel extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
