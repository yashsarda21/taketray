// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vn_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VnSession {

 int get reelId; String get folderName; DateTime get createdAt;
/// Create a copy of VnSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VnSessionCopyWith<VnSession> get copyWith => _$VnSessionCopyWithImpl<VnSession>(this as VnSession, _$identity);

  /// Serializes this VnSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VnSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VnSession&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.folderName, _this.folderName) || other.folderName == _this.folderName)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VnSession;
  return Object.hash(runtimeType,_this.reelId,_this.folderName,_this.createdAt);
}

@override
String toString() {
  final _this = this as VnSession;
  return 'VnSession(reelId: ${_this.reelId}, folderName: ${_this.folderName}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $VnSessionCopyWith<$Res>  {
  factory $VnSessionCopyWith(VnSession value, $Res Function(VnSession) _then) = _$VnSessionCopyWithImpl;
@useResult
$Res call({
 int reelId, String folderName, DateTime createdAt
});




}
/// @nodoc
class _$VnSessionCopyWithImpl<$Res>
    implements $VnSessionCopyWith<$Res> {
  _$VnSessionCopyWithImpl(this._self, this._then);

  final VnSession _self;
  final $Res Function(VnSession) _then;

/// Create a copy of VnSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? folderName = null,Object? createdAt = null,}) {
  return _then(VnSession(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [VnSession].
extension VnSessionPatterns on VnSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VnSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VnSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VnSession value)  $default,){
final _that = this;
switch (_that) {
case _VnSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VnSession value)?  $default,){
final _that = this;
switch (_that) {
case _VnSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  String folderName,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VnSession() when $default != null:
return $default(_that.reelId,_that.folderName,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  String folderName,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _VnSession():
return $default(_that.reelId,_that.folderName,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  String folderName,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _VnSession() when $default != null:
return $default(_that.reelId,_that.folderName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VnSession implements VnSession {
  const _VnSession({required this.reelId, required this.folderName, required this.createdAt});
  factory _VnSession.fromJson(Map<String, dynamic> json) => _$VnSessionFromJson(json);

@override final  int reelId;
@override final  String folderName;
@override final  DateTime createdAt;

/// Create a copy of VnSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VnSessionCopyWith<_VnSession> get copyWith => __$VnSessionCopyWithImpl<_VnSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VnSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VnSession&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reelId,folderName,createdAt);
}

@override
String toString() {
    return 'VnSession(reelId: $reelId, folderName: $folderName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$VnSessionCopyWith<$Res> implements $VnSessionCopyWith<$Res> {
  factory _$VnSessionCopyWith(_VnSession value, $Res Function(_VnSession) _then) = __$VnSessionCopyWithImpl;
@override @useResult
$Res call({
 int reelId, String folderName, DateTime createdAt
});




}
/// @nodoc
class __$VnSessionCopyWithImpl<$Res>
    implements _$VnSessionCopyWith<$Res> {
  __$VnSessionCopyWithImpl(this._self, this._then);

  final _VnSession _self;
  final $Res Function(_VnSession) _then;

/// Create a copy of VnSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? folderName = null,Object? createdAt = null,}) {
  return _then(_VnSession(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
