// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Clip {

 int get id; ClipSource get source; ClipFingerprint get fingerprint; int get width; int get height; String get mimeType; DateTime get firstSeenAt; bool get missing; int? get mediaStoreId; String? get volumeName; String? get pickerUri;/// IANA zone where the clip was shot, e.g. `Europe/London`.
 String? get timeZoneId; int? get generationAdded; DateTime? get lastVerifiedAt;
/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClipCopyWith<Clip> get copyWith => _$ClipCopyWithImpl<Clip>(this as Clip, _$identity);

  /// Serializes this Clip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Clip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Clip&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.firstSeenAt, _this.firstSeenAt) || other.firstSeenAt == _this.firstSeenAt)&&(identical(other.missing, _this.missing) || other.missing == _this.missing)&&(identical(other.mediaStoreId, _this.mediaStoreId) || other.mediaStoreId == _this.mediaStoreId)&&(identical(other.volumeName, _this.volumeName) || other.volumeName == _this.volumeName)&&(identical(other.pickerUri, _this.pickerUri) || other.pickerUri == _this.pickerUri)&&(identical(other.timeZoneId, _this.timeZoneId) || other.timeZoneId == _this.timeZoneId)&&(identical(other.generationAdded, _this.generationAdded) || other.generationAdded == _this.generationAdded)&&(identical(other.lastVerifiedAt, _this.lastVerifiedAt) || other.lastVerifiedAt == _this.lastVerifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Clip;
  return Object.hash(runtimeType,_this.id,_this.source,_this.fingerprint,_this.width,_this.height,_this.mimeType,_this.firstSeenAt,_this.missing,_this.mediaStoreId,_this.volumeName,_this.pickerUri,_this.timeZoneId,_this.generationAdded,_this.lastVerifiedAt);
}

@override
String toString() {
  final _this = this as Clip;
  return 'Clip(id: ${_this.id}, source: ${_this.source}, fingerprint: ${_this.fingerprint}, width: ${_this.width}, height: ${_this.height}, mimeType: ${_this.mimeType}, firstSeenAt: ${_this.firstSeenAt}, missing: ${_this.missing}, mediaStoreId: ${_this.mediaStoreId}, volumeName: ${_this.volumeName}, pickerUri: ${_this.pickerUri}, timeZoneId: ${_this.timeZoneId}, generationAdded: ${_this.generationAdded}, lastVerifiedAt: ${_this.lastVerifiedAt})';
}


}

