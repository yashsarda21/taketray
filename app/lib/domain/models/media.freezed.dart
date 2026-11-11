// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MediaAccess {

 MediaAccessLevel get level; bool get canAskAgain; int get sdkInt;
/// Create a copy of MediaAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaAccessCopyWith<MediaAccess> get copyWith => _$MediaAccessCopyWithImpl<MediaAccess>(this as MediaAccess, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MediaAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaAccess&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.canAskAgain, _this.canAskAgain) || other.canAskAgain == _this.canAskAgain)&&(identical(other.sdkInt, _this.sdkInt) || other.sdkInt == _this.sdkInt));
}


@override
int get hashCode {
  final _this = this as MediaAccess;
  return Object.hash(runtimeType,_this.level,_this.canAskAgain,_this.sdkInt);
}

@override
String toString() {
  final _this = this as MediaAccess;
  return 'MediaAccess(level: ${_this.level}, canAskAgain: ${_this.canAskAgain}, sdkInt: ${_this.sdkInt})';
}


}

/// @nodoc
abstract mixin class $MediaAccessCopyWith<$Res>  {
  factory $MediaAccessCopyWith(MediaAccess value, $Res Function(MediaAccess) _then) = _$MediaAccessCopyWithImpl;
@useResult
$Res call({
 MediaAccessLevel level, bool canAskAgain, int sdkInt
});




}
/// @nodoc
class _$MediaAccessCopyWithImpl<$Res>
    implements $MediaAccessCopyWith<$Res> {
  _$MediaAccessCopyWithImpl(this._self, this._then);

  final MediaAccess _self;
  final $Res Function(MediaAccess) _then;

/// Create a copy of MediaAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? canAskAgain = null,Object? sdkInt = null,}) {
  return _then(MediaAccess(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as MediaAccessLevel,canAskAgain: null == canAskAgain ? _self.canAskAgain : canAskAgain // ignore: cast_nullable_to_non_nullable
as bool,sdkInt: null == sdkInt ? _self.sdkInt : sdkInt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaAccess].
extension MediaAccessPatterns on MediaAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaAccess value)  $default,){
final _that = this;
switch (_that) {
case _MediaAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaAccess value)?  $default,){
final _that = this;
switch (_that) {
case _MediaAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MediaAccessLevel level,  bool canAskAgain,  int sdkInt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaAccess() when $default != null:
return $default(_that.level,_that.canAskAgain,_that.sdkInt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MediaAccessLevel level,  bool canAskAgain,  int sdkInt)  $default,) {final _that = this;
switch (_that) {
case _MediaAccess():
return $default(_that.level,_that.canAskAgain,_that.sdkInt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MediaAccessLevel level,  bool canAskAgain,  int sdkInt)?  $default,) {final _that = this;
switch (_that) {
case _MediaAccess() when $default != null:
return $default(_that.level,_that.canAskAgain,_that.sdkInt);case _:
  return null;

}
}

}

/// @nodoc


class _MediaAccess implements MediaAccess {
  const _MediaAccess({required this.level, required this.canAskAgain, required this.sdkInt});
  

@override final  MediaAccessLevel level;
@override final  bool canAskAgain;
@override final  int sdkInt;

/// Create a copy of MediaAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaAccessCopyWith<_MediaAccess> get copyWith => __$MediaAccessCopyWithImpl<_MediaAccess>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaAccess&&(identical(other.level, level) || other.level == level)&&(identical(other.canAskAgain, canAskAgain) || other.canAskAgain == canAskAgain)&&(identical(other.sdkInt, sdkInt) || other.sdkInt == sdkInt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,level,canAskAgain,sdkInt);
}

@override
String toString() {
    return 'MediaAccess(level: $level, canAskAgain: $canAskAgain, sdkInt: $sdkInt)';
}


}

