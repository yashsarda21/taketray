// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clip_fingerprint.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClipFingerprint {

 int get sizeBytes; int get durationMs; DateTime get dateTakenUtc; String get displayName;
/// Create a copy of ClipFingerprint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClipFingerprintCopyWith<ClipFingerprint> get copyWith => _$ClipFingerprintCopyWithImpl<ClipFingerprint>(this as ClipFingerprint, _$identity);

  /// Serializes this ClipFingerprint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ClipFingerprint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClipFingerprint&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.dateTakenUtc, _this.dateTakenUtc) || other.dateTakenUtc == _this.dateTakenUtc)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClipFingerprint;
  return Object.hash(runtimeType,_this.sizeBytes,_this.durationMs,_this.dateTakenUtc,_this.displayName);
}

@override
String toString() {
  final _this = this as ClipFingerprint;
  return 'ClipFingerprint(sizeBytes: ${_this.sizeBytes}, durationMs: ${_this.durationMs}, dateTakenUtc: ${_this.dateTakenUtc}, displayName: ${_this.displayName})';
}


}

/// @nodoc
abstract mixin class $ClipFingerprintCopyWith<$Res>  {
  factory $ClipFingerprintCopyWith(ClipFingerprint value, $Res Function(ClipFingerprint) _then) = _$ClipFingerprintCopyWithImpl;
@useResult
$Res call({
 int sizeBytes, int durationMs, DateTime dateTakenUtc, String displayName
});




}
/// @nodoc
class _$ClipFingerprintCopyWithImpl<$Res>
    implements $ClipFingerprintCopyWith<$Res> {
  _$ClipFingerprintCopyWithImpl(this._self, this._then);

  final ClipFingerprint _self;
  final $Res Function(ClipFingerprint) _then;

/// Create a copy of ClipFingerprint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sizeBytes = null,Object? durationMs = null,Object? dateTakenUtc = null,Object? displayName = null,}) {
  return _then(ClipFingerprint(
sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,dateTakenUtc: null == dateTakenUtc ? _self.dateTakenUtc : dateTakenUtc // ignore: cast_nullable_to_non_nullable
as DateTime,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ClipFingerprint].
extension ClipFingerprintPatterns on ClipFingerprint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClipFingerprint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClipFingerprint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClipFingerprint value)  $default,){
final _that = this;
switch (_that) {
case _ClipFingerprint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClipFingerprint value)?  $default,){
final _that = this;
switch (_that) {
case _ClipFingerprint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sizeBytes,  int durationMs,  DateTime dateTakenUtc,  String displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClipFingerprint() when $default != null:
return $default(_that.sizeBytes,_that.durationMs,_that.dateTakenUtc,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sizeBytes,  int durationMs,  DateTime dateTakenUtc,  String displayName)  $default,) {final _that = this;
switch (_that) {
case _ClipFingerprint():
return $default(_that.sizeBytes,_that.durationMs,_that.dateTakenUtc,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sizeBytes,  int durationMs,  DateTime dateTakenUtc,  String displayName)?  $default,) {final _that = this;
switch (_that) {
case _ClipFingerprint() when $default != null:
return $default(_that.sizeBytes,_that.durationMs,_that.dateTakenUtc,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClipFingerprint implements ClipFingerprint {
  const _ClipFingerprint({required this.sizeBytes, required this.durationMs, required this.dateTakenUtc, required this.displayName});
  factory _ClipFingerprint.fromJson(Map<String, dynamic> json) => _$ClipFingerprintFromJson(json);

@override final  int sizeBytes;
@override final  int durationMs;
@override final  DateTime dateTakenUtc;
@override final  String displayName;

/// Create a copy of ClipFingerprint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClipFingerprintCopyWith<_ClipFingerprint> get copyWith => __$ClipFingerprintCopyWithImpl<_ClipFingerprint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClipFingerprintToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClipFingerprint&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.dateTakenUtc, dateTakenUtc) || other.dateTakenUtc == dateTakenUtc)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sizeBytes,durationMs,dateTakenUtc,displayName);
}

@override
String toString() {
    return 'ClipFingerprint(sizeBytes: $sizeBytes, durationMs: $durationMs, dateTakenUtc: $dateTakenUtc, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$ClipFingerprintCopyWith<$Res> implements $ClipFingerprintCopyWith<$Res> {
  factory _$ClipFingerprintCopyWith(_ClipFingerprint value, $Res Function(_ClipFingerprint) _then) = __$ClipFingerprintCopyWithImpl;
@override @useResult
$Res call({
 int sizeBytes, int durationMs, DateTime dateTakenUtc, String displayName
});




}
/// @nodoc
class __$ClipFingerprintCopyWithImpl<$Res>
    implements _$ClipFingerprintCopyWith<$Res> {
  __$ClipFingerprintCopyWithImpl(this._self, this._then);

  final _ClipFingerprint _self;
  final $Res Function(_ClipFingerprint) _then;

/// Create a copy of ClipFingerprint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sizeBytes = null,Object? durationMs = null,Object? dateTakenUtc = null,Object? displayName = null,}) {
  return _then(_ClipFingerprint(
sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,dateTakenUtc: null == dateTakenUtc ? _self.dateTakenUtc : dateTakenUtc // ignore: cast_nullable_to_non_nullable
as DateTime,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