/// @nodoc
abstract mixin class $ClipCopyWith<$Res>  {
  factory $ClipCopyWith(Clip value, $Res Function(Clip) _then) = _$ClipCopyWithImpl;
@useResult
$Res call({
 int id, ClipSource source, ClipFingerprint fingerprint, int width, int height, String mimeType, DateTime firstSeenAt, bool missing, int? mediaStoreId, String? volumeName, String? pickerUri, String? timeZoneId, int? generationAdded, DateTime? lastVerifiedAt
});


$ClipFingerprintCopyWith<$Res> get fingerprint;

}
/// @nodoc
class _$ClipCopyWithImpl<$Res>
    implements $ClipCopyWith<$Res> {
  _$ClipCopyWithImpl(this._self, this._then);

  final Clip _self;
  final $Res Function(Clip) _then;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? source = null,Object? fingerprint = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? firstSeenAt = null,Object? missing = null,Object? mediaStoreId = freezed,Object? volumeName = freezed,Object? pickerUri = freezed,Object? timeZoneId = freezed,Object? generationAdded = freezed,Object? lastVerifiedAt = freezed,}) {
  return _then(Clip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipSource,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as ClipFingerprint,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,firstSeenAt: null == firstSeenAt ? _self.firstSeenAt : firstSeenAt // ignore: cast_nullable_to_non_nullable
as DateTime,missing: null == missing ? _self.missing : missing // ignore: cast_nullable_to_non_nullable
as bool,mediaStoreId: freezed == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int?,volumeName: freezed == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String?,pickerUri: freezed == pickerUri ? _self.pickerUri : pickerUri // ignore: cast_nullable_to_non_nullable
as String?,timeZoneId: freezed == timeZoneId ? _self.timeZoneId : timeZoneId // ignore: cast_nullable_to_non_nullable
as String?,generationAdded: freezed == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int?,lastVerifiedAt: freezed == lastVerifiedAt ? _self.lastVerifiedAt : lastVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipFingerprintCopyWith<$Res> get fingerprint {
  
  return $ClipFingerprintCopyWith<$Res>(_self.fingerprint, (value) {
    return _then(_self.copyWith(fingerprint: value));
  });
}
}


/// Adds pattern-matching-related methods to [Clip].
extension ClipPatterns on Clip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Clip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Clip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Clip value)  $default,){
final _that = this;
switch (_that) {
case _Clip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Clip value)?  $default,){
final _that = this;
switch (_that) {
case _Clip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  DateTime firstSeenAt,  bool missing,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded,  DateTime? lastVerifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that.id,_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.firstSeenAt,_that.missing,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded,_that.lastVerifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  DateTime firstSeenAt,  bool missing,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded,  DateTime? lastVerifiedAt)  $default,) {final _that = this;
switch (_that) {
case _Clip():
return $default(_that.id,_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.firstSeenAt,_that.missing,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded,_that.lastVerifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  DateTime firstSeenAt,  bool missing,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded,  DateTime? lastVerifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that.id,_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.firstSeenAt,_that.missing,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded,_that.lastVerifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Clip implements Clip {
  const _Clip({required this.id, required this.source, required this.fingerprint, required this.width, required this.height, required this.mimeType, required this.firstSeenAt, required this.missing, this.mediaStoreId, this.volumeName, this.pickerUri, this.timeZoneId, this.generationAdded, this.lastVerifiedAt});
  factory _Clip.fromJson(Map<String, dynamic> json) => _$ClipFromJson(json);

@override final  int id;
@override final  ClipSource source;
@override final  ClipFingerprint fingerprint;
@override final  int width;
@override final  int height;
@override final  String mimeType;
@override final  DateTime firstSeenAt;
@override final  bool missing;
@override final  int? mediaStoreId;
@override final  String? volumeName;
@override final  String? pickerUri;
/// IANA zone where the clip was shot, e.g. `Europe/London`.
@override final  String? timeZoneId;
@override final  int? generationAdded;
@override final  DateTime? lastVerifiedAt;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClipCopyWith<_Clip> get copyWith => __$ClipCopyWithImpl<_Clip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Clip&&(identical(other.id, id) || other.id == id)&&(identical(other.source, source) || other.source == source)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.firstSeenAt, firstSeenAt) || other.firstSeenAt == firstSeenAt)&&(identical(other.missing, missing) || other.missing == missing)&&(identical(other.mediaStoreId, mediaStoreId) || other.mediaStoreId == mediaStoreId)&&(identical(other.volumeName, volumeName) || other.volumeName == volumeName)&&(identical(other.pickerUri, pickerUri) || other.pickerUri == pickerUri)&&(identical(other.timeZoneId, timeZoneId) || other.timeZoneId == timeZoneId)&&(identical(other.generationAdded, generationAdded) || other.generationAdded == generationAdded)&&(identical(other.lastVerifiedAt, lastVerifiedAt) || other.lastVerifiedAt == lastVerifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,source,fingerprint,width,height,mimeType,firstSeenAt,missing,mediaStoreId,volumeName,pickerUri,timeZoneId,generationAdded,lastVerifiedAt);
}

@override
String toString() {
    return 'Clip(id: $id, source: $source, fingerprint: $fingerprint, width: $width, height: $height, mimeType: $mimeType, firstSeenAt: $firstSeenAt, missing: $missing, mediaStoreId: $mediaStoreId, volumeName: $volumeName, pickerUri: $pickerUri, timeZoneId: $timeZoneId, generationAdded: $generationAdded, lastVerifiedAt: $lastVerifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ClipCopyWith<$Res> implements $ClipCopyWith<$Res> {
  factory _$ClipCopyWith(_Clip value, $Res Function(_Clip) _then) = __$ClipCopyWithImpl;
@override @useResult
$Res call({
 int id, ClipSource source, ClipFingerprint fingerprint, int width, int height, String mimeType, DateTime firstSeenAt, bool missing, int? mediaStoreId, String? volumeName, String? pickerUri, String? timeZoneId, int? generationAdded, DateTime? lastVerifiedAt
});


@override $ClipFingerprintCopyWith<$Res> get fingerprint;

}
/// @nodoc
class __$ClipCopyWithImpl<$Res>
    implements _$ClipCopyWith<$Res> {
  __$ClipCopyWithImpl(this._self, this._then);

  final _Clip _self;
  final $Res Function(_Clip) _then;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? source = null,Object? fingerprint = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? firstSeenAt = null,Object? missing = null,Object? mediaStoreId = freezed,Object? volumeName = freezed,Object? pickerUri = freezed,Object? timeZoneId = freezed,Object? generationAdded = freezed,Object? lastVerifiedAt = freezed,}) {
  return _then(_Clip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipSource,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as ClipFingerprint,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,firstSeenAt: null == firstSeenAt ? _self.firstSeenAt : firstSeenAt // ignore: cast_nullable_to_non_nullable
as DateTime,missing: null == missing ? _self.missing : missing // ignore: cast_nullable_to_non_nullable
as bool,mediaStoreId: freezed == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int?,volumeName: freezed == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String?,pickerUri: freezed == pickerUri ? _self.pickerUri : pickerUri // ignore: cast_nullable_to_non_nullable
as String?,timeZoneId: freezed == timeZoneId ? _self.timeZoneId : timeZoneId // ignore: cast_nullable_to_non_nullable
as String?,generationAdded: freezed == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int?,lastVerifiedAt: freezed == lastVerifiedAt ? _self.lastVerifiedAt : lastVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipFingerprintCopyWith<$Res> get fingerprint {
  
  return $ClipFingerprintCopyWith<$Res>(_self.fingerprint, (value) {
    return _then(_self.copyWith(fingerprint: value));
  });
}
}


/// @nodoc
mixin _$NewClip {

 ClipSource get source; ClipFingerprint get fingerprint; int get width; int get height; String get mimeType; int? get mediaStoreId; String? get volumeName; String? get pickerUri; String? get timeZoneId; int? get generationAdded;
/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewClipCopyWith<NewClip> get copyWith => _$NewClipCopyWithImpl<NewClip>(this as NewClip, _$identity);

  /// Serializes this NewClip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NewClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewClip&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.mediaStoreId, _this.mediaStoreId) || other.mediaStoreId == _this.mediaStoreId)&&(identical(other.volumeName, _this.volumeName) || other.volumeName == _this.volumeName)&&(identical(other.pickerUri, _this.pickerUri) || other.pickerUri == _this.pickerUri)&&(identical(other.timeZoneId, _this.timeZoneId) || other.timeZoneId == _this.timeZoneId)&&(identical(other.generationAdded, _this.generationAdded) || other.generationAdded == _this.generationAdded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NewClip;
  return Object.hash(runtimeType,_this.source,_this.fingerprint,_this.width,_this.height,_this.mimeType,_this.mediaStoreId,_this.volumeName,_this.pickerUri,_this.timeZoneId,_this.generationAdded);
}

@override
String toString() {
  final _this = this as NewClip;
  return 'NewClip(source: ${_this.source}, fingerprint: ${_this.fingerprint}, width: ${_this.width}, height: ${_this.height}, mimeType: ${_this.mimeType}, mediaStoreId: ${_this.mediaStoreId}, volumeName: ${_this.volumeName}, pickerUri: ${_this.pickerUri}, timeZoneId: ${_this.timeZoneId}, generationAdded: ${_this.generationAdded})';
}


}

