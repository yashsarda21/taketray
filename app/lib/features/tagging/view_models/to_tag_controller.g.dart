// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'to_tag_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clips waiting in To tag, oldest first (D-75).
///
/// The state is the database's own list (`watchInbox(pending)`), so it shows
/// at once and follows every change: a scan that adds clips, a verify that
/// removes the ones whose video is gone, a tag or a skip.
///
/// Each time the state is built (the screen opens it, or it is opened again
/// after being closed) it also scans for new videos and then checks the
/// waiting clips still exist, once; [onResume] does both again. Neither
/// blocks the list and neither can fail it: an error is logged by type and
/// the list stays as the database has it. The scan and the verify each run
/// even if the other failed. Both go through the shared media queue (D-72),
/// so three triggers at once cost one more scan.

@ProviderFor(ToTagController)
final toTagControllerProvider = ToTagControllerProvider._();

/// The clips waiting in To tag, oldest first (D-75).
///
/// The state is the database's own list (`watchInbox(pending)`), so it shows
/// at once and follows every change: a scan that adds clips, a verify that
/// removes the ones whose video is gone, a tag or a skip.
///
/// Each time the state is built (the screen opens it, or it is opened again
/// after being closed) it also scans for new videos and then checks the
/// waiting clips still exist, once; [onResume] does both again. Neither
/// blocks the list and neither can fail it: an error is logged by type and
/// the list stays as the database has it. The scan and the verify each run
/// even if the other failed. Both go through the shared media queue (D-72),
/// so three triggers at once cost one more scan.
final class ToTagControllerProvider
    extends $StreamNotifierProvider<ToTagController, List<Clip>> {
  /// The clips waiting in To tag, oldest first (D-75).
  ///
  /// The state is the database's own list (`watchInbox(pending)`), so it shows
  /// at once and follows every change: a scan that adds clips, a verify that
  /// removes the ones whose video is gone, a tag or a skip.
  ///
  /// Each time the state is built (the screen opens it, or it is opened again
  /// after being closed) it also scans for new videos and then checks the
  /// waiting clips still exist, once; [onResume] does both again. Neither
  /// blocks the list and neither can fail it: an error is logged by type and
  /// the list stays as the database has it. The scan and the verify each run
  /// even if the other failed. Both go through the shared media queue (D-72),
  /// so three triggers at once cost one more scan.
  ToTagControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'toTagControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toTagControllerHash();

  @$internal
  @override
  ToTagController create() => ToTagController();
}

String _$toTagControllerHash() => r'942fe255c0729dca94a4bb4d15cd4d8d622af4d5';

/// The clips waiting in To tag, oldest first (D-75).
///
/// The state is the database's own list (`watchInbox(pending)`), so it shows
/// at once and follows every change: a scan that adds clips, a verify that
/// removes the ones whose video is gone, a tag or a skip.
///
/// Each time the state is built (the screen opens it, or it is opened again
/// after being closed) it also scans for new videos and then checks the
/// waiting clips still exist, once; [onResume] does both again. Neither
/// blocks the list and neither can fail it: an error is logged by type and
/// the list stays as the database has it. The scan and the verify each run
/// even if the other failed. Both go through the shared media queue (D-72),
/// so three triggers at once cost one more scan.

abstract class _$ToTagController extends $StreamNotifier<List<Clip>> {
  Stream<List<Clip>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Clip>>, List<Clip>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Clip>>, List<Clip>>,
              AsyncValue<List<Clip>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
