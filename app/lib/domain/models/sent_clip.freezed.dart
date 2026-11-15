// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sent_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SentClip {

 int get reelId; int get clipId; DateTime get sentAt;
/// Create a copy of SentClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SentClipCopyWith<SentClip> get copyWith => _$SentClipCopyWithImpl<SentClip>(this as SentClip, _$identity);

  /// Serializes this SentClip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SentClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SentClip&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.clipId, _this.clipId) || other.clipId == _this.clipId)&&(identical(other.sentAt, _this.sentAt) || other.sentAt == _this.sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SentClip;
  return Object.hash(runtimeType,_this.reelId,_this.clipId,_this.sentAt);
}

@override
String toString() {
  final _this = this as SentClip;
  return 'SentClip(reelId: ${_this.reelId}, clipId: ${_this.clipId}, sentAt: ${_this.sentAt})';
}


}

/// @nodoc
abstract mixin class $SentClipCopyWith<$Res>  {
  factory $SentClipCopyWith(SentClip value, $Res Function(SentClip) _then) = _$SentClipCopyWithImpl;
@useResult
$Res call({
 int reelId, int clipId, DateTime sentAt
});




}
/// @nodoc
class _$SentClipCopyWithImpl<$Res>
    implements $SentClipCopyWith<$Res> {
  _$SentClipCopyWithImpl(this._self, this._then);

  final SentClip _self;
  final $Res Function(SentClip) _then;

/// Create a copy of SentClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? clipId = null,Object? sentAt = null,}) {
  return _then(SentClip(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SentClip].
extension SentClipPatterns on SentClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SentClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SentClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SentClip value)  $default,){
final _that = this;
switch (_that) {
case _SentClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SentClip value)?  $default,){
final _that = this;
switch (_that) {
case _SentClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  int clipId,  DateTime sentAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SentClip() when $default != null:
return $default(_that.reelId,_that.clipId,_that.sentAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  int clipId,  DateTime sentAt)  $default,) {final _that = this;
switch (_that) {
case _SentClip():
return $default(_that.reelId,_that.clipId,_that.sentAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  int clipId,  DateTime sentAt)?  $default,) {final _that = this;
switch (_that) {
case _SentClip() when $default != null:
return $default(_that.reelId,_that.clipId,_that.sentAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SentClip implements SentClip {
  const _SentClip({required this.reelId, required this.clipId, required this.sentAt});
  factory _SentClip.fromJson(Map<String, dynamic> json) => _$SentClipFromJson(json);

@override final  int reelId;
@override final  int clipId;
@override final  DateTime sentAt;

/// Create a copy of SentClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SentClipCopyWith<_SentClip> get copyWith => __$SentClipCopyWithImpl<_SentClip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SentClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SentClip&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.clipId, clipId) || other.clipId == clipId)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reelId,clipId,sentAt);
}

@override
String toString() {
    return 'SentClip(reelId: $reelId, clipId: $clipId, sentAt: $sentAt)';
}


}

/// @nodoc
abstract mixin class _$SentClipCopyWith<$Res> implements $SentClipCopyWith<$Res> {
  factory _$SentClipCopyWith(_SentClip value, $Res Function(_SentClip) _then) = __$SentClipCopyWithImpl;
@override @useResult
$Res call({
 int reelId, int clipId, DateTime sentAt
});




}
/// @nodoc
class __$SentClipCopyWithImpl<$Res>
    implements _$SentClipCopyWith<$Res> {
  __$SentClipCopyWithImpl(this._self, this._then);

  final _SentClip _self;
  final $Res Function(_SentClip) _then;

/// Create a copy of SentClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? clipId = null,Object? sentAt = null,}) {
  return _then(_SentClip(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,clipId: null == clipId ? _self.clipId : clipId // ignore: cast_nullable_to_non_nullable
as int,sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
