// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reel_reference.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReelReference {

 int get id; int get reelId; String get url; ReferenceSource get source; DateTime get createdAt; String? get label;
/// Create a copy of ReelReference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReelReferenceCopyWith<ReelReference> get copyWith => _$ReelReferenceCopyWithImpl<ReelReference>(this as ReelReference, _$identity);

  /// Serializes this ReelReference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReelReference;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReelReference&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.label, _this.label) || other.label == _this.label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReelReference;
  return Object.hash(runtimeType,_this.id,_this.reelId,_this.url,_this.source,_this.createdAt,_this.label);
}

@override
String toString() {
  final _this = this as ReelReference;
  return 'ReelReference(id: ${_this.id}, reelId: ${_this.reelId}, url: ${_this.url}, source: ${_this.source}, createdAt: ${_this.createdAt}, label: ${_this.label})';
}


}

/// @nodoc
abstract mixin class $ReelReferenceCopyWith<$Res>  {
  factory $ReelReferenceCopyWith(ReelReference value, $Res Function(ReelReference) _then) = _$ReelReferenceCopyWithImpl;
@useResult
$Res call({
 int id, int reelId, String url, ReferenceSource source, DateTime createdAt, String? label
});




}
/// @nodoc
class _$ReelReferenceCopyWithImpl<$Res>
    implements $ReelReferenceCopyWith<$Res> {
  _$ReelReferenceCopyWithImpl(this._self, this._then);

  final ReelReference _self;
  final $Res Function(ReelReference) _then;

/// Create a copy of ReelReference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? reelId = null,Object? url = null,Object? source = null,Object? createdAt = null,Object? label = freezed,}) {
  return _then(ReelReference(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ReferenceSource,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReelReference].
extension ReelReferencePatterns on ReelReference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReelReference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReelReference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReelReference value)  $default,){
final _that = this;
switch (_that) {
case _ReelReference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReelReference value)?  $default,){
final _that = this;
switch (_that) {
case _ReelReference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int reelId,  String url,  ReferenceSource source,  DateTime createdAt,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReelReference() when $default != null:
return $default(_that.id,_that.reelId,_that.url,_that.source,_that.createdAt,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int reelId,  String url,  ReferenceSource source,  DateTime createdAt,  String? label)  $default,) {final _that = this;
switch (_that) {
case _ReelReference():
return $default(_that.id,_that.reelId,_that.url,_that.source,_that.createdAt,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int reelId,  String url,  ReferenceSource source,  DateTime createdAt,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _ReelReference() when $default != null:
return $default(_that.id,_that.reelId,_that.url,_that.source,_that.createdAt,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReelReference implements ReelReference {
  const _ReelReference({required this.id, required this.reelId, required this.url, required this.source, required this.createdAt, this.label});
  factory _ReelReference.fromJson(Map<String, dynamic> json) => _$ReelReferenceFromJson(json);

@override final  int id;
@override final  int reelId;
@override final  String url;
@override final  ReferenceSource source;
@override final  DateTime createdAt;
@override final  String? label;

/// Create a copy of ReelReference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReelReferenceCopyWith<_ReelReference> get copyWith => __$ReelReferenceCopyWithImpl<_ReelReference>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReelReferenceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReelReference&&(identical(other.id, id) || other.id == id)&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.url, url) || other.url == url)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,reelId,url,source,createdAt,label);
}

@override
String toString() {
    return 'ReelReference(id: $id, reelId: $reelId, url: $url, source: $source, createdAt: $createdAt, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ReelReferenceCopyWith<$Res> implements $ReelReferenceCopyWith<$Res> {
  factory _$ReelReferenceCopyWith(_ReelReference value, $Res Function(_ReelReference) _then) = __$ReelReferenceCopyWithImpl;
@override @useResult
$Res call({
 int id, int reelId, String url, ReferenceSource source, DateTime createdAt, String? label
});




}
/// @nodoc
class __$ReelReferenceCopyWithImpl<$Res>
    implements _$ReelReferenceCopyWith<$Res> {
  __$ReelReferenceCopyWithImpl(this._self, this._then);

  final _ReelReference _self;
  final $Res Function(_ReelReference) _then;

/// Create a copy of ReelReference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? reelId = null,Object? url = null,Object? source = null,Object? createdAt = null,Object? label = freezed,}) {
  return _then(_ReelReference(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ReferenceSource,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
