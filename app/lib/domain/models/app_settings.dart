import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// The user's settings.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// Folders (relative to the storage root) scanned for new clips.
    @Default(['DCIM/Camera']) List<String> watchedFolders,
    @Default(true) bool eveningReminderEnabled,

    /// Minutes after local midnight; 1260 is 21:00.
    @Default(1260) int eveningReminderMinutes,

    /// Whether "Still shooting?" is asked after two weeks of Shooting mode
    /// (D-145).
    @Default(true) bool stillReminderEnabled,

    /// Whether a session's copies are reminded about, to delete them (D-145).
    @Default(true) bool copiesReminderEnabled,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
