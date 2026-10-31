// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'to_tag_times.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The time where each waiting clip was shot, by clip id (D-83): what the To
/// tag tiles show.
///
/// It follows the To tag list (`ToTagController`): each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws; a clip
/// missing from the map (a list that arrived while its times are still being
/// read) shows the phone's time.

@ProviderFor(toTagTimes)
final toTagTimesProvider = ToTagTimesProvider._();

/// The time where each waiting clip was shot, by clip id (D-83): what the To
/// tag tiles show.
///
/// It follows the To tag list (`ToTagController`): each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws; a clip
/// missing from the map (a list that arrived while its times are still being
/// read) shows the phone's time.

final class ToTagTimesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, ClipLocalTime>>,
          Map<int, ClipLocalTime>,
          FutureOr<Map<int, ClipLocalTime>>
        >
    with
        $FutureModifier<Map<int, ClipLocalTime>>,
        $FutureProvider<Map<int, ClipLocalTime>> {
  /// The time where each waiting clip was shot, by clip id (D-83): what the To
  /// tag tiles show.
  ///
  /// It follows the To tag list (`ToTagController`): each new list asks
  /// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
  /// so only new ones cost a bridge entry. The service never throws; a clip
  /// missing from the map (a list that arrived while its times are still being
  /// read) shows the phone's time.
  ToTagTimesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toTagTimesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toTagTimesHash();

  @$internal
  @override
  $FutureProviderElement<Map<int, ClipLocalTime>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, ClipLocalTime>> create(Ref ref) {
    return toTagTimes(ref);
  }
}

String _$toTagTimesHash() => r'4fabf85f9f3f8be9ebb213e56e295cf3af5d2a0c';