/// @nodoc
abstract mixin class _$MediaAccessCopyWith<$Res> implements $MediaAccessCopyWith<$Res> {
  factory _$MediaAccessCopyWith(_MediaAccess value, $Res Function(_MediaAccess) _then) = __$MediaAccessCopyWithImpl;
@override @useResult
$Res call({
 MediaAccessLevel level, bool canAskAgain, int sdkInt
});




}
/// @nodoc
class __$MediaAccessCopyWithImpl<$Res>
    implements _$MediaAccessCopyWith<$Res> {
  __$MediaAccessCopyWithImpl(this._self, this._then);

  final _MediaAccess _self;
  final $Res Function(_MediaAccess) _then;

/// Create a copy of MediaAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? canAskAgain = null,Object? sdkInt = null,}) {
  return _then(_MediaAccess(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as MediaAccessLevel,canAskAgain: null == canAskAgain ? _self.canAskAgain : canAskAgain // ignore: cast_nullable_to_non_nullable
as bool,sdkInt: null == sdkInt ? _self.sdkInt : sdkInt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$MediaVolume {

 String get name; int get generation; String? get version;
/// Create a copy of MediaVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaVolumeCopyWith<MediaVolume> get copyWith => _$MediaVolumeCopyWithImpl<MediaVolume>(this as MediaVolume, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MediaVolume;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaVolume&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.version, _this.version) || other.version == _this.version));
}


@override
int get hashCode {
  final _this = this as MediaVolume;
  return Object.hash(runtimeType,_this.name,_this.generation,_this.version);
}

@override
String toString() {
  final _this = this as MediaVolume;
  return 'MediaVolume(name: ${_this.name}, generation: ${_this.generation}, version: ${_this.version})';
}


}

/// @nodoc
abstract mixin class $MediaVolumeCopyWith<$Res>  {
  factory $MediaVolumeCopyWith(MediaVolume value, $Res Function(MediaVolume) _then) = _$MediaVolumeCopyWithImpl;
@useResult
$Res call({
 String name, int generation, String? version
});




}
/// @nodoc
class _$MediaVolumeCopyWithImpl<$Res>
    implements $MediaVolumeCopyWith<$Res> {
  _$MediaVolumeCopyWithImpl(this._self, this._then);

  final MediaVolume _self;
  final $Res Function(MediaVolume) _then;

/// Create a copy of MediaVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? generation = null,Object? version = freezed,}) {
  return _then(MediaVolume(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaVolume].
extension MediaVolumePatterns on MediaVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaVolume value)  $default,){
final _that = this;
switch (_that) {
case _MediaVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaVolume value)?  $default,){
final _that = this;
switch (_that) {
case _MediaVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int generation,  String? version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaVolume() when $default != null:
return $default(_that.name,_that.generation,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int generation,  String? version)  $default,) {final _that = this;
switch (_that) {
case _MediaVolume():
return $default(_that.name,_that.generation,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int generation,  String? version)?  $default,) {final _that = this;
switch (_that) {
case _MediaVolume() when $default != null:
return $default(_that.name,_that.generation,_that.version);case _:
  return null;

}
}

}

/// @nodoc


class _MediaVolume extends MediaVolume {
  const _MediaVolume({required this.name, required this.generation, this.version}): super._();
  

@override final  String name;
@override final  int generation;
@override final  String? version;

/// Create a copy of MediaVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaVolumeCopyWith<_MediaVolume> get copyWith => __$MediaVolumeCopyWithImpl<_MediaVolume>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaVolume&&(identical(other.name, name) || other.name == name)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.version, version) || other.version == version));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,generation,version);
}

@override
String toString() {
    return 'MediaVolume(name: $name, generation: $generation, version: $version)';
}


}

/// @nodoc
abstract mixin class _$MediaVolumeCopyWith<$Res> implements $MediaVolumeCopyWith<$Res> {
  factory _$MediaVolumeCopyWith(_MediaVolume value, $Res Function(_MediaVolume) _then) = __$MediaVolumeCopyWithImpl;
@override @useResult
$Res call({
 String name, int generation, String? version
});




}
/// @nodoc
class __$MediaVolumeCopyWithImpl<$Res>
    implements _$MediaVolumeCopyWith<$Res> {
  __$MediaVolumeCopyWithImpl(this._self, this._then);

  final _MediaVolume _self;
  final $Res Function(_MediaVolume) _then;

/// Create a copy of MediaVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? generation = null,Object? version = freezed,}) {
  return _then(_MediaVolume(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$MediaVideo {

 String get volumeName; int get mediaStoreId; int get generationAdded; int get sizeBytes; String get displayName; String get relativePath; bool get isPending; int? get durationMs; int? get dateTakenMs; int? get dateAddedSec; int? get dateModifiedSec; int? get width; int? get height; String get mimeType;
/// Create a copy of MediaVideo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaVideoCopyWith<MediaVideo> get copyWith => _$MediaVideoCopyWithImpl<MediaVideo>(this as MediaVideo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MediaVideo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaVideo&&(identical(other.volumeName, _this.volumeName) || other.volumeName == _this.volumeName)&&(identical(other.mediaStoreId, _this.mediaStoreId) || other.mediaStoreId == _this.mediaStoreId)&&(identical(other.generationAdded, _this.generationAdded) || other.generationAdded == _this.generationAdded)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.relativePath, _this.relativePath) || other.relativePath == _this.relativePath)&&(identical(other.isPending, _this.isPending) || other.isPending == _this.isPending)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.dateTakenMs, _this.dateTakenMs) || other.dateTakenMs == _this.dateTakenMs)&&(identical(other.dateAddedSec, _this.dateAddedSec) || other.dateAddedSec == _this.dateAddedSec)&&(identical(other.dateModifiedSec, _this.dateModifiedSec) || other.dateModifiedSec == _this.dateModifiedSec)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType));
}


@override
int get hashCode {
  final _this = this as MediaVideo;
  return Object.hash(runtimeType,_this.volumeName,_this.mediaStoreId,_this.generationAdded,_this.sizeBytes,_this.displayName,_this.relativePath,_this.isPending,_this.durationMs,_this.dateTakenMs,_this.dateAddedSec,_this.dateModifiedSec,_this.width,_this.height,_this.mimeType);
}

@override
String toString() {
  final _this = this as MediaVideo;
  return 'MediaVideo(volumeName: ${_this.volumeName}, mediaStoreId: ${_this.mediaStoreId}, generationAdded: ${_this.generationAdded}, sizeBytes: ${_this.sizeBytes}, displayName: ${_this.displayName}, relativePath: ${_this.relativePath}, isPending: ${_this.isPending}, durationMs: ${_this.durationMs}, dateTakenMs: ${_this.dateTakenMs}, dateAddedSec: ${_this.dateAddedSec}, dateModifiedSec: ${_this.dateModifiedSec}, width: ${_this.width}, height: ${_this.height}, mimeType: ${_this.mimeType})';
}


}

/// @nodoc
abstract mixin class $MediaVideoCopyWith<$Res>  {
  factory $MediaVideoCopyWith(MediaVideo value, $Res Function(MediaVideo) _then) = _$MediaVideoCopyWithImpl;
@useResult
$Res call({
 String volumeName, int mediaStoreId, int generationAdded, int sizeBytes, String displayName, String relativePath, bool isPending, int? durationMs, int? dateTakenMs, int? dateAddedSec, int? dateModifiedSec, int? width, int? height, String mimeType
});




}
/// @nodoc
class _$MediaVideoCopyWithImpl<$Res>
    implements $MediaVideoCopyWith<$Res> {
  _$MediaVideoCopyWithImpl(this._self, this._then);

  final MediaVideo _self;
  final $Res Function(MediaVideo) _then;

/// Create a copy of MediaVideo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeName = null,Object? mediaStoreId = null,Object? generationAdded = null,Object? sizeBytes = null,Object? displayName = null,Object? relativePath = null,Object? isPending = null,Object? durationMs = freezed,Object? dateTakenMs = freezed,Object? dateAddedSec = freezed,Object? dateModifiedSec = freezed,Object? width = freezed,Object? height = freezed,Object? mimeType = null,}) {
  return _then(MediaVideo(
volumeName: null == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String,mediaStoreId: null == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int,generationAdded: null == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,isPending: null == isPending ? _self.isPending : isPending // ignore: cast_nullable_to_non_nullable
as bool,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,dateTakenMs: freezed == dateTakenMs ? _self.dateTakenMs : dateTakenMs // ignore: cast_nullable_to_non_nullable
as int?,dateAddedSec: freezed == dateAddedSec ? _self.dateAddedSec : dateAddedSec // ignore: cast_nullable_to_non_nullable
as int?,dateModifiedSec: freezed == dateModifiedSec ? _self.dateModifiedSec : dateModifiedSec // ignore: cast_nullable_to_non_nullable
as int?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaVideo].
extension MediaVideoPatterns on MediaVideo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaVideo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaVideo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaVideo value)  $default,){
final _that = this;
switch (_that) {
case _MediaVideo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaVideo value)?  $default,){
final _that = this;
switch (_that) {
case _MediaVideo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String volumeName,  int mediaStoreId,  int generationAdded,  int sizeBytes,  String displayName,  String relativePath,  bool isPending,  int? durationMs,  int? dateTakenMs,  int? dateAddedSec,  int? dateModifiedSec,  int? width,  int? height,  String mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaVideo() when $default != null:
return $default(_that.volumeName,_that.mediaStoreId,_that.generationAdded,_that.sizeBytes,_that.displayName,_that.relativePath,_that.isPending,_that.durationMs,_that.dateTakenMs,_that.dateAddedSec,_that.dateModifiedSec,_that.width,_that.height,_that.mimeType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String volumeName,  int mediaStoreId,  int generationAdded,  int sizeBytes,  String displayName,  String relativePath,  bool isPending,  int? durationMs,  int? dateTakenMs,  int? dateAddedSec,  int? dateModifiedSec,  int? width,  int? height,  String mimeType)  $default,) {final _that = this;
switch (_that) {
case _MediaVideo():
return $default(_that.volumeName,_that.mediaStoreId,_that.generationAdded,_that.sizeBytes,_that.displayName,_that.relativePath,_that.isPending,_that.durationMs,_that.dateTakenMs,_that.dateAddedSec,_that.dateModifiedSec,_that.width,_that.height,_that.mimeType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String volumeName,  int mediaStoreId,  int generationAdded,  int sizeBytes,  String displayName,  String relativePath,  bool isPending,  int? durationMs,  int? dateTakenMs,  int? dateAddedSec,  int? dateModifiedSec,  int? width,  int? height,  String mimeType)?  $default,) {final _that = this;
switch (_that) {
case _MediaVideo() when $default != null:
return $default(_that.volumeName,_that.mediaStoreId,_that.generationAdded,_that.sizeBytes,_that.displayName,_that.relativePath,_that.isPending,_that.durationMs,_that.dateTakenMs,_that.dateAddedSec,_that.dateModifiedSec,_that.width,_that.height,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc


class _MediaVideo implements MediaVideo {
  const _MediaVideo({required this.volumeName, required this.mediaStoreId, required this.generationAdded, required this.sizeBytes, required this.displayName, required this.relativePath, required this.isPending, this.durationMs, this.dateTakenMs, this.dateAddedSec, this.dateModifiedSec, this.width, this.height, this.mimeType = defaultVideoMimeType});
  

@override final  String volumeName;
@override final  int mediaStoreId;
@override final  int generationAdded;
@override final  int sizeBytes;
@override final  String displayName;
@override final  String relativePath;
@override final  bool isPending;
@override final  int? durationMs;
@override final  int? dateTakenMs;
@override final  int? dateAddedSec;
@override final  int? dateModifiedSec;
@override final  int? width;
@override final  int? height;
@override@JsonKey() final  String mimeType;

/// Create a copy of MediaVideo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaVideoCopyWith<_MediaVideo> get copyWith => __$MediaVideoCopyWithImpl<_MediaVideo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaVideo&&(identical(other.volumeName, volumeName) || other.volumeName == volumeName)&&(identical(other.mediaStoreId, mediaStoreId) || other.mediaStoreId == mediaStoreId)&&(identical(other.generationAdded, generationAdded) || other.generationAdded == generationAdded)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.isPending, isPending) || other.isPending == isPending)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.dateTakenMs, dateTakenMs) || other.dateTakenMs == dateTakenMs)&&(identical(other.dateAddedSec, dateAddedSec) || other.dateAddedSec == dateAddedSec)&&(identical(other.dateModifiedSec, dateModifiedSec) || other.dateModifiedSec == dateModifiedSec)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}


@override
int get hashCode {
    return Object.hash(runtimeType,volumeName,mediaStoreId,generationAdded,sizeBytes,displayName,relativePath,isPending,durationMs,dateTakenMs,dateAddedSec,dateModifiedSec,width,height,mimeType);
}

@override
String toString() {
    return 'MediaVideo(volumeName: $volumeName, mediaStoreId: $mediaStoreId, generationAdded: $generationAdded, sizeBytes: $sizeBytes, displayName: $displayName, relativePath: $relativePath, isPending: $isPending, durationMs: $durationMs, dateTakenMs: $dateTakenMs, dateAddedSec: $dateAddedSec, dateModifiedSec: $dateModifiedSec, width: $width, height: $height, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$MediaVideoCopyWith<$Res> implements $MediaVideoCopyWith<$Res> {
  factory _$MediaVideoCopyWith(_MediaVideo value, $Res Function(_MediaVideo) _then) = __$MediaVideoCopyWithImpl;
@override @useResult
$Res call({
 String volumeName, int mediaStoreId, int generationAdded, int sizeBytes, String displayName, String relativePath, bool isPending, int? durationMs, int? dateTakenMs, int? dateAddedSec, int? dateModifiedSec, int? width, int? height, String mimeType
});




}
/// @nodoc
class __$MediaVideoCopyWithImpl<$Res>
    implements _$MediaVideoCopyWith<$Res> {
  __$MediaVideoCopyWithImpl(this._self, this._then);

  final _MediaVideo _self;
  final $Res Function(_MediaVideo) _then;

/// Create a copy of MediaVideo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeName = null,Object? mediaStoreId = null,Object? generationAdded = null,Object? sizeBytes = null,Object? displayName = null,Object? relativePath = null,Object? isPending = null,Object? durationMs = freezed,Object? dateTakenMs = freezed,Object? dateAddedSec = freezed,Object? dateModifiedSec = freezed,Object? width = freezed,Object? height = freezed,Object? mimeType = null,}) {
  return _then(_MediaVideo(
volumeName: null == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String,mediaStoreId: null == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int,generationAdded: null == generationAdded ? _self.generationAdded : generationAdded // ignore: cast_nullable_to_non_nullable
as int,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,isPending: null == isPending ? _self.isPending : isPending // ignore: cast_nullable_to_non_nullable
as bool,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,dateTakenMs: freezed == dateTakenMs ? _self.dateTakenMs : dateTakenMs // ignore: cast_nullable_to_non_nullable
as int?,dateAddedSec: freezed == dateAddedSec ? _self.dateAddedSec : dateAddedSec // ignore: cast_nullable_to_non_nullable
as int?,dateModifiedSec: freezed == dateModifiedSec ? _self.dateModifiedSec : dateModifiedSec // ignore: cast_nullable_to_non_nullable
as int?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$VideoFolder {

 String get volumeName; String get relativePath; int get videoCount;
/// Create a copy of VideoFolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoFolderCopyWith<VideoFolder> get copyWith => _$VideoFolderCopyWithImpl<VideoFolder>(this as VideoFolder, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoFolder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoFolder&&(identical(other.volumeName, _this.volumeName) || other.volumeName == _this.volumeName)&&(identical(other.relativePath, _this.relativePath) || other.relativePath == _this.relativePath)&&(identical(other.videoCount, _this.videoCount) || other.videoCount == _this.videoCount));
}


@override
int get hashCode {
  final _this = this as VideoFolder;
  return Object.hash(runtimeType,_this.volumeName,_this.relativePath,_this.videoCount);
}

@override
String toString() {
  final _this = this as VideoFolder;
  return 'VideoFolder(volumeName: ${_this.volumeName}, relativePath: ${_this.relativePath}, videoCount: ${_this.videoCount})';
}


}

/// @nodoc
abstract mixin class $VideoFolderCopyWith<$Res>  {
  factory $VideoFolderCopyWith(VideoFolder value, $Res Function(VideoFolder) _then) = _$VideoFolderCopyWithImpl;
@useResult
$Res call({
 String volumeName, String relativePath, int videoCount
});




}
/// @nodoc
class _$VideoFolderCopyWithImpl<$Res>
    implements $VideoFolderCopyWith<$Res> {
  _$VideoFolderCopyWithImpl(this._self, this._then);

  final VideoFolder _self;
  final $Res Function(VideoFolder) _then;

/// Create a copy of VideoFolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeName = null,Object? relativePath = null,Object? videoCount = null,}) {
  return _then(VideoFolder(
volumeName: null == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,videoCount: null == videoCount ? _self.videoCount : videoCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoFolder].
extension VideoFolderPatterns on VideoFolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoFolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoFolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoFolder value)  $default,){
final _that = this;
switch (_that) {
case _VideoFolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoFolder value)?  $default,){
final _that = this;
switch (_that) {
case _VideoFolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String volumeName,  String relativePath,  int videoCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoFolder() when $default != null:
return $default(_that.volumeName,_that.relativePath,_that.videoCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String volumeName,  String relativePath,  int videoCount)  $default,) {final _that = this;
switch (_that) {
case _VideoFolder():
return $default(_that.volumeName,_that.relativePath,_that.videoCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String volumeName,  String relativePath,  int videoCount)?  $default,) {final _that = this;
switch (_that) {
case _VideoFolder() when $default != null:
return $default(_that.volumeName,_that.relativePath,_that.videoCount);case _:
  return null;

}
}

}

/// @nodoc


class _VideoFolder implements VideoFolder {
  const _VideoFolder({required this.volumeName, required this.relativePath, required this.videoCount});
  

@override final  String volumeName;
@override final  String relativePath;
@override final  int videoCount;

/// Create a copy of VideoFolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoFolderCopyWith<_VideoFolder> get copyWith => __$VideoFolderCopyWithImpl<_VideoFolder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoFolder&&(identical(other.volumeName, volumeName) || other.volumeName == volumeName)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.videoCount, videoCount) || other.videoCount == videoCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,volumeName,relativePath,videoCount);
}

@override
String toString() {
    return 'VideoFolder(volumeName: $volumeName, relativePath: $relativePath, videoCount: $videoCount)';
}


}

/// @nodoc
abstract mixin class _$VideoFolderCopyWith<$Res> implements $VideoFolderCopyWith<$Res> {
  factory _$VideoFolderCopyWith(_VideoFolder value, $Res Function(_VideoFolder) _then) = __$VideoFolderCopyWithImpl;
@override @useResult
$Res call({
 String volumeName, String relativePath, int videoCount
});




}
/// @nodoc
class __$VideoFolderCopyWithImpl<$Res>
    implements _$VideoFolderCopyWith<$Res> {
  __$VideoFolderCopyWithImpl(this._self, this._then);

  final _VideoFolder _self;
  final $Res Function(_VideoFolder) _then;

/// Create a copy of VideoFolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeName = null,Object? relativePath = null,Object? videoCount = null,}) {
  return _then(_VideoFolder(
volumeName: null == volumeName ? _self.volumeName : volumeName // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,videoCount: null == videoCount ? _self.videoCount : videoCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PickedVideo {

 String get uri; int get sizeBytes; String get displayName; bool get persisted; int? get durationMs; int? get dateTakenMs; int? get width; int? get height; String? get mimeType;
/// Create a copy of PickedVideo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PickedVideoCopyWith<PickedVideo> get copyWith => _$PickedVideoCopyWithImpl<PickedVideo>(this as PickedVideo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PickedVideo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PickedVideo&&(identical(other.uri, _this.uri) || other.uri == _this.uri)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.persisted, _this.persisted) || other.persisted == _this.persisted)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.dateTakenMs, _this.dateTakenMs) || other.dateTakenMs == _this.dateTakenMs)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType));
}


@override
int get hashCode {
  final _this = this as PickedVideo;
  return Object.hash(runtimeType,_this.uri,_this.sizeBytes,_this.displayName,_this.persisted,_this.durationMs,_this.dateTakenMs,_this.width,_this.height,_this.mimeType);
}

@override
String toString() {
  final _this = this as PickedVideo;
  return 'PickedVideo(uri: ${_this.uri}, sizeBytes: ${_this.sizeBytes}, displayName: ${_this.displayName}, persisted: ${_this.persisted}, durationMs: ${_this.durationMs}, dateTakenMs: ${_this.dateTakenMs}, width: ${_this.width}, height: ${_this.height}, mimeType: ${_this.mimeType})';
}


}

/// @nodoc
abstract mixin class $PickedVideoCopyWith<$Res>  {
  factory $PickedVideoCopyWith(PickedVideo value, $Res Function(PickedVideo) _then) = _$PickedVideoCopyWithImpl;
@useResult
$Res call({
 String uri, int sizeBytes, String displayName, bool persisted, int? durationMs, int? dateTakenMs, int? width, int? height, String? mimeType
});




}
/// @nodoc
class _$PickedVideoCopyWithImpl<$Res>
    implements $PickedVideoCopyWith<$Res> {
  _$PickedVideoCopyWithImpl(this._self, this._then);

  final PickedVideo _self;
  final $Res Function(PickedVideo) _then;

/// Create a copy of PickedVideo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uri = null,Object? sizeBytes = null,Object? displayName = null,Object? persisted = null,Object? durationMs = freezed,Object? dateTakenMs = freezed,Object? width = freezed,Object? height = freezed,Object? mimeType = freezed,}) {
  return _then(PickedVideo(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,persisted: null == persisted ? _self.persisted : persisted // ignore: cast_nullable_to_non_nullable
as bool,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,dateTakenMs: freezed == dateTakenMs ? _self.dateTakenMs : dateTakenMs // ignore: cast_nullable_to_non_nullable
as int?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PickedVideo].
extension PickedVideoPatterns on PickedVideo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PickedVideo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PickedVideo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PickedVideo value)  $default,){
final _that = this;
switch (_that) {
case _PickedVideo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PickedVideo value)?  $default,){
final _that = this;
switch (_that) {
case _PickedVideo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uri,  int sizeBytes,  String displayName,  bool persisted,  int? durationMs,  int? dateTakenMs,  int? width,  int? height,  String? mimeType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PickedVideo() when $default != null:
return $default(_that.uri,_that.sizeBytes,_that.displayName,_that.persisted,_that.durationMs,_that.dateTakenMs,_that.width,_that.height,_that.mimeType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uri,  int sizeBytes,  String displayName,  bool persisted,  int? durationMs,  int? dateTakenMs,  int? width,  int? height,  String? mimeType)  $default,) {final _that = this;
switch (_that) {
case _PickedVideo():
return $default(_that.uri,_that.sizeBytes,_that.displayName,_that.persisted,_that.durationMs,_that.dateTakenMs,_that.width,_that.height,_that.mimeType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uri,  int sizeBytes,  String displayName,  bool persisted,  int? durationMs,  int? dateTakenMs,  int? width,  int? height,  String? mimeType)?  $default,) {final _that = this;
switch (_that) {
case _PickedVideo() when $default != null:
return $default(_that.uri,_that.sizeBytes,_that.displayName,_that.persisted,_that.durationMs,_that.dateTakenMs,_that.width,_that.height,_that.mimeType);case _:
  return null;

}
}

}

/// @nodoc


class _PickedVideo implements PickedVideo {
  const _PickedVideo({required this.uri, required this.sizeBytes, required this.displayName, required this.persisted, this.durationMs, this.dateTakenMs, this.width, this.height, this.mimeType});
  

@override final  String uri;
@override final  int sizeBytes;
@override final  String displayName;
@override final  bool persisted;
@override final  int? durationMs;
@override final  int? dateTakenMs;
@override final  int? width;
@override final  int? height;
@override final  String? mimeType;

/// Create a copy of PickedVideo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PickedVideoCopyWith<_PickedVideo> get copyWith => __$PickedVideoCopyWithImpl<_PickedVideo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PickedVideo&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.persisted, persisted) || other.persisted == persisted)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.dateTakenMs, dateTakenMs) || other.dateTakenMs == dateTakenMs)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}


@override
int get hashCode {
    return Object.hash(runtimeType,uri,sizeBytes,displayName,persisted,durationMs,dateTakenMs,width,height,mimeType);
}

@override
String toString() {
    return 'PickedVideo(uri: $uri, sizeBytes: $sizeBytes, displayName: $displayName, persisted: $persisted, durationMs: $durationMs, dateTakenMs: $dateTakenMs, width: $width, height: $height, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class _$PickedVideoCopyWith<$Res> implements $PickedVideoCopyWith<$Res> {
  factory _$PickedVideoCopyWith(_PickedVideo value, $Res Function(_PickedVideo) _then) = __$PickedVideoCopyWithImpl;
@override @useResult
$Res call({
 String uri, int sizeBytes, String displayName, bool persisted, int? durationMs, int? dateTakenMs, int? width, int? height, String? mimeType
});




}
/// @nodoc
class __$PickedVideoCopyWithImpl<$Res>
    implements _$PickedVideoCopyWith<$Res> {
  __$PickedVideoCopyWithImpl(this._self, this._then);

  final _PickedVideo _self;
  final $Res Function(_PickedVideo) _then;

/// Create a copy of PickedVideo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uri = null,Object? sizeBytes = null,Object? displayName = null,Object? persisted = null,Object? durationMs = freezed,Object? dateTakenMs = freezed,Object? width = freezed,Object? height = freezed,Object? mimeType = freezed,}) {
  return _then(_PickedVideo(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,persisted: null == persisted ? _self.persisted : persisted // ignore: cast_nullable_to_non_nullable
as bool,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,dateTakenMs: freezed == dateTakenMs ? _self.dateTakenMs : dateTakenMs // ignore: cast_nullable_to_non_nullable
as int?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VolumeBaseline {

 String get version; int get generation;
/// Create a copy of VolumeBaseline
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VolumeBaselineCopyWith<VolumeBaseline> get copyWith => _$VolumeBaselineCopyWithImpl<VolumeBaseline>(this as VolumeBaseline, _$identity);

  /// Serializes this VolumeBaseline to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VolumeBaseline;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VolumeBaseline&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.generation, _this.generation) || other.generation == _this.generation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VolumeBaseline;
  return Object.hash(runtimeType,_this.version,_this.generation);
}

@override
String toString() {
  final _this = this as VolumeBaseline;
  return 'VolumeBaseline(version: ${_this.version}, generation: ${_this.generation})';
}


}

/// @nodoc
abstract mixin class $VolumeBaselineCopyWith<$Res>  {
  factory $VolumeBaselineCopyWith(VolumeBaseline value, $Res Function(VolumeBaseline) _then) = _$VolumeBaselineCopyWithImpl;
@useResult
$Res call({
 String version, int generation
});




}
/// @nodoc
class _$VolumeBaselineCopyWithImpl<$Res>
    implements $VolumeBaselineCopyWith<$Res> {
  _$VolumeBaselineCopyWithImpl(this._self, this._then);

  final VolumeBaseline _self;
  final $Res Function(VolumeBaseline) _then;

/// Create a copy of VolumeBaseline
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? generation = null,}) {
  return _then(VolumeBaseline(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VolumeBaseline].
extension VolumeBaselinePatterns on VolumeBaseline {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VolumeBaseline value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VolumeBaseline() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VolumeBaseline value)  $default,){
final _that = this;
switch (_that) {
case _VolumeBaseline():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VolumeBaseline value)?  $default,){
final _that = this;
switch (_that) {
case _VolumeBaseline() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version,  int generation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VolumeBaseline() when $default != null:
return $default(_that.version,_that.generation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version,  int generation)  $default,) {final _that = this;
switch (_that) {
case _VolumeBaseline():
return $default(_that.version,_that.generation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version,  int generation)?  $default,) {final _that = this;
switch (_that) {
case _VolumeBaseline() when $default != null:
return $default(_that.version,_that.generation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VolumeBaseline implements VolumeBaseline {
  const _VolumeBaseline({required this.version, required this.generation});
  factory _VolumeBaseline.fromJson(Map<String, dynamic> json) => _$VolumeBaselineFromJson(json);

@override final  String version;
@override final  int generation;

/// Create a copy of VolumeBaseline
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VolumeBaselineCopyWith<_VolumeBaseline> get copyWith => __$VolumeBaselineCopyWithImpl<_VolumeBaseline>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VolumeBaselineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VolumeBaseline&&(identical(other.version, version) || other.version == version)&&(identical(other.generation, generation) || other.generation == generation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,generation);
}

@override
String toString() {
    return 'VolumeBaseline(version: $version, generation: $generation)';
}


}

/// @nodoc
abstract mixin class _$VolumeBaselineCopyWith<$Res> implements $VolumeBaselineCopyWith<$Res> {
  factory _$VolumeBaselineCopyWith(_VolumeBaseline value, $Res Function(_VolumeBaseline) _then) = __$VolumeBaselineCopyWithImpl;
@override @useResult
$Res call({
 String version, int generation
});




}
/// @nodoc
class __$VolumeBaselineCopyWithImpl<$Res>
    implements _$VolumeBaselineCopyWith<$Res> {
  __$VolumeBaselineCopyWithImpl(this._self, this._then);

  final _VolumeBaseline _self;
  final $Res Function(_VolumeBaseline) _then;

/// Create a copy of VolumeBaseline
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? generation = null,}) {
  return _then(_VolumeBaseline(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ShootingState {

 bool get on; Map<String, VolumeBaseline> get baselines; DateTime? get since; bool get stillAnswered;
/// Create a copy of ShootingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShootingStateCopyWith<ShootingState> get copyWith => _$ShootingStateCopyWithImpl<ShootingState>(this as ShootingState, _$identity);

  /// Serializes this ShootingState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ShootingState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShootingState&&(identical(other.on, _this.on) || other.on == _this.on)&&const DeepCollectionEquality().equals(other.baselines, _this.baselines)&&(identical(other.since, _this.since) || other.since == _this.since)&&(identical(other.stillAnswered, _this.stillAnswered) || other.stillAnswered == _this.stillAnswered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ShootingState;
  return Object.hash(runtimeType,_this.on,const DeepCollectionEquality().hash(_this.baselines),_this.since,_this.stillAnswered);
}

@override
String toString() {
  final _this = this as ShootingState;
  return 'ShootingState(on: ${_this.on}, baselines: ${_this.baselines}, since: ${_this.since}, stillAnswered: ${_this.stillAnswered})';
}


}

/// @nodoc
abstract mixin class $ShootingStateCopyWith<$Res>  {
  factory $ShootingStateCopyWith(ShootingState value, $Res Function(ShootingState) _then) = _$ShootingStateCopyWithImpl;
@useResult
$Res call({
 bool on, Map<String, VolumeBaseline> baselines, DateTime? since, bool stillAnswered
});




}
/// @nodoc
class _$ShootingStateCopyWithImpl<$Res>
    implements $ShootingStateCopyWith<$Res> {
  _$ShootingStateCopyWithImpl(this._self, this._then);

  final ShootingState _self;
  final $Res Function(ShootingState) _then;

/// Create a copy of ShootingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? on = null,Object? baselines = null,Object? since = freezed,Object? stillAnswered = null,}) {
  return _then(ShootingState(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool,baselines: null == baselines ? _self.baselines : baselines // ignore: cast_nullable_to_non_nullable
as Map<String, VolumeBaseline>,since: freezed == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime?,stillAnswered: null == stillAnswered ? _self.stillAnswered : stillAnswered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ShootingState].
extension ShootingStatePatterns on ShootingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShootingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShootingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShootingState value)  $default,){
final _that = this;
switch (_that) {
case _ShootingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShootingState value)?  $default,){
final _that = this;
switch (_that) {
case _ShootingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool on,  Map<String, VolumeBaseline> baselines,  DateTime? since,  bool stillAnswered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShootingState() when $default != null:
return $default(_that.on,_that.baselines,_that.since,_that.stillAnswered);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool on,  Map<String, VolumeBaseline> baselines,  DateTime? since,  bool stillAnswered)  $default,) {final _that = this;
switch (_that) {
case _ShootingState():
return $default(_that.on,_that.baselines,_that.since,_that.stillAnswered);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool on,  Map<String, VolumeBaseline> baselines,  DateTime? since,  bool stillAnswered)?  $default,) {final _that = this;
switch (_that) {
case _ShootingState() when $default != null:
return $default(_that.on,_that.baselines,_that.since,_that.stillAnswered);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShootingState extends ShootingState {
  const _ShootingState({required this.on, required  Map<String, VolumeBaseline> baselines, this.since, this.stillAnswered = false}): _baselines = baselines,super._();
  factory _ShootingState.fromJson(Map<String, dynamic> json) => _$ShootingStateFromJson(json);

@override final  bool on;
 final  Map<String, VolumeBaseline> _baselines;
@override Map<String, VolumeBaseline> get baselines {
  if (_baselines is EqualUnmodifiableMapView) return _baselines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_baselines);
}

@override final  DateTime? since;
@override@JsonKey() final  bool stillAnswered;

/// Create a copy of ShootingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShootingStateCopyWith<_ShootingState> get copyWith => __$ShootingStateCopyWithImpl<_ShootingState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShootingStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShootingState&&(identical(other.on, on) || other.on == on)&&const DeepCollectionEquality().equals(other.baselines, _baselines)&&(identical(other.since, since) || other.since == since)&&(identical(other.stillAnswered, stillAnswered) || other.stillAnswered == stillAnswered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,on,const DeepCollectionEquality().hash(_baselines),since,stillAnswered);
}

@override
String toString() {
    return 'ShootingState(on: $on, baselines: $baselines, since: $since, stillAnswered: $stillAnswered)';
}


}

/// @nodoc
abstract mixin class _$ShootingStateCopyWith<$Res> implements $ShootingStateCopyWith<$Res> {
  factory _$ShootingStateCopyWith(_ShootingState value, $Res Function(_ShootingState) _then) = __$ShootingStateCopyWithImpl;
@override @useResult
$Res call({
 bool on, Map<String, VolumeBaseline> baselines, DateTime? since, bool stillAnswered
});




}
/// @nodoc
class __$ShootingStateCopyWithImpl<$Res>
    implements _$ShootingStateCopyWith<$Res> {
  __$ShootingStateCopyWithImpl(this._self, this._then);

  final _ShootingState _self;
  final $Res Function(_ShootingState) _then;

/// Create a copy of ShootingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? on = null,Object? baselines = null,Object? since = freezed,Object? stillAnswered = null,}) {
  return _then(_ShootingState(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool,baselines: null == baselines ? _self._baselines : baselines // ignore: cast_nullable_to_non_nullable
as Map<String, VolumeBaseline>,since: freezed == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime?,stillAnswered: null == stillAnswered ? _self.stillAnswered : stillAnswered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
