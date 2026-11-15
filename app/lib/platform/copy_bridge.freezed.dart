// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'copy_bridge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CopyItem {

 int get clipId; ClipRef get source; String get fileName; int get sizeBytes;
/// Create a copy of CopyItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopyItemCopyWith<CopyItem> get copyWith => _$CopyItemCopyWithImpl<CopyItem>(this as CopyItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CopyItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopyItem&&(identical(other.clipId, _this.clipId) || other.clipId == _this.clipId)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes));
}


@override
int get hashCode {
  final _this = this as CopyItem;
  return Object.hash(runtimeType,_this.clipId,_this.source,_this.fileName,_this.sizeBytes);
}

@override
String toString() {
  final _this = this as CopyItem;
  return 'CopyItem(clipId: ${_this.clipId}, source: ${_this.source}, fileName: ${_this.fileName}, sizeBytes: ${_this.sizeBytes})';
}


}

/// @nodoc
abstract mixin class $CopyItemCopyWith<$Res>  {
  factory $CopyItemCopyWith(CopyItem value, $Res Function(CopyItem) _then) = _$CopyItemCopyWithImpl;
@useResult
$Res call({
 int clipId, ClipRef source, String fileName, int sizeBytes
});




}
/// @nodoc
class _$CopyItemCopyWithImpl<$Res>
    implements $CopyItemCopyWith<$Res> {
  _$CopyItemCopyWithImpl(this._self, this._then);

  final CopyItem _self;
  final $Res Function(CopyItem) _then;

/// Create a copy of CopyItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clipId = null,Object? source = null,Object? fileName = null,Object? sizeBytes = null,}) {
  return _then(CopyItem(
clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipRef,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CopyItem].
extension CopyItemPatterns on CopyItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopyItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopyItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopyItem value)  $default,){
final _that = this;
switch (_that) {
case _CopyItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopyItem value)?  $default,){
final _that = this;
switch (_that) {
case _CopyItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int clipId,  ClipRef source,  String fileName,  int sizeBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopyItem() when $default != null:
return $default(_that.clipId,_that.source,_that.fileName,_that.sizeBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int clipId,  ClipRef source,  String fileName,  int sizeBytes)  $default,) {final _that = this;
switch (_that) {
case _CopyItem():
return $default(_that.clipId,_that.source,_that.fileName,_that.sizeBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int clipId,  ClipRef source,  String fileName,  int sizeBytes)?  $default,) {final _that = this;
switch (_that) {
case _CopyItem() when $default != null:
return $default(_that.clipId,_that.source,_that.fileName,_that.sizeBytes);case _:
  return null;

}
}

}

/// @nodoc


class _CopyItem implements CopyItem {
  const _CopyItem({required this.clipId, required this.source, required this.fileName, required this.sizeBytes});
  

@override final  int clipId;
@override final  ClipRef source;
@override final  String fileName;
@override final  int sizeBytes;

/// Create a copy of CopyItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopyItemCopyWith<_CopyItem> get copyWith => __$CopyItemCopyWithImpl<_CopyItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopyItem&&(identical(other.clipId, clipId) || other.clipId == clipId)&&(identical(other.source, source) || other.source == source)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,clipId,source,fileName,sizeBytes);
}

@override
String toString() {
    return 'CopyItem(clipId: $clipId, source: $source, fileName: $fileName, sizeBytes: $sizeBytes)';
}


}

