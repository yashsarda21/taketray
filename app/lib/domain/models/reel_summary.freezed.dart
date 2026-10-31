// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reel_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReelSummary {

 Reel get reel;/// Every clip in the reel, missing ones too.
 int get clipCount;/// The clips in the reel that are flagged missing.
 int get missingCount;/// The total length of the clips that are not missing, in milliseconds.
 int get liveDurationMs;/// The picture on the card: the oldest clip (by shooting time, ties by
/// id) that has a picture to show: a MediaStore clip that is not missing
/// and holds a MediaStore number above 0. Null when the reel has none.
 Clip? get cover;
/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReelSummaryCopyWith<ReelSummary> get copyWith => _$ReelSummaryCopyWithImpl<ReelSummary>(this as ReelSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReelSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReelSummary&&(identical(other.reel, _this.reel) || other.reel == _this.reel)&&(identical(other.clipCount, _this.clipCount) || other.clipCount == _this.clipCount)&&(identical(other.missingCount, _this.missingCount) || other.missingCount == _this.missingCount)&&(identical(other.liveDurationMs, _this.liveDurationMs) || other.liveDurationMs == _this.liveDurationMs)&&(identical(other.cover, _this.cover) || other.cover == _this.cover));
}


@override
int get hashCode {
  final _this = this as ReelSummary;
  return Object.hash(runtimeType,_this.reel,_this.clipCount,_this.missingCount,_this.liveDurationMs,_this.cover);
}

@override
String toString() {
  final _this = this as ReelSummary;
  return 'ReelSummary(reel: ${_this.reel}, clipCount: ${_this.clipCount}, missingCount: ${_this.missingCount}, liveDurationMs: ${_this.liveDurationMs}, cover: ${_this.cover})';
}


}

/// @nodoc
abstract mixin class $ReelSummaryCopyWith<$Res>  {
  factory $ReelSummaryCopyWith(ReelSummary value, $Res Function(ReelSummary) _then) = _$ReelSummaryCopyWithImpl;
@useResult
$Res call({
 Reel reel, int clipCount, int missingCount, int liveDurationMs, Clip? cover
});


$ReelCopyWith<$Res> get reel;$ClipCopyWith<$Res>? get cover;

}
/// @nodoc
class _$ReelSummaryCopyWithImpl<$Res>
    implements $ReelSummaryCopyWith<$Res> {
  _$ReelSummaryCopyWithImpl(this._self, this._then);

  final ReelSummary _self;
  final $Res Function(ReelSummary) _then;

/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reel = null,Object? clipCount = null,Object? missingCount = null,Object? liveDurationMs = null,Object? cover = freezed,}) {
  return _then(ReelSummary(
reel: null == reel ? _self.reel : reel // ignore: cast_nullable_to_non_nullable
as Reel,clipCount: null == clipCount ? _self.clipCount : clipCount // ignore: cast_nullable_to_non_nullable
as int,missingCount: null == missingCount ? _self.missingCount : missingCount // ignore: cast_nullable_to_non_nullable
as int,liveDurationMs: null == liveDurationMs ? _self.liveDurationMs : liveDurationMs // ignore: cast_nullable_to_non_nullable
as int,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as Clip?,
  ));
}
/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReelCopyWith<$Res> get reel {
  
  return $ReelCopyWith<$Res>(_self.reel, (value) {
    return _then(_self.copyWith(reel: value));
  });
}/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipCopyWith<$Res>? get cover {
    if (_self.cover == null) {
    return null;
  }

  return $ClipCopyWith<$Res>(_self.cover!, (value) {
    return _then(_self.copyWith(cover: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReelSummary].
extension ReelSummaryPatterns on ReelSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReelSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReelSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReelSummary value)  $default,){
final _that = this;
switch (_that) {
case _ReelSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReelSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ReelSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Reel reel,  int clipCount,  int missingCount,  int liveDurationMs,  Clip? cover)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReelSummary() when $default != null:
return $default(_that.reel,_that.clipCount,_that.missingCount,_that.liveDurationMs,_that.cover);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Reel reel,  int clipCount,  int missingCount,  int liveDurationMs,  Clip? cover)  $default,) {final _that = this;
switch (_that) {
case _ReelSummary():
return $default(_that.reel,_that.clipCount,_that.missingCount,_that.liveDurationMs,_that.cover);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Reel reel,  int clipCount,  int missingCount,  int liveDurationMs,  Clip? cover)?  $default,) {final _that = this;
switch (_that) {
case _ReelSummary() when $default != null:
return $default(_that.reel,_that.clipCount,_that.missingCount,_that.liveDurationMs,_that.cover);case _:
  return null;

}
}

}

