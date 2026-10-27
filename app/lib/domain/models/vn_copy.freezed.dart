// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vn_copy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VnCopy {

 int get reelId; int get clipId; int get copyMediaStoreId; String get fileName; int get sizeBytes;
/// Create a copy of VnCopy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VnCopyCopyWith<VnCopy> get copyWith => _$VnCopyCopyWithImpl<VnCopy>(this as VnCopy, _$identity);

  /// Serializes this VnCopy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VnCopy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VnCopy&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.clipId, _this.clipId) || other.clipId == _this.clipId)&&(identical(other.copyMediaStoreId, _this.copyMediaStoreId) || other.copyMediaStoreId == _this.copyMediaStoreId)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VnCopy;
  return Object.hash(runtimeType,_this.reelId,_this.clipId,_this.copyMediaStoreId,_this.fileName,_this.sizeBytes);
}

@override
String toString() {
  final _this = this as VnCopy;
  return 'VnCopy(reelId: ${_this.reelId}, clipId: ${_this.clipId}, copyMediaStoreId: ${_this.copyMediaStoreId}, fileName: ${_this.fileName}, sizeBytes: ${_this.sizeBytes})';
}


}

/// @nodoc
abstract mixin class $VnCopyCopyWith<$Res>  {
  factory $VnCopyCopyWith(VnCopy value, $Res Function(VnCopy) _then) = _$VnCopyCopyWithImpl;
@useResult
$Res call({
 int reelId, int clipId, int copyMediaStoreId, String fileName, int sizeBytes
});




}
/// @nodoc
class _$VnCopyCopyWithImpl<$Res>
    implements $VnCopyCopyWith<$Res> {
  _$VnCopyCopyWithImpl(this._self, this._then);

  final VnCopy _self;
  final $Res Function(VnCopy) _then;

/// Create a copy of VnCopy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,}) {
  return _then(VnCopy(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VnCopy].
extension VnCopyPatterns on VnCopy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VnCopy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VnCopy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VnCopy value)  $default,){
final _that = this;
switch (_that) {
case _VnCopy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VnCopy value)?  $default,){
final _that = this;
switch (_that) {
case _VnCopy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VnCopy() when $default != null:
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes)  $default,) {final _that = this;
switch (_that) {
case _VnCopy():
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes)?  $default,) {final _that = this;
switch (_that) {
case _VnCopy() when $default != null:
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VnCopy implements VnCopy {
  const _VnCopy({required this.reelId, required this.clipId, required this.copyMediaStoreId, required this.fileName, required this.sizeBytes});
  factory _VnCopy.fromJson(Map<String, dynamic> json) => _$VnCopyFromJson(json);

@override final  int reelId;
@override final  int clipId;
@override final  int copyMediaStoreId;
@override final  String fileName;
@override final  int sizeBytes;

/// Create a copy of VnCopy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VnCopyCopyWith<_VnCopy> get copyWith => __$VnCopyCopyWithImpl<_VnCopy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VnCopyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VnCopy&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.clipId, clipId) || other.clipId == clipId)&&(identical(other.copyMediaStoreId, copyMediaStoreId) || other.copyMediaStoreId == copyMediaStoreId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reelId,clipId,copyMediaStoreId,fileName,sizeBytes);
}

@override
String toString() {
    return 'VnCopy(reelId: $reelId, clipId: $clipId, copyMediaStoreId: $copyMediaStoreId, fileName: $fileName, sizeBytes: $sizeBytes)';
}


}

/// @nodoc
abstract mixin class _$VnCopyCopyWith<$Res> implements $VnCopyCopyWith<$Res> {
  factory _$VnCopyCopyWith(_VnCopy value, $Res Function(_VnCopy) _then) = __$VnCopyCopyWithImpl;
@override @useResult
$Res call({
 int reelId, int clipId, int copyMediaStoreId, String fileName, int sizeBytes
});




}
/// @nodoc
class __$VnCopyCopyWithImpl<$Res>
    implements _$VnCopyCopyWith<$Res> {
  __$VnCopyCopyWithImpl(this._self, this._then);

  final _VnCopy _self;
  final $Res Function(_VnCopy) _then;

/// Create a copy of VnCopy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,}) {
  return _then(_VnCopy(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
