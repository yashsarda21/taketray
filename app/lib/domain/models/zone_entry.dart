import 'package:freezed_annotation/freezed_annotation.dart';

part 'zone_entry.freezed.dart';
part 'zone_entry.g.dart';

/// "From this moment on, the phone was in this time zone" (spec §8.3a).
@freezed
abstract class ZoneEntry with _$ZoneEntry {
  const factory ZoneEntry({required DateTime at, required String zoneId}) =
      _ZoneEntry;

  factory ZoneEntry.fromJson(Map<String, dynamic> json) =>
      _$ZoneEntryFromJson(json);
}
