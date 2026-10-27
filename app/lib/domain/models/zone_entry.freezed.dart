// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'zone_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ZoneEntry {

 DateTime get at; String get zoneId;
/// Create a copy of ZoneEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ZoneEntryCopyWith<ZoneEntry> get copyWith => _$ZoneEntryCopyWithImpl<ZoneEntry>(this as ZoneEntry, _$identity);

  /// Serializes this ZoneEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ZoneEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ZoneEntry&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.zoneId, _this.zoneId) || other.zoneId == _this.zoneId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ZoneEntry;
  return Object.hash(runtimeType,_this.at,_this.zoneId);
}

@override
String toString() {
  final _this = this as ZoneEntry;
  return 'ZoneEntry(at: ${_this.at}, zoneId: ${_this.zoneId})';
}


}

/// @nodoc
abstract mixin class $ZoneEntryCopyWith<$Res>  {
  factory $ZoneEntryCopyWith(ZoneEntry value, $Res Function(ZoneEntry) _then) = _$ZoneEntryCopyWithImpl;
@useResult
$Res call({
 DateTime at, String zoneId
});




}
/// @nodoc
class _$ZoneEntryCopyWithImpl<$Res>
    implements $ZoneEntryCopyWith<$Res> {
  _$ZoneEntryCopyWithImpl(this._self, this._then);

  final ZoneEntry _self;
  final $Res Function(ZoneEntry) _then;

/// Create a copy of ZoneEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? zoneId = null,}) {
  return _then(ZoneEntry(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,zoneId: null == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ZoneEntry].
extension ZoneEntryPatterns on ZoneEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ZoneEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ZoneEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ZoneEntry value)  $default,){
final _that = this;
switch (_that) {
case _ZoneEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ZoneEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ZoneEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  String zoneId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ZoneEntry() when $default != null:
return $default(_that.at,_that.zoneId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  String zoneId)  $default,) {final _that = this;
switch (_that) {
case _ZoneEntry():
return $default(_that.at,_that.zoneId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  String zoneId)?  $default,) {final _that = this;
switch (_that) {
case _ZoneEntry() when $default != null:
return $default(_that.at,_that.zoneId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ZoneEntry implements ZoneEntry {
  const _ZoneEntry({required this.at, required this.zoneId});
  factory _ZoneEntry.fromJson(Map<String, dynamic> json) => _$ZoneEntryFromJson(json);

@override final  DateTime at;
@override final  String zoneId;

/// Create a copy of ZoneEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ZoneEntryCopyWith<_ZoneEntry> get copyWith => __$ZoneEntryCopyWithImpl<_ZoneEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ZoneEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ZoneEntry&&(identical(other.at, at) || other.at == at)&&(identical(other.zoneId, zoneId) || other.zoneId == zoneId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,at,zoneId);
}

@override
String toString() {
    return 'ZoneEntry(at: $at, zoneId: $zoneId)';
}


}

/// @nodoc
abstract mixin class _$ZoneEntryCopyWith<$Res> implements $ZoneEntryCopyWith<$Res> {
  factory _$ZoneEntryCopyWith(_ZoneEntry value, $Res Function(_ZoneEntry) _then) = __$ZoneEntryCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, String zoneId
});




}
/// @nodoc
class __$ZoneEntryCopyWithImpl<$Res>
    implements _$ZoneEntryCopyWith<$Res> {
  __$ZoneEntryCopyWithImpl(this._self, this._then);

  final _ZoneEntry _self;
  final $Res Function(_ZoneEntry) _then;

/// Create a copy of ZoneEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? zoneId = null,}) {
  return _then(_ZoneEntry(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,zoneId: null == zoneId ? _self.zoneId : zoneId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
