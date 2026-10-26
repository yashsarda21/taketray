// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettings {

/// Folders (relative to the storage root) scanned for new clips.
 List<String> get watchedFolders; bool get eveningReminderEnabled;/// Minutes after local midnight; 1260 is 21:00.
 int get eveningReminderMinutes;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AppSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&const DeepCollectionEquality().equals(other.watchedFolders, _this.watchedFolders)&&(identical(other.eveningReminderEnabled, _this.eveningReminderEnabled) || other.eveningReminderEnabled == _this.eveningReminderEnabled)&&(identical(other.eveningReminderMinutes, _this.eveningReminderMinutes) || other.eveningReminderMinutes == _this.eveningReminderMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AppSettings;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.watchedFolders),_this.eveningReminderEnabled,_this.eveningReminderMinutes);
}

@override
String toString() {
  final _this = this as AppSettings;
  return 'AppSettings(watchedFolders: ${_this.watchedFolders}, eveningReminderEnabled: ${_this.eveningReminderEnabled}, eveningReminderMinutes: ${_this.eveningReminderMinutes})';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 List<String> watchedFolders, bool eveningReminderEnabled, int eveningReminderMinutes
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? watchedFolders = null,Object? eveningReminderEnabled = null,Object? eveningReminderMinutes = null,}) {
  return _then(AppSettings(
watchedFolders: null == watchedFolders ? _self.watchedFolders : watchedFolders // ignore: cast_nullable_to_non_nullable
as List<String>,eveningReminderEnabled: null == eveningReminderEnabled ? _self.eveningReminderEnabled : eveningReminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,eveningReminderMinutes: null == eveningReminderMinutes ? _self.eveningReminderMinutes : eveningReminderMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> watchedFolders,  bool eveningReminderEnabled,  int eveningReminderMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.watchedFolders,_that.eveningReminderEnabled,_that.eveningReminderMinutes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> watchedFolders,  bool eveningReminderEnabled,  int eveningReminderMinutes)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.watchedFolders,_that.eveningReminderEnabled,_that.eveningReminderMinutes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> watchedFolders,  bool eveningReminderEnabled,  int eveningReminderMinutes)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.watchedFolders,_that.eveningReminderEnabled,_that.eveningReminderMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettings implements AppSettings {
  const _AppSettings({ List<String> watchedFolders = const ['DCIM/Camera'], this.eveningReminderEnabled = true, this.eveningReminderMinutes = 1260}): _watchedFolders = watchedFolders;
  factory _AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);

/// Folders (relative to the storage root) scanned for new clips.
 final  List<String> _watchedFolders;
/// Folders (relative to the storage root) scanned for new clips.
@override@JsonKey() List<String> get watchedFolders {
  if (_watchedFolders is EqualUnmodifiableListView) return _watchedFolders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_watchedFolders);
}

@override@JsonKey() final  bool eveningReminderEnabled;
/// Minutes after local midnight; 1260 is 21:00.
@override@JsonKey() final  int eveningReminderMinutes;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&const DeepCollectionEquality().equals(other.watchedFolders, _watchedFolders)&&(identical(other.eveningReminderEnabled, eveningReminderEnabled) || other.eveningReminderEnabled == eveningReminderEnabled)&&(identical(other.eveningReminderMinutes, eveningReminderMinutes) || other.eveningReminderMinutes == eveningReminderMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_watchedFolders),eveningReminderEnabled,eveningReminderMinutes);
}

@override
String toString() {
    return 'AppSettings(watchedFolders: $watchedFolders, eveningReminderEnabled: $eveningReminderEnabled, eveningReminderMinutes: $eveningReminderMinutes)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 List<String> watchedFolders, bool eveningReminderEnabled, int eveningReminderMinutes
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? watchedFolders = null,Object? eveningReminderEnabled = null,Object? eveningReminderMinutes = null,}) {
  return _then(_AppSettings(
watchedFolders: null == watchedFolders ? _self._watchedFolders : watchedFolders // ignore: cast_nullable_to_non_nullable
as List<String>,eveningReminderEnabled: null == eveningReminderEnabled ? _self.eveningReminderEnabled : eveningReminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,eveningReminderMinutes: null == eveningReminderMinutes ? _self.eveningReminderMinutes : eveningReminderMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