/// @nodoc
abstract mixin class _$CopyItemCopyWith<$Res> implements $CopyItemCopyWith<$Res> {
  factory _$CopyItemCopyWith(_CopyItem value, $Res Function(_CopyItem) _then) = __$CopyItemCopyWithImpl;
@override @useResult
$Res call({
 int clipId, ClipRef source, String fileName, int sizeBytes
});




}
/// @nodoc
class __$CopyItemCopyWithImpl<$Res>
    implements _$CopyItemCopyWith<$Res> {
  __$CopyItemCopyWithImpl(this._self, this._then);

  final _CopyItem _self;
  final $Res Function(_CopyItem) _then;

/// Create a copy of CopyItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clipId = null,Object? source = null,Object? fileName = null,Object? sizeBytes = null,}) {
  return _then(_CopyItem(
clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClipRef,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$CopyRequest {

 String get jobId; int get reelId; String get folderName; List<CopyItem> get items;
/// Create a copy of CopyRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopyRequestCopyWith<CopyRequest> get copyWith => _$CopyRequestCopyWithImpl<CopyRequest>(this as CopyRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CopyRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopyRequest&&(identical(other.jobId, _this.jobId) || other.jobId == _this.jobId)&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.folderName, _this.folderName) || other.folderName == _this.folderName)&&const DeepCollectionEquality().equals(other.items, _this.items));
}


@override
int get hashCode {
  final _this = this as CopyRequest;
  return Object.hash(runtimeType,_this.jobId,_this.reelId,_this.folderName,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as CopyRequest;
  return 'CopyRequest(jobId: ${_this.jobId}, reelId: ${_this.reelId}, folderName: ${_this.folderName}, items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $CopyRequestCopyWith<$Res>  {
  factory $CopyRequestCopyWith(CopyRequest value, $Res Function(CopyRequest) _then) = _$CopyRequestCopyWithImpl;
@useResult
$Res call({
 String jobId, int reelId, String folderName, List<CopyItem> items
});




}
/// @nodoc
class _$CopyRequestCopyWithImpl<$Res>
    implements $CopyRequestCopyWith<$Res> {
  _$CopyRequestCopyWithImpl(this._self, this._then);

  final CopyRequest _self;
  final $Res Function(CopyRequest) _then;

/// Create a copy of CopyRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jobId = null,Object? reelId = null,Object? folderName = null,Object? items = null,}) {
  return _then(CopyRequest(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CopyItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [CopyRequest].
extension CopyRequestPatterns on CopyRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopyRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopyRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopyRequest value)  $default,){
final _that = this;
switch (_that) {
case _CopyRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopyRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CopyRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String jobId,  int reelId,  String folderName,  List<CopyItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopyRequest() when $default != null:
return $default(_that.jobId,_that.reelId,_that.folderName,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String jobId,  int reelId,  String folderName,  List<CopyItem> items)  $default,) {final _that = this;
switch (_that) {
case _CopyRequest():
return $default(_that.jobId,_that.reelId,_that.folderName,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String jobId,  int reelId,  String folderName,  List<CopyItem> items)?  $default,) {final _that = this;
switch (_that) {
case _CopyRequest() when $default != null:
return $default(_that.jobId,_that.reelId,_that.folderName,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _CopyRequest implements CopyRequest {
  const _CopyRequest({required this.jobId, required this.reelId, required this.folderName, required  List<CopyItem> items}): _items = items;
  

@override final  String jobId;
@override final  int reelId;
@override final  String folderName;
 final  List<CopyItem> _items;
@override List<CopyItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of CopyRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopyRequestCopyWith<_CopyRequest> get copyWith => __$CopyRequestCopyWithImpl<_CopyRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopyRequest&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&const DeepCollectionEquality().equals(other.items, _items));
}


@override
int get hashCode {
    return Object.hash(runtimeType,jobId,reelId,folderName,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'CopyRequest(jobId: $jobId, reelId: $reelId, folderName: $folderName, items: $items)';
}


}

/// @nodoc
abstract mixin class _$CopyRequestCopyWith<$Res> implements $CopyRequestCopyWith<$Res> {
  factory _$CopyRequestCopyWith(_CopyRequest value, $Res Function(_CopyRequest) _then) = __$CopyRequestCopyWithImpl;
@override @useResult
$Res call({
 String jobId, int reelId, String folderName, List<CopyItem> items
});




}
/// @nodoc
class __$CopyRequestCopyWithImpl<$Res>
    implements _$CopyRequestCopyWith<$Res> {
  __$CopyRequestCopyWithImpl(this._self, this._then);

  final _CopyRequest _self;
  final $Res Function(_CopyRequest) _then;

/// Create a copy of CopyRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? reelId = null,Object? folderName = null,Object? items = null,}) {
  return _then(_CopyRequest(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CopyItem>,
  ));
}


}

/// @nodoc
mixin _$CopiedFile {

 int get clipId; int get copyMediaStoreId; String get fileName; int get sizeBytes; DateTime get copiedAt;
/// Create a copy of CopiedFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopiedFileCopyWith<CopiedFile> get copyWith => _$CopiedFileCopyWithImpl<CopiedFile>(this as CopiedFile, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CopiedFile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopiedFile&&(identical(other.clipId, _this.clipId) || other.clipId == _this.clipId)&&(identical(other.copyMediaStoreId, _this.copyMediaStoreId) || other.copyMediaStoreId == _this.copyMediaStoreId)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.copiedAt, _this.copiedAt) || other.copiedAt == _this.copiedAt));
}


@override
int get hashCode {
  final _this = this as CopiedFile;
  return Object.hash(runtimeType,_this.clipId,_this.copyMediaStoreId,_this.fileName,_this.sizeBytes,_this.copiedAt);
}

@override
String toString() {
  final _this = this as CopiedFile;
  return 'CopiedFile(clipId: ${_this.clipId}, copyMediaStoreId: ${_this.copyMediaStoreId}, fileName: ${_this.fileName}, sizeBytes: ${_this.sizeBytes}, copiedAt: ${_this.copiedAt})';
}


}

/// @nodoc
abstract mixin class $CopiedFileCopyWith<$Res>  {
  factory $CopiedFileCopyWith(CopiedFile value, $Res Function(CopiedFile) _then) = _$CopiedFileCopyWithImpl;
@useResult
$Res call({
 int clipId, int copyMediaStoreId, String fileName, int sizeBytes, DateTime copiedAt
});




}
/// @nodoc
class _$CopiedFileCopyWithImpl<$Res>
    implements $CopiedFileCopyWith<$Res> {
  _$CopiedFileCopyWithImpl(this._self, this._then);

  final CopiedFile _self;
  final $Res Function(CopiedFile) _then;

/// Create a copy of CopiedFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? copiedAt = null,}) {
  return _then(CopiedFile(
clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,copiedAt: null == copiedAt ? _self.copiedAt : copiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CopiedFile].
extension CopiedFilePatterns on CopiedFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopiedFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopiedFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopiedFile value)  $default,){
final _that = this;
switch (_that) {
case _CopiedFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopiedFile value)?  $default,){
final _that = this;
switch (_that) {
case _CopiedFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopiedFile() when $default != null:
return $default(_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)  $default,) {final _that = this;
switch (_that) {
case _CopiedFile():
return $default(_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int clipId,  int copyMediaStoreId,  String fileName,  int sizeBytes,  DateTime copiedAt)?  $default,) {final _that = this;
switch (_that) {
case _CopiedFile() when $default != null:
return $default(_that.clipId,_that.copyMediaStoreId,_that.fileName,_that.sizeBytes,_that.copiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _CopiedFile implements CopiedFile {
  const _CopiedFile({required this.clipId, required this.copyMediaStoreId, required this.fileName, required this.sizeBytes, required this.copiedAt});
  

@override final  int clipId;
@override final  int copyMediaStoreId;
@override final  String fileName;
@override final  int sizeBytes;
@override final  DateTime copiedAt;

/// Create a copy of CopiedFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopiedFileCopyWith<_CopiedFile> get copyWith => __$CopiedFileCopyWithImpl<_CopiedFile>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopiedFile&&(identical(other.clipId, clipId) || other.clipId == clipId)&&(identical(other.copyMediaStoreId, copyMediaStoreId) || other.copyMediaStoreId == copyMediaStoreId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.copiedAt, copiedAt) || other.copiedAt == copiedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,clipId,copyMediaStoreId,fileName,sizeBytes,copiedAt);
}

@override
String toString() {
    return 'CopiedFile(clipId: $clipId, copyMediaStoreId: $copyMediaStoreId, fileName: $fileName, sizeBytes: $sizeBytes, copiedAt: $copiedAt)';
}


}

/// @nodoc
abstract mixin class _$CopiedFileCopyWith<$Res> implements $CopiedFileCopyWith<$Res> {
  factory _$CopiedFileCopyWith(_CopiedFile value, $Res Function(_CopiedFile) _then) = __$CopiedFileCopyWithImpl;
@override @useResult
$Res call({
 int clipId, int copyMediaStoreId, String fileName, int sizeBytes, DateTime copiedAt
});




}
/// @nodoc
class __$CopiedFileCopyWithImpl<$Res>
    implements _$CopiedFileCopyWith<$Res> {
  __$CopiedFileCopyWithImpl(this._self, this._then);

  final _CopiedFile _self;
  final $Res Function(_CopiedFile) _then;

/// Create a copy of CopiedFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clipId = null,Object? copyMediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? copiedAt = null,}) {
  return _then(_CopiedFile(
clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,copyMediaStoreId: null == copyMediaStoreId ? _self.copyMediaStoreId : copyMediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,copiedAt: null == copiedAt ? _self.copiedAt : copiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$CopyJob {

 String get jobId; int get reelId; String get folderName; CopyState get state; int get total; int get done; int get bytesDone; int get bytesTotal; List<CopiedFile> get copied; List<int> get failedClipIds; List<CopiedFile> get undeleted; bool get wasClosed;
/// Create a copy of CopyJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopyJobCopyWith<CopyJob> get copyWith => _$CopyJobCopyWithImpl<CopyJob>(this as CopyJob, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CopyJob;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopyJob&&(identical(other.jobId, _this.jobId) || other.jobId == _this.jobId)&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.folderName, _this.folderName) || other.folderName == _this.folderName)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.done, _this.done) || other.done == _this.done)&&(identical(other.bytesDone, _this.bytesDone) || other.bytesDone == _this.bytesDone)&&(identical(other.bytesTotal, _this.bytesTotal) || other.bytesTotal == _this.bytesTotal)&&const DeepCollectionEquality().equals(other.copied, _this.copied)&&const DeepCollectionEquality().equals(other.failedClipIds, _this.failedClipIds)&&const DeepCollectionEquality().equals(other.undeleted, _this.undeleted)&&(identical(other.wasClosed, _this.wasClosed) || other.wasClosed == _this.wasClosed));
}


@override
int get hashCode {
  final _this = this as CopyJob;
  return Object.hash(runtimeType,_this.jobId,_this.reelId,_this.folderName,_this.state,_this.total,_this.done,_this.bytesDone,_this.bytesTotal,const DeepCollectionEquality().hash(_this.copied),const DeepCollectionEquality().hash(_this.failedClipIds),const DeepCollectionEquality().hash(_this.undeleted),_this.wasClosed);
}

@override
String toString() {
  final _this = this as CopyJob;
  return 'CopyJob(jobId: ${_this.jobId}, reelId: ${_this.reelId}, folderName: ${_this.folderName}, state: ${_this.state}, total: ${_this.total}, done: ${_this.done}, bytesDone: ${_this.bytesDone}, bytesTotal: ${_this.bytesTotal}, copied: ${_this.copied}, failedClipIds: ${_this.failedClipIds}, undeleted: ${_this.undeleted}, wasClosed: ${_this.wasClosed})';
}


}

/// @nodoc
abstract mixin class $CopyJobCopyWith<$Res>  {
  factory $CopyJobCopyWith(CopyJob value, $Res Function(CopyJob) _then) = _$CopyJobCopyWithImpl;
@useResult
$Res call({
 String jobId, int reelId, String folderName, CopyState state, int total, int done, int bytesDone, int bytesTotal, List<CopiedFile> copied, List<int> failedClipIds, List<CopiedFile> undeleted, bool wasClosed
});




}
/// @nodoc
class _$CopyJobCopyWithImpl<$Res>
    implements $CopyJobCopyWith<$Res> {
  _$CopyJobCopyWithImpl(this._self, this._then);

  final CopyJob _self;
  final $Res Function(CopyJob) _then;

/// Create a copy of CopyJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jobId = null,Object? reelId = null,Object? folderName = null,Object? state = null,Object? total = null,Object? done = null,Object? bytesDone = null,Object? bytesTotal = null,Object? copied = null,Object? failedClipIds = null,Object? undeleted = null,Object? wasClosed = null,}) {
  return _then(CopyJob(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CopyState,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as int,bytesDone: null == bytesDone ? _self.bytesDone : bytesDone // ignore: cast_nullable_to_non_nullable
as int,bytesTotal: null == bytesTotal ? _self.bytesTotal : bytesTotal // ignore: cast_nullable_to_non_nullable
as int,copied: null == copied ? _self.copied : copied // ignore: cast_nullable_to_non_nullable
as List<CopiedFile>,failedClipIds: null == failedClipIds ? _self.failedClipIds : failedClipIds // ignore: cast_nullable_to_non_nullable
as List<int>,undeleted: null == undeleted ? _self.undeleted : undeleted // ignore: cast_nullable_to_non_nullable
as List<CopiedFile>,wasClosed: null == wasClosed ? _self.wasClosed : wasClosed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CopyJob].
extension CopyJobPatterns on CopyJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopyJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopyJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopyJob value)  $default,){
final _that = this;
switch (_that) {
case _CopyJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopyJob value)?  $default,){
final _that = this;
switch (_that) {
case _CopyJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String jobId,  int reelId,  String folderName,  CopyState state,  int total,  int done,  int bytesDone,  int bytesTotal,  List<CopiedFile> copied,  List<int> failedClipIds,  List<CopiedFile> undeleted,  bool wasClosed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopyJob() when $default != null:
return $default(_that.jobId,_that.reelId,_that.folderName,_that.state,_that.total,_that.done,_that.bytesDone,_that.bytesTotal,_that.copied,_that.failedClipIds,_that.undeleted,_that.wasClosed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String jobId,  int reelId,  String folderName,  CopyState state,  int total,  int done,  int bytesDone,  int bytesTotal,  List<CopiedFile> copied,  List<int> failedClipIds,  List<CopiedFile> undeleted,  bool wasClosed)  $default,) {final _that = this;
switch (_that) {
case _CopyJob():
return $default(_that.jobId,_that.reelId,_that.folderName,_that.state,_that.total,_that.done,_that.bytesDone,_that.bytesTotal,_that.copied,_that.failedClipIds,_that.undeleted,_that.wasClosed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String jobId,  int reelId,  String folderName,  CopyState state,  int total,  int done,  int bytesDone,  int bytesTotal,  List<CopiedFile> copied,  List<int> failedClipIds,  List<CopiedFile> undeleted,  bool wasClosed)?  $default,) {final _that = this;
switch (_that) {
case _CopyJob() when $default != null:
return $default(_that.jobId,_that.reelId,_that.folderName,_that.state,_that.total,_that.done,_that.bytesDone,_that.bytesTotal,_that.copied,_that.failedClipIds,_that.undeleted,_that.wasClosed);case _:
  return null;

}
}

}

/// @nodoc


class _CopyJob implements CopyJob {
  const _CopyJob({required this.jobId, required this.reelId, required this.folderName, required this.state, required this.total, required this.done, required this.bytesDone, required this.bytesTotal, required  List<CopiedFile> copied, required  List<int> failedClipIds, required  List<CopiedFile> undeleted, this.wasClosed = false}): _copied = copied,_failedClipIds = failedClipIds,_undeleted = undeleted;
  

@override final  String jobId;
@override final  int reelId;
@override final  String folderName;
@override final  CopyState state;
@override final  int total;
@override final  int done;
@override final  int bytesDone;
@override final  int bytesTotal;
 final  List<CopiedFile> _copied;
@override List<CopiedFile> get copied {
  if (_copied is EqualUnmodifiableListView) return _copied;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_copied);
}

 final  List<int> _failedClipIds;
@override List<int> get failedClipIds {
  if (_failedClipIds is EqualUnmodifiableListView) return _failedClipIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_failedClipIds);
}

 final  List<CopiedFile> _undeleted;
@override List<CopiedFile> get undeleted {
  if (_undeleted is EqualUnmodifiableListView) return _undeleted;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_undeleted);
}

@override@JsonKey() final  bool wasClosed;

/// Create a copy of CopyJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopyJobCopyWith<_CopyJob> get copyWith => __$CopyJobCopyWithImpl<_CopyJob>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopyJob&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.state, state) || other.state == state)&&(identical(other.total, total) || other.total == total)&&(identical(other.done, done) || other.done == done)&&(identical(other.bytesDone, bytesDone) || other.bytesDone == bytesDone)&&(identical(other.bytesTotal, bytesTotal) || other.bytesTotal == bytesTotal)&&const DeepCollectionEquality().equals(other.copied, _copied)&&const DeepCollectionEquality().equals(other.failedClipIds, _failedClipIds)&&const DeepCollectionEquality().equals(other.undeleted, _undeleted)&&(identical(other.wasClosed, wasClosed) || other.wasClosed == wasClosed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,jobId,reelId,folderName,state,total,done,bytesDone,bytesTotal,const DeepCollectionEquality().hash(_copied),const DeepCollectionEquality().hash(_failedClipIds),const DeepCollectionEquality().hash(_undeleted),wasClosed);
}

@override
String toString() {
    return 'CopyJob(jobId: $jobId, reelId: $reelId, folderName: $folderName, state: $state, total: $total, done: $done, bytesDone: $bytesDone, bytesTotal: $bytesTotal, copied: $copied, failedClipIds: $failedClipIds, undeleted: $undeleted, wasClosed: $wasClosed)';
}


}

/// @nodoc
abstract mixin class _$CopyJobCopyWith<$Res> implements $CopyJobCopyWith<$Res> {
  factory _$CopyJobCopyWith(_CopyJob value, $Res Function(_CopyJob) _then) = __$CopyJobCopyWithImpl;
@override @useResult
$Res call({
 String jobId, int reelId, String folderName, CopyState state, int total, int done, int bytesDone, int bytesTotal, List<CopiedFile> copied, List<int> failedClipIds, List<CopiedFile> undeleted, bool wasClosed
});




}
/// @nodoc
class __$CopyJobCopyWithImpl<$Res>
    implements _$CopyJobCopyWith<$Res> {
  __$CopyJobCopyWithImpl(this._self, this._then);

  final _CopyJob _self;
  final $Res Function(_CopyJob) _then;

/// Create a copy of CopyJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? reelId = null,Object? folderName = null,Object? state = null,Object? total = null,Object? done = null,Object? bytesDone = null,Object? bytesTotal = null,Object? copied = null,Object? failedClipIds = null,Object? undeleted = null,Object? wasClosed = null,}) {
  return _then(_CopyJob(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CopyState,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as int,bytesDone: null == bytesDone ? _self.bytesDone : bytesDone // ignore: cast_nullable_to_non_nullable
as int,bytesTotal: null == bytesTotal ? _self.bytesTotal : bytesTotal // ignore: cast_nullable_to_non_nullable
as int,copied: null == copied ? _self._copied : copied // ignore: cast_nullable_to_non_nullable
as List<CopiedFile>,failedClipIds: null == failedClipIds ? _self._failedClipIds : failedClipIds // ignore: cast_nullable_to_non_nullable
as List<int>,undeleted: null == undeleted ? _self._undeleted : undeleted // ignore: cast_nullable_to_non_nullable
as List<CopiedFile>,wasClosed: null == wasClosed ? _self.wasClosed : wasClosed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$FolderRow {

 int get mediaStoreId; String get fileName; int get sizeBytes; bool get pending;
/// Create a copy of FolderRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderRowCopyWith<FolderRow> get copyWith => _$FolderRowCopyWithImpl<FolderRow>(this as FolderRow, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FolderRow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderRow&&(identical(other.mediaStoreId, _this.mediaStoreId) || other.mediaStoreId == _this.mediaStoreId)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.pending, _this.pending) || other.pending == _this.pending));
}


@override
int get hashCode {
  final _this = this as FolderRow;
  return Object.hash(runtimeType,_this.mediaStoreId,_this.fileName,_this.sizeBytes,_this.pending);
}

@override
String toString() {
  final _this = this as FolderRow;
  return 'FolderRow(mediaStoreId: ${_this.mediaStoreId}, fileName: ${_this.fileName}, sizeBytes: ${_this.sizeBytes}, pending: ${_this.pending})';
}


}

/// @nodoc
abstract mixin class $FolderRowCopyWith<$Res>  {
  factory $FolderRowCopyWith(FolderRow value, $Res Function(FolderRow) _then) = _$FolderRowCopyWithImpl;
@useResult
$Res call({
 int mediaStoreId, String fileName, int sizeBytes, bool pending
});




}
/// @nodoc
class _$FolderRowCopyWithImpl<$Res>
    implements $FolderRowCopyWith<$Res> {
  _$FolderRowCopyWithImpl(this._self, this._then);

  final FolderRow _self;
  final $Res Function(FolderRow) _then;

/// Create a copy of FolderRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? pending = null,}) {
  return _then(FolderRow(
mediaStoreId: null == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FolderRow].
extension FolderRowPatterns on FolderRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FolderRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FolderRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FolderRow value)  $default,){
final _that = this;
switch (_that) {
case _FolderRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FolderRow value)?  $default,){
final _that = this;
switch (_that) {
case _FolderRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int mediaStoreId,  String fileName,  int sizeBytes,  bool pending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FolderRow() when $default != null:
return $default(_that.mediaStoreId,_that.fileName,_that.sizeBytes,_that.pending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int mediaStoreId,  String fileName,  int sizeBytes,  bool pending)  $default,) {final _that = this;
switch (_that) {
case _FolderRow():
return $default(_that.mediaStoreId,_that.fileName,_that.sizeBytes,_that.pending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int mediaStoreId,  String fileName,  int sizeBytes,  bool pending)?  $default,) {final _that = this;
switch (_that) {
case _FolderRow() when $default != null:
return $default(_that.mediaStoreId,_that.fileName,_that.sizeBytes,_that.pending);case _:
  return null;

}
}

}

/// @nodoc


class _FolderRow implements FolderRow {
  const _FolderRow({required this.mediaStoreId, required this.fileName, required this.sizeBytes, required this.pending});
  

@override final  int mediaStoreId;
@override final  String fileName;
@override final  int sizeBytes;
@override final  bool pending;

/// Create a copy of FolderRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FolderRowCopyWith<_FolderRow> get copyWith => __$FolderRowCopyWithImpl<_FolderRow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FolderRow&&(identical(other.mediaStoreId, mediaStoreId) || other.mediaStoreId == mediaStoreId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.pending, pending) || other.pending == pending));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mediaStoreId,fileName,sizeBytes,pending);
}

@override
String toString() {
    return 'FolderRow(mediaStoreId: $mediaStoreId, fileName: $fileName, sizeBytes: $sizeBytes, pending: $pending)';
}


}

/// @nodoc
abstract mixin class _$FolderRowCopyWith<$Res> implements $FolderRowCopyWith<$Res> {
  factory _$FolderRowCopyWith(_FolderRow value, $Res Function(_FolderRow) _then) = __$FolderRowCopyWithImpl;
@override @useResult
$Res call({
 int mediaStoreId, String fileName, int sizeBytes, bool pending
});




}
/// @nodoc
class __$FolderRowCopyWithImpl<$Res>
    implements _$FolderRowCopyWith<$Res> {
  __$FolderRowCopyWithImpl(this._self, this._then);

  final _FolderRow _self;
  final $Res Function(_FolderRow) _then;

/// Create a copy of FolderRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mediaStoreId = null,Object? fileName = null,Object? sizeBytes = null,Object? pending = null,}) {
  return _then(_FolderRow(
mediaStoreId: null == mediaStoreId ? _self.mediaStoreId : mediaStoreId // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
