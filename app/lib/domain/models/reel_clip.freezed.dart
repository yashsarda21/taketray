// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reel_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReelClip {

 Clip get clip;/// How many reels the clip is in, this one included (the "in N reels"
/// badge shows when it is 2 or more).
 int get reelCount;/// When the clip joined this reel.
 DateTime get addedAt;
/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReelClipCopyWith<ReelClip> get copyWith => _$ReelClipCopyWithImpl<ReelClip>(this as ReelClip, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReelClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReelClip&&(identical(other.clip, _this.clip) || other.clip == _this.clip)&&(identical(other.reelCount, _this.reelCount) || other.reelCount == _this.reelCount)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt));
}


@override
int get hashCode {
  final _this = this as ReelClip;
  return Object.hash(runtimeType,_this.clip,_this.reelCount,_this.addedAt);
}

@override
String toString() {
  final _this = this as ReelClip;
  return 'ReelClip(clip: ${_this.clip}, reelCount: ${_this.reelCount}, addedAt: ${_this.addedAt})';
}


}

/// @nodoc
abstract mixin class $ReelClipCopyWith<$Res>  {
  factory $ReelClipCopyWith(ReelClip value, $Res Function(ReelClip) _then) = _$ReelClipCopyWithImpl;
@useResult
$Res call({
 Clip clip, int reelCount, DateTime addedAt
});


$ClipCopyWith<$Res> get clip;

}
/// @nodoc
class _$ReelClipCopyWithImpl<$Res>
    implements $ReelClipCopyWith<$Res> {
  _$ReelClipCopyWithImpl(this._self, this._then);

  final ReelClip _self;
  final $Res Function(ReelClip) _then;

/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clip = null,Object? reelCount = null,Object? addedAt = null,}) {
  return _then(ReelClip(
clip: null == clip ? _self.clip : clip // ignore: cast_nullable_to_non_nullable
as Clip,reelCount: null == reelCount ? _self.reelCount : reelCount // ignore: cast_nullable_to_non_nullable
as int,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipCopyWith<$Res> get clip {
  
  return $ClipCopyWith<$Res>(_self.clip, (value) {
    return _then(_self.copyWith(clip: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReelClip].
extension ReelClipPatterns on ReelClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReelClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReelClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReelClip value)  $default,){
final _that = this;
switch (_that) {
case _ReelClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReelClip value)?  $default,){
final _that = this;
switch (_that) {
case _ReelClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Clip clip,  int reelCount,  DateTime addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReelClip() when $default != null:
return $default(_that.clip,_that.reelCount,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Clip clip,  int reelCount,  DateTime addedAt)  $default,) {final _that = this;
switch (_that) {
case _ReelClip():
return $default(_that.clip,_that.reelCount,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Clip clip,  int reelCount,  DateTime addedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReelClip() when $default != null:
return $default(_that.clip,_that.reelCount,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ReelClip implements ReelClip {
  const _ReelClip({required this.clip, required this.reelCount, required this.addedAt});
  

@override final  Clip clip;
/// How many reels the clip is in, this one included (the "in N reels"
/// badge shows when it is 2 or more).
@override final  int reelCount;
/// When the clip joined this reel.
@override final  DateTime addedAt;

/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReelClipCopyWith<_ReelClip> get copyWith => __$ReelClipCopyWithImpl<_ReelClip>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReelClip&&(identical(other.clip, clip) || other.clip == clip)&&(identical(other.reelCount, reelCount) || other.reelCount == reelCount)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,clip,reelCount,addedAt);
}

@override
String toString() {
    return 'ReelClip(clip: $clip, reelCount: $reelCount, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$ReelClipCopyWith<$Res> implements $ReelClipCopyWith<$Res> {
  factory _$ReelClipCopyWith(_ReelClip value, $Res Function(_ReelClip) _then) = __$ReelClipCopyWithImpl;
@override @useResult
$Res call({
 Clip clip, int reelCount, DateTime addedAt
});


@override $ClipCopyWith<$Res> get clip;

}
/// @nodoc
class __$ReelClipCopyWithImpl<$Res>
    implements _$ReelClipCopyWith<$Res> {
  __$ReelClipCopyWithImpl(this._self, this._then);

  final _ReelClip _self;
  final $Res Function(_ReelClip) _then;

/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clip = null,Object? reelCount = null,Object? addedAt = null,}) {
  return _then(_ReelClip(
clip: null == clip ? _self.clip : clip // ignore: cast_nullable_to_non_nullable
as Clip,reelCount: null == reelCount ? _self.reelCount : reelCount // ignore: cast_nullable_to_non_nullable
as int,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of ReelClip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipCopyWith<$Res> get clip {
  
  return $ClipCopyWith<$Res>(_self.clip, (value) {
    return _then(_self.copyWith(clip: value));
  });
}
}

// dart format on
