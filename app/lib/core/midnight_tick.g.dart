// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'midnight_tick.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The phone's local date: midnight of today, in local time, now, and again
/// at every local midnight after that.
///
/// A screen that writes "since 9:41 AM" or "Oct 27, 9:41 PM" depending on the
/// day watches this, so it is built again when the day changes instead of
/// keeping yesterday's text until something else redraws it (D-86). The
/// value is the day; callers watch it for the change and read the time from
/// the `clockProvider`.
///
/// The timer is set for the next local midnight (`DateTime(y, m, d + 1)`),
/// not for 24 hours later, so a day with a daylight-saving change (23 or 25
/// hours) still ends at midnight. When the timer fires and the clock still
/// shows the same day (it fired a moment early, or the clock was set back),
/// nothing is emitted and the timer is set again. The timer is cancelled when
/// nothing watches the provider any more.

@ProviderFor(localDay)
final localDayProvider = LocalDayProvider._();

/// The phone's local date: midnight of today, in local time, now, and again
/// at every local midnight after that.
///
/// A screen that writes "since 9:41 AM" or "Oct 27, 9:41 PM" depending on the
/// day watches this, so it is built again when the day changes instead of
/// keeping yesterday's text until something else redraws it (D-86). The
/// value is the day; callers watch it for the change and read the time from
/// the `clockProvider`.
///
/// The timer is set for the next local midnight (`DateTime(y, m, d + 1)`),
/// not for 24 hours later, so a day with a daylight-saving change (23 or 25
/// hours) still ends at midnight. When the timer fires and the clock still
/// shows the same day (it fired a moment early, or the clock was set back),
/// nothing is emitted and the timer is set again. The timer is cancelled when
/// nothing watches the provider any more.

final class LocalDayProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// The phone's local date: midnight of today, in local time, now, and again
  /// at every local midnight after that.
  ///
  /// A screen that writes "since 9:41 AM" or "Oct 27, 9:41 PM" depending on the
  /// day watches this, so it is built again when the day changes instead of
  /// keeping yesterday's text until something else redraws it (D-86). The
  /// value is the day; callers watch it for the change and read the time from
  /// the `clockProvider`.
  ///
  /// The timer is set for the next local midnight (`DateTime(y, m, d + 1)`),
  /// not for 24 hours later, so a day with a daylight-saving change (23 or 25
  /// hours) still ends at midnight. When the timer fires and the clock still
  /// shows the same day (it fired a moment early, or the clock was set back),
  /// nothing is emitted and the timer is set again. The timer is cancelled when
  /// nothing watches the provider any more.
  LocalDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localDayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localDayHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return localDay(ref);
  }
}

String _$localDayHash() => r'9b310120171c480ad0b972a2dded1157a859e90d';