/// @nodoc


class _ReelSummary implements ReelSummary {
  const _ReelSummary({required this.reel, required this.clipCount, required this.missingCount, required this.liveDurationMs, this.cover});
  

@override final  Reel reel;
/// Every clip in the reel, missing ones too.
@override final  int clipCount;
/// The clips in the reel that are flagged missing.
@override final  int missingCount;
/// The total length of the clips that are not missing, in milliseconds.
@override final  int liveDurationMs;
/// The picture on the card: the oldest clip (by shooting time, ties by
/// id) that has a picture to show: a MediaStore clip that is not missing
/// and holds a MediaStore number above 0. Null when the reel has none.
@override final  Clip? cover;

/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReelSummaryCopyWith<_ReelSummary> get copyWith => __$ReelSummaryCopyWithImpl<_ReelSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReelSummary&&(identical(other.reel, reel) || other.reel == reel)&&(identical(other.clipCount, clipCount) || other.clipCount == clipCount)&&(identical(other.missingCount, missingCount) || other.missingCount == missingCount)&&(identical(other.liveDurationMs, liveDurationMs) || other.liveDurationMs == liveDurationMs)&&(identical(other.cover, cover) || other.cover == cover));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reel,clipCount,missingCount,liveDurationMs,cover);
}

@override
String toString() {
    return 'ReelSummary(reel: $reel, clipCount: $clipCount, missingCount: $missingCount, liveDurationMs: $liveDurationMs, cover: $cover)';
}


}

/// @nodoc
abstract mixin class _$ReelSummaryCopyWith<$Res> implements $ReelSummaryCopyWith<$Res> {
  factory _$ReelSummaryCopyWith(_ReelSummary value, $Res Function(_ReelSummary) _then) = __$ReelSummaryCopyWithImpl;
@override @useResult
$Res call({
 Reel reel, int clipCount, int missingCount, int liveDurationMs, Clip? cover
});


@override $ReelCopyWith<$Res> get reel;@override $ClipCopyWith<$Res>? get cover;

}
/// @nodoc
class __$ReelSummaryCopyWithImpl<$Res>
    implements _$ReelSummaryCopyWith<$Res> {
  __$ReelSummaryCopyWithImpl(this._self, this._then);

  final _ReelSummary _self;
  final $Res Function(_ReelSummary) _then;

/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reel = null,Object? clipCount = null,Object? missingCount = null,Object? liveDurationMs = null,Object? cover = freezed,}) {
  return _then(_ReelSummary(
reel: null == reel ? _self.reel : reel // ignore: cast_nullable_to_non_nullable
as Reel,clipCount: null == clipCount ? _self.clipCount : clipCount // ignore: cast_nullable_to_non_nullable
as int,missingCount: null == missingCount ? _self.missingCount : missingCount // ignore: cast_nullable_to_non_nullable
as int,liveDurationMs: null == liveDurationMs ? _self.liveDurationMs : liveDurationMs // ignore: cast_nullable_to_non_nullable
as int,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as Clip?,
  ));
}

/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReelCopyWith<$Res> get reel {
  
  return $ReelCopyWith<$Res>(_self.reel, (value) {
    return _then(_self.copyWith(reel: value));
  });
}/// Create a copy of ReelSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClipCopyWith<$Res>? get cover {
    if (_self.cover == null) {
    return null;
  }

  return $ClipCopyWith<$Res>(_self.cover!, (value) {
    return _then(_self.copyWith(cover: value));
  });
}
}

// dart format on
