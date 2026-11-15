// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edit_copy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EditCopy {

 int get reelId; int get clipId; int get copyMediaStoreId; String get fileName; int get sizeBytes; DateTime get copiedAt;
/// Create a copy of EditCopy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditCopyCopyWith<EditCopy> get copyWith => _$EditCopyCopyWithImpl<EditCopy>(this as EditCopy, _$identity);

  /// Serializes this EditCopy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditCopy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditCopy&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.clipId, _this.clipId) || other.clipId == _this.clipId)&&(identical(other.copyMediaStoreId, _this.copyMediaStoreId) || other.copyMediaStoreId == _this.copyMediaStoreId)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.copiedAt, _this.copiedAt) || other.copiedAt == _this.copiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditCopy;
  return Object.hash(runtimeType,_this.reelId,_this.clipId,_this.copyMediaStoreId,_this.fileName,_this.sizeBytes,_this.copiedAt);
}

@override
String toString() {
  final _this = this as EditCopy;
  return 'EditCopy(reelId: ${_this.reelId}, clipId: ${_this.clipId}, copyMediaStoreId: ${_this.copyMediaStoreId}, fileName: ${_this.fileName}, sizeBytes: ${_this.sizeBytes}, copiedAt: ${_this.copiedAt})';
}


}

/// @nodoc
abstract mixin class $EditCopyCopyWith<$Res>  {
  factory $EditCopyCopyWith(EditCopy value, $Res Function(EditCopy) _then) = _$EditCopyCopyWithImpl;
@useResult
$Res call({
 int reelId, int clipId, int copyMediaStoreId, String fileName, int sizeBytes, DateTime copiedAt
});




}
/// @nodoc
class _$EditCopyCopyWithImpl<$Res>
    implements $EditCopyCopyWith<$Res> {
  _$EditCopyCopyWithImpl(this._self, this._then);

  final EditCopy _self;
  final $Res Function(EditCopy) _then;

/// Create a copy of EditCopy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? copiedAt = null,}) {
  return _then(EditCopy(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,copiedAt: null == copiedAt ? _self.copiedAt : copiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EditCopy].
extension EditCopyPatterns on EditCopy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditCopy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditCopy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditCopy value)  $default,){
final _that = this;
switch (_that) {
case _EditCopy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditCopy value)?  $default,){
final _that = this;
switch (_that) {
case _EditCopy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditCopy() when $default != null:
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)  $default,) {final _that = this;
switch (_that) {
case _EditCopy():
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)?  $default,) {final _that = this;
switch (_that) {
case _EditCopy() when $default != null:
return $default(_that.reelId,_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditCopy implements EditCopy {
  const _EditCopy({required this.reelId, required this.clipId, required this.copyMediaStoreId, required this.fileName, required this.sizeBytes, required this.copiedAt});
  factory _EditCopy.fromJson(Map<String, dynamic> json) => _$EditCopyFromJson(json);

@override final  int reelId;
@override final  int clipId;
@override final  int copyMediaStoreId;
@override final  String fileName;
@override final  int sizeBytes;
@override final  DateTime copiedAt;

/// Create a copy of EditCopy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditCopyCopyWith<_EditCopy> get copyWith => __$EditCopyCopyWithImpl<_EditCopy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditCopyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditCopy&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.clipId, clipId) || other.clipId == clipId)&&(identical(other.copyMediaStoreId, copyMediaStoreId) || other.copyMediaStoreId == copyMediaStoreId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.copiedAt, copiedAt) || other.copiedAt == copiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reelId,clipId,copyMediaStoreId,fileName,sizeBytes,copiedAt);
}

@override
String toString() {
    return 'EditCopy(reelId: $reelId, clipId: $clipId, copyMediaStoreId: $copyMediaStoreId, fileName: $fileName, sizeBytes: $sizeBytes, copiedAt: $copiedAt)';
}


}

/// @nodoc
abstract mixin class _$EditCopyCopyWith<$Res> implements $EditCopyCopyWith<$Res> {
  factory _$EditCopyCopyWith(_EditCopy value, $Res Function(_EditCopy) _then) = __$EditCopyCopyWithImpl;
@override @useResult
$Res call({
 int reelId, int clipId, int copyMediaStoreId, String fileName, int sizeBytes, DateTime copiedAt
});




}
/// @nodoc
class __$EditCopyCopyWithImpl<$Res>
    implements _$EditCopyCopyWith<$Res> {
  __$EditCopyCopyWithImpl(this._self, this._then);

  final _EditCopy _self;
  final $Res Function(_EditCopy) _then;

/// Create a copy of EditCopy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? copiedAt = null,}) {
  return _then(_EditCopy(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,copiedAt: null == copiedAt ? _self.copiedAt : copiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