/// @nodoc
abstract mixin class $NewClipCopyWith<$Res>  {
  factory $NewClipCopyWith(NewClip value, $Res Function(NewClip) _then) = _$NewClipCopyWithImpl;
@useResult
$Res call({
 ClipSource source, ClipFingerprint fingerprint, int width, int height, String mimeType, int? mediaStoreId, String? volumeName, String? pickerUri, String? timeZoneId, int? generationAdded
});


$ClipFingerprintCopyWith<$Res> get fingerprint;

}
/// @nodoc
class _$NewClipCopyWithImpl<$Res>
    implements $NewClipCopyWith<$Res> {
  _$NewClipCopyWithImpl(this._self, this._then);

  final NewClip _self;
  final $Res Function(NewClip) _then;

/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? fingerprint = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? mediaStoreId = freezed,Object? volumeName = freezed,Object? pickerUri = freezed,Object? timeZoneId = freezed,Object? generationAdded = freezed,}) {
  return _then(NewClip(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipSource,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as ClipFingerprint,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,mediaStoreId: freezed == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int?,volumeName: freezed == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String?,pickerUri: freezed == pickerUri ? _self.pickerUri : pickerUri // ignore: cast_nullable_to_non_nullable
as String?,timeZoneId: freezed == timeZoneId ? _self.timeZoneId : timeZoneId // ignore: cast_nullable_to_non_nullable
as String?,generationAdded: freezed == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipFingerprintCopyWith<$Res> get fingerprint {
  
  return $ClipFingerprintCopyWith<$Res>(_self.fingerprint, (value) {
    return _then(_self.copyWith(fingerprint: value));
  });
}
}


/// Adds pattern-matching-related methods to [NewClip].
extension NewClipPatterns on NewClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewClip value)  $default,){
final _that = this;
switch (_that) {
case _NewClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewClip value)?  $default,){
final _that = this;
switch (_that) {
case _NewClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewClip() when $default != null:
return $default(_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded)  $default,) {final _that = this;
switch (_that) {
case _NewClip():
return $default(_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ClipSource source,  ClipFingerprint fingerprint,  int width,  int height,  String mimeType,  int? mediaStoreId,  String? volumeName,  String? pickerUri,  String? timeZoneId,  int? generationAdded)?  $default,) {final _that = this;
switch (_that) {
case _NewClip() when $default != null:
return $default(_that.source,_that.fingerprint,_that.width,_that.height,_that.mimeType,_that.mediaStoreId,_that.volumeName,_that.pickerUri,_that.timeZoneId,_that.generationAdded);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NewClip implements NewClip {
  const _NewClip({required this.source, required this.fingerprint, required this.width, required this.height, required this.mimeType, this.mediaStoreId, this.volumeName, this.pickerUri, this.timeZoneId, this.generationAdded}): assert(source != ClipSource.mediaStore || (mediaStoreId != null && volumeName != null), 'a mediaStore clip needs mediaStoreId and volumeName'),assert(source != ClipSource.picker || pickerUri != null, 'a picker clip needs pickerUri');
  factory _NewClip.fromJson(Map<String, dynamic> json) => _$NewClipFromJson(json);

@override final  ClipSource source;
@override final  ClipFingerprint fingerprint;
@override final  int width;
@override final  int height;
@override final  String mimeType;
@override final  int? mediaStoreId;
@override final  String? volumeName;
@override final  String? pickerUri;
@override final  String? timeZoneId;
@override final  int? generationAdded;

/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewClipCopyWith<_NewClip> get copyWith => __$NewClipCopyWithImpl<_NewClip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NewClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewClip&&(identical(other.source, source) || other.source == source)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.mediaStoreId, mediaStoreId) || other.mediaStoreId == mediaStoreId)&&(identical(other.volumeName, volumeName) || other.volumeName == volumeName)&&(identical(other.pickerUri, pickerUri) || other.pickerUri == pickerUri)&&(identical(other.timeZoneId, timeZoneId) || other.timeZoneId == timeZoneId)&&(identical(other.generationAdded, generationAdded) || other.generationAdded == generationAdded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,source,fingerprint,width,height,mimeType,mediaStoreId,volumeName,pickerUri,timeZoneId,generationAdded);
}

@override
String toString() {
    return 'NewClip(source: $source, fingerprint: $fingerprint, width: $width, height: $height, mimeType: $mimeType, mediaStoreId: $mediaStoreId, volumeName: $volumeName, pickerUri: $pickerUri, timeZoneId: $timeZoneId, generationAdded: $generationAdded)';
}


}

/// @nodoc
abstract mixin class _$NewClipCopyWith<$Res> implements $NewClipCopyWith<$Res> {
  factory _$NewClipCopyWith(_NewClip value, $Res Function(_NewClip) _then) = __$NewClipCopyWithImpl;
@override @useResult
$Res call({
 ClipSource source, ClipFingerprint fingerprint, int width, int height, String mimeType, int? mediaStoreId, String? volumeName, String? pickerUri, String? timeZoneId, int? generationAdded
});


@override $ClipFingerprintCopyWith<$Res> get fingerprint;

}
/// @nodoc
class __$NewClipCopyWithImpl<$Res>
    implements _$NewClipCopyWith<$Res> {
  __$NewClipCopyWithImpl(this._self, this._then);

  final _NewClip _self;
  final $Res Function(_NewClip) _then;

/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? fingerprint = null,Object? width = null,Object? height = null,Object? mimeType = null,Object? mediaStoreId = freezed,Object? volumeName = freezed,Object? pickerUri = freezed,Object? timeZoneId = freezed,Object? generationAdded = freezed,}) {
  return _then(_NewClip(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipSource,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as ClipFingerprint,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,mediaStoreId: freezed == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int?,volumeName: freezed == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String?,pickerUri: freezed == pickerUri ? _self.pickerUri : pickerUri // ignore: cast_nullable_to_non_nullable
as String?,timeZoneId: freezed == timeZoneId ? _self.timeZoneId : timeZoneId // ignore: cast_nullable_to_non_nullable
as String?,generationAdded: freezed == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of NewClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipFingerprintCopyWith<$Res> get fingerprint {
  
  return $ClipFingerprintCopyWith<$Res>(_self.fingerprint, (value) {
    return _then(_self.copyWith(fingerprint: value));
  });
}
}

// dart format on
