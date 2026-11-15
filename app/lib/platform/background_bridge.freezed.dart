// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'background_bridge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BackgroundState {

 bool get shootingOn; DateTime? get since; Map<String, VolumeBaseline> get baselines; List<String> get watchedFolders; List<DateTime> get waitingShots; bool get eveningEnabled; int get eveningMinutes; bool get stillReminderEnabled; bool get stillAnswered; List<CopiesReminder> get copiesReminders;
/// Create a copy of BackgroundState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackgroundStateCopyWith<BackgroundState> get copyWith => _$BackgroundStateCopyWithImpl<BackgroundState>(this as BackgroundState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BackgroundState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackgroundState&&(identical(other.shootingOn, _this.shootingOn) || other.shootingOn == _this.shootingOn)&&(identical(other.since, _this.since) || other.since == _this.since)&&const DeepCollectionEquality().equals(other.baselines, _this.baselines)&&const DeepCollectionEquality().equals(other.watchedFolders, _this.watchedFolders)&&const DeepCollectionEquality().equals(other.waitingShots, _this.waitingShots)&&(identical(other.eveningEnabled, _this.eveningEnabled) || other.eveningEnabled == _this.eveningEnabled)&&(identical(other.eveningMinutes, _this.eveningMinutes) || other.eveningMinutes == _this.eveningMinutes)&&(identical(other.stillReminderEnabled, _this.stillReminderEnabled) || other.stillReminderEnabled == _this.stillReminderEnabled)&&(identical(other.stillAnswered, _this.stillAnswered) || other.stillAnswered == _this.stillAnswered)&&const DeepCollectionEquality().equals(other.copiesReminders, _this.copiesReminders));
}


@override
int get hashCode {
  final _this = this as BackgroundState;
  return Object.hash(runtimeType,_this.shootingOn,_this.since,const DeepCollectionEquality().hash(_this.baselines),const DeepCollectionEquality().hash(_this.watchedFolders),const DeepCollectionEquality().hash(_this.waitingShots),_this.eveningEnabled,_this.eveningMinutes,_this.stillReminderEnabled,_this.stillAnswered,const DeepCollectionEquality().hash(_this.copiesReminders));
}

@override
String toString() {
  final _this = this as BackgroundState;
  return 'BackgroundState(shootingOn: ${_this.shootingOn}, since: ${_this.since}, baselines: ${_this.baselines}, watchedFolders: ${_this.watchedFolders}, waitingShots: ${_this.waitingShots}, eveningEnabled: ${_this.eveningEnabled}, eveningMinutes: ${_this.eveningMinutes}, stillReminderEnabled: ${_this.stillReminderEnabled}, stillAnswered: ${_this.stillAnswered}, copiesReminders: ${_this.copiesReminders})';
}


}

/// @nodoc
abstract mixin class $BackgroundStateCopyWith<$Res>  {
  factory $BackgroundStateCopyWith(BackgroundState value, $Res Function(BackgroundState) _then) = _$BackgroundStateCopyWithImpl;
@useResult
$Res call({
 bool shootingOn, DateTime? since, Map<String, VolumeBaseline> baselines, List<String> watchedFolders, List<DateTime> waitingShots, bool eveningEnabled, int eveningMinutes, bool stillReminderEnabled, bool stillAnswered, List<CopiesReminder> copiesReminders
});




}
/// @nodoc
class _$BackgroundStateCopyWithImpl<$Res>
    implements $BackgroundStateCopyWith<$Res> {
  _$BackgroundStateCopyWithImpl(this._self, this._then);

  final BackgroundState _self;
  final $Res Function(BackgroundState) _then;

/// Create a copy of BackgroundState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shootingOn = null,Object? since = freezed,Object? baselines = null,Object? watchedFolders = null,Object? waitingShots = null,Object? eveningEnabled = null,Object? eveningMinutes = null,Object? stillReminderEnabled = null,Object? stillAnswered = null,Object? copiesReminders = null,}) {
  return _then(BackgroundState(
shootingOn: null == shootingOn ? _self.shootingOn : shootingOn // ignore: cast_nullable_to_non_nullable
as bool,since: freezed == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime?,baselines: null == baselines ? _self.baselines : baselines // ignore: cast_nullable_to_non_nullable
as Map<String, VolumeBaseline>,watchedFolders: null == watchedFolders ? _self.watchedFolders : watchedFolders // ignore: cast_nullable_to_non_nullable
as List<String>,waitingShots: null == waitingShots ? _self.waitingShots : waitingShots // ignore: cast_nullable_to_non_nullable
as List<DateTime>,eveningEnabled: null == eveningEnabled ? _self.eveningEnabled : eveningEnabled // ignore: cast_nullable_to_non_nullable
as bool,eveningMinutes: null == eveningMinutes ? _self.eveningMinutes : eveningMinutes // ignore: cast_nullable_to_non_nullable
as int,stillReminderEnabled: null == stillReminderEnabled ? _self.stillReminderEnabled : stillReminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,stillAnswered: null == stillAnswered ? _self.stillAnswered : stillAnswered // ignore: cast_nullable_to_non_nullable
as bool,copiesReminders: null == copiesReminders ? _self.copiesReminders : copiesReminders // ignore: cast_nullable_to_non_nullable
as List<CopiesReminder>,
  ));
}

}


/// Adds pattern-matching-related methods to [BackgroundState].
extension BackgroundStatePatterns on BackgroundState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackgroundState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackgroundState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackgroundState value)  $default,){
final _that = this;
switch (_that) {
case _BackgroundState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackgroundState value)?  $default,){
final _that = this;
switch (_that) {
case _BackgroundState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool shootingOn,  DateTime? since,  Map<String, VolumeBaseline> baselines,  List<String> watchedFolders,  List<DateTime> waitingShots,  bool eveningEnabled,  int eveningMinutes,  bool stillReminderEnabled,  bool stillAnswered,  List<CopiesReminder> copiesReminders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BackgroundState() when $default != null:
return $default(_that.shootingOn,_that.since,_that.baselines,_that.watchedFolders,_that.waitingShots,_that.eveningEnabled,_that.eveningMinutes,_that.stillReminderEnabled,_that.stillAnswered,_that.copiesReminders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool shootingOn,  DateTime? since,  Map<String, VolumeBaseline> baselines,  List<String> watchedFolders,  List<DateTime> waitingShots,  bool eveningEnabled,  int eveningMinutes,  bool stillReminderEnabled,  bool stillAnswered,  List<CopiesReminder> copiesReminders)  $default,) {final _that = this;
switch (_that) {
case _BackgroundState():
return $default(_that.shootingOn,_that.since,_that.baselines,_that.watchedFolders,_that.waitingShots,_that.eveningEnabled,_that.eveningMinutes,_that.stillReminderEnabled,_that.stillAnswered,_that.copiesReminders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool shootingOn,  DateTime? since,  Map<String, VolumeBaseline> baselines,  List<String> watchedFolders,  List<DateTime> waitingShots,  bool eveningEnabled,  int eveningMinutes,  bool stillReminderEnabled,  bool stillAnswered,  List<CopiesReminder> copiesReminders)?  $default,) {final _that = this;
switch (_that) {
case _BackgroundState() when $default != null:
return $default(_that.shootingOn,_that.since,_that.baselines,_that.watchedFolders,_that.waitingShots,_that.eveningEnabled,_that.eveningMinutes,_that.stillReminderEnabled,_that.stillAnswered,_that.copiesReminders);case _:
  return null;

}
}

}

/// @nodoc


class _BackgroundState implements BackgroundState {
  const _BackgroundState({required this.shootingOn, required this.since, required  Map<String, VolumeBaseline> baselines, required  List<String> watchedFolders, required  List<DateTime> waitingShots, required this.eveningEnabled, required this.eveningMinutes, required this.stillReminderEnabled, required this.stillAnswered,  List<CopiesReminder> copiesReminders = const <CopiesReminder>[]}): _baselines = baselines,_watchedFolders = watchedFolders,_waitingShots = waitingShots,_copiesReminders = copiesReminders;
  

@override final  bool shootingOn;
@override final  DateTime? since;
 final  Map<String, VolumeBaseline> _baselines;
@override Map<String, VolumeBaseline> get baselines {
  if (_baselines is EqualUnmodifiableMapView) return _baselines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_baselines);
}

 final  List<String> _watchedFolders;
@override List<String> get watchedFolders {
  if (_watchedFolders is EqualUnmodifiableListView) return _watchedFolders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_watchedFolders);
}

 final  List<DateTime> _waitingShots;
@override List<DateTime> get waitingShots {
  if (_waitingShots is EqualUnmodifiableListView) return _waitingShots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_waitingShots);
}

@override final  bool eveningEnabled;
@override final  int eveningMinutes;
@override final  bool stillReminderEnabled;
@override final  bool stillAnswered;
 final  List<CopiesReminder> _copiesReminders;
@override@JsonKey() List<CopiesReminder> get copiesReminders {
  if (_copiesReminders is EqualUnmodifiableListView) return _copiesReminders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_copiesReminders);
}


/// Create a copy of BackgroundState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackgroundStateCopyWith<_BackgroundState> get copyWith => __$BackgroundStateCopyWithImpl<_BackgroundState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackgroundState&&(identical(other.shootingOn, shootingOn) || other.shootingOn == shootingOn)&&(identical(other.since, since) || other.since == since)&&const DeepCollectionEquality().equals(other.baselines, _baselines)&&const DeepCollectionEquality().equals(other.watchedFolders, _watchedFolders)&&const DeepCollectionEquality().equals(other.waitingShots, _waitingShots)&&(identical(other.eveningEnabled, eveningEnabled) || other.eveningEnabled == eveningEnabled)&&(identical(other.eveningMinutes, eveningMinutes) || other.eveningMinutes == eveningMinutes)&&(identical(other.stillReminderEnabled, stillReminderEnabled) || other.stillReminderEnabled == stillReminderEnabled)&&(identical(other.stillAnswered, stillAnswered) || other.stillAnswered == stillAnswered)&&const DeepCollectionEquality().equals(other.copiesReminders, _copiesReminders));
}


@override
int get hashCode {
    return Object.hash(runtimeType,shootingOn,since,const DeepCollectionEquality().hash(_baselines),const DeepCollectionEquality().hash(_watchedFolders),const DeepCollectionEquality().hash(_waitingShots),eveningEnabled,eveningMinutes,stillReminderEnabled,stillAnswered,const DeepCollectionEquality().hash(_copiesReminders));
}

@override
String toString() {
    return 'BackgroundState(shootingOn: $shootingOn, since: $since, baselines: $baselines, watchedFolders: $watchedFolders, waitingShots: $waitingShots, eveningEnabled: $eveningEnabled, eveningMinutes: $eveningMinutes, stillReminderEnabled: $stillReminderEnabled, stillAnswered: $stillAnswered, copiesReminders: $copiesReminders)';
}


}

/// @nodoc
abstract mixin class _$BackgroundStateCopyWith<$Res> implements $BackgroundStateCopyWith<$Res> {
  factory _$BackgroundStateCopyWith(_BackgroundState value, $Res Function(_BackgroundState) _then) = __$BackgroundStateCopyWithImpl;
@override @useResult
$Res call({
 bool shootingOn, DateTime? since, Map<String, VolumeBaseline> baselines, List<String> watchedFolders, List<DateTime> waitingShots, bool eveningEnabled, int eveningMinutes, bool stillReminderEnabled, bool stillAnswered, List<CopiesReminder> copiesReminders
});




}
/// @nodoc
class __$BackgroundStateCopyWithImpl<$Res>
    implements _$BackgroundStateCopyWith<$Res> {
  __$BackgroundStateCopyWithImpl(this._self, this._then);

  final _BackgroundState _self;
  final $Res Function(_BackgroundState) _then;

/// Create a copy of BackgroundState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shootingOn = null,Object? since = freezed,Object? baselines = null,Object? watchedFolders = null,Object? waitingShots = null,Object? eveningEnabled = null,Object? eveningMinutes = null,Object? stillReminderEnabled = null,Object? stillAnswered = null,Object? copiesReminders = null,}) {
  return _then(_BackgroundState(
shootingOn: null == shootingOn ? _self.shootingOn : shootingOn // ignore: cast_nullable_to_non_nullable
as bool,since: freezed == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime?,baselines: null == baselines ? _self._baselines : baselines // ignore: cast_nullable_to_non_nullable
as Map<String, VolumeBaseline>,watchedFolders: null == watchedFolders ? _self._watchedFolders : watchedFolders // ignore: cast_nullable_to_non_nullable
as List<String>,waitingShots: null == waitingShots ? _self._waitingShots : waitingShots // ignore: cast_nullable_to_non_nullable
as List<DateTime>,eveningEnabled: null == eveningEnabled ? _self.eveningEnabled : eveningEnabled // ignore: cast_nullable_to_non_nullable
as bool,eveningMinutes: null == eveningMinutes ? _self.eveningMinutes : eveningMinutes // ignore: cast_nullable_to_non_nullable
as int,stillReminderEnabled: null == stillReminderEnabled ? _self.stillReminderEnabled : stillReminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,stillAnswered: null == stillAnswered ? _self.stillAnswered : stillAnswered // ignore: cast_nullable_to_non_nullable
as bool,copiesReminders: null == copiesReminders ? _self._copiesReminders : copiesReminders // ignore: cast_nullable_to_non_nullable
as List<CopiesReminder>,
  ));
}


}

/// @nodoc
mixin _$CopiesReminder {

 int get reelId; String get reelName; int get copyBytes; DateTime get lastCopiedAt;
/// Create a copy of CopiesReminder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopiesReminderCopyWith<CopiesReminder> get copyWith => _$CopiesReminderCopyWithImpl<CopiesReminder>(this as CopiesReminder, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CopiesReminder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopiesReminder&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.reelName, _this.reelName) || other.reelName == _this.reelName)&&(identical(other.copyBytes, _this.copyBytes) || other.copyBytes == _this.copyBytes)&&(identical(other.lastCopiedAt, _this.lastCopiedAt) || other.lastCopiedAt == _this.lastCopiedAt));
}


@override
int get hashCode {
  final _this = this as CopiesReminder;
  return Object.hash(runtimeType,_this.reelId,_this.reelName,_this.copyBytes,_this.lastCopiedAt);
}

@override
String toString() {
  final _this = this as CopiesReminder;
  return 'CopiesReminder(reelId: ${_this.reelId}, reelName: ${_this.reelName}, copyBytes: ${_this.copyBytes}, lastCopiedAt: ${_this.lastCopiedAt})';
}


}

/// @nodoc
abstract mixin class $CopiesReminderCopyWith<$Res>  {
  factory $CopiesReminderCopyWith(CopiesReminder value, $Res Function(CopiesReminder) _then) = _$CopiesReminderCopyWithImpl;
@useResult
$Res call({
 int reelId, String reelName, int copyBytes, DateTime lastCopiedAt
});




}
/// @nodoc
class _$CopiesReminderCopyWithImpl<$Res>
    implements $CopiesReminderCopyWith<$Res> {
  _$CopiesReminderCopyWithImpl(this._self, this._then);

  final CopiesReminder _self;
  final $Res Function(CopiesReminder) _then;

/// Create a copy of CopiesReminder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? reelName = null,Object? copyBytes = null,Object? lastCopiedAt = null,}) {
  return _then(CopiesReminder(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,reelName: null == reelName ? _self.reelName : reelName // ignore: cast_nullable_to_non_nullable
as String,copyBytes: null == copyBytes ? _self.copyBytes : copyBytes // ignore: cast_nullable_to_non_nullable
as int,lastCopiedAt: null == lastCopiedAt ? _self.lastCopiedAt : lastCopiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CopiesReminder].
extension CopiesReminderPatterns on CopiesReminder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopiesReminder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopiesReminder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopiesReminder value)  $default,){
final _that = this;
switch (_that) {
case _CopiesReminder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopiesReminder value)?  $default,){
final _that = this;
switch (_that) {
case _CopiesReminder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  String reelName,  int copyBytes,  DateTime lastCopiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopiesReminder() when $default != null:
return $default(_that.reelId,_that.reelName,_that.copyBytes,_that.lastCopiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  String reelName,  int copyBytes,  DateTime lastCopiedAt)  $default,) {final _that = this;
switch (_that) {
case _CopiesReminder():
return $default(_that.reelId,_that.reelName,_that.copyBytes,_that.lastCopiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  String reelName,  int copyBytes,  DateTime lastCopiedAt)?  $default,) {final _that = this;
switch (_that) {
case _CopiesReminder() when $default != null:
return $default(_that.reelId,_that.reelName,_that.copyBytes,_that.lastCopiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _CopiesReminder implements CopiesReminder {
  const _CopiesReminder({required this.reelId, required this.reelName, required this.copyBytes, required this.lastCopiedAt});
  

@override final  int reelId;
@override final  String reelName;
@override final  int copyBytes;
@override final  DateTime lastCopiedAt;

/// Create a copy of CopiesReminder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopiesReminderCopyWith<_CopiesReminder> get copyWith => __$CopiesReminderCopyWithImpl<_CopiesReminder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopiesReminder&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.reelName, reelName) || other.reelName == reelName)&&(identical(other.copyBytes, copyBytes) || other.copyBytes == copyBytes)&&(identical(other.lastCopiedAt, lastCopiedAt) || other.lastCopiedAt == lastCopiedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reelId,reelName,copyBytes,lastCopiedAt);
}

@override
String toString() {
    return 'CopiesReminder(reelId: $reelId, reelName: $reelName, copyBytes: $copyBytes, lastCopiedAt: $lastCopiedAt)';
}


}

/// @nodoc
abstract mixin class _$CopiesReminderCopyWith<$Res> implements $CopiesReminderCopyWith<$Res> {
  factory _$CopiesReminderCopyWith(_CopiesReminder value, $Res Function(_CopiesReminder) _then) = __$CopiesReminderCopyWithImpl;
@override @useResult
$Res call({
 int reelId, String reelName, int copyBytes, DateTime lastCopiedAt
});




}
/// @nodoc
class __$CopiesReminderCopyWithImpl<$Res>
    implements _$CopiesReminderCopyWith<$Res> {
  __$CopiesReminderCopyWithImpl(this._self, this._then);

  final _CopiesReminder _self;
  final $Res Function(_CopiesReminder) _then;

/// Create a copy of CopiesReminder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? reelName = null,Object? copyBytes = null,Object? lastCopiedAt = null,}) {
  return _then(_CopiesReminder(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,reelName: null == reelName ? _self.reelName : reelName // ignore: cast_nullable_to_non_nullable
as String,copyBytes: null == copyBytes ? _self.copyBytes : copyBytes // ignore: cast_nullable_to_non_nullable
as int,lastCopiedAt: null == lastCopiedAt ? _self.lastCopiedAt : lastCopiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$ShadeAction {

 ShadeActionKind get kind; DateTime get since; DateTime get at; Map<String, int> get generations;
/// Create a copy of ShadeAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShadeActionCopyWith<ShadeAction> get copyWith => _$ShadeActionCopyWithImpl<ShadeAction>(this as ShadeAction, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShadeAction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShadeAction&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.since, _this.since) || other.since == _this.since)&&(identical(other.at, _this.at) || other.at == _this.at)&&const DeepCollectionEquality().equals(other.generations, _this.generations));
}


@override
int get hashCode {
  final _this = this as ShadeAction;
  return Object.hash(runtimeType,_this.kind,_this.since,_this.at,const DeepCollectionEquality().hash(_this.generations));
}

@override
String toString() {
  final _this = this as ShadeAction;
  return 'ShadeAction(kind: ${_this.kind}, since: ${_this.since}, at: ${_this.at}, generations: ${_this.generations})';
}


}

/// @nodoc
abstract mixin class $ShadeActionCopyWith<$Res>  {
  factory $ShadeActionCopyWith(ShadeAction value, $Res Function(ShadeAction) _then) = _$ShadeActionCopyWithImpl;
@useResult
$Res call({
 ShadeActionKind kind, DateTime since, DateTime at, Map<String, int> generations
});




}
/// @nodoc
class _$ShadeActionCopyWithImpl<$Res>
    implements $ShadeActionCopyWith<$Res> {
  _$ShadeActionCopyWithImpl(this._self, this._then);

  final ShadeAction _self;
  final $Res Function(ShadeAction) _then;

/// Create a copy of ShadeAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? since = null,Object? at = null,Object? generations = null,}) {
  return _then(ShadeAction(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShadeActionKind,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,generations: null == generations ? _self.generations : generations // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ShadeAction].
extension ShadeActionPatterns on ShadeAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShadeAction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShadeAction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShadeAction value)  $default,){
final _that = this;
switch (_that) {
case _ShadeAction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShadeAction value)?  $default,){
final _that = this;
switch (_that) {
case _ShadeAction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ShadeActionKind kind,  DateTime since,  DateTime at,  Map<String, int> generations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShadeAction() when $default != null:
return $default(_that.kind,_that.since,_that.at,_that.generations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ShadeActionKind kind,  DateTime since,  DateTime at,  Map<String, int> generations)  $default,) {final _that = this;
switch (_that) {
case _ShadeAction():
return $default(_that.kind,_that.since,_that.at,_that.generations);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ShadeActionKind kind,  DateTime since,  DateTime at,  Map<String, int> generations)?  $default,) {final _that = this;
switch (_that) {
case _ShadeAction() when $default != null:
return $default(_that.kind,_that.since,_that.at,_that.generations);case _:
  return null;

}
}

}

/// @nodoc


class _ShadeAction implements ShadeAction {
  const _ShadeAction({required this.kind, required this.since, required this.at, required  Map<String, int> generations}): _generations = generations;
  

@override final  ShadeActionKind kind;
@override final  DateTime since;
@override final  DateTime at;
 final  Map<String, int> _generations;
@override Map<String, int> get generations {
  if (_generations is EqualUnmodifiableMapView) return _generations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_generations);
}


/// Create a copy of ShadeAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShadeActionCopyWith<_ShadeAction> get copyWith => __$ShadeActionCopyWithImpl<_ShadeAction>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShadeAction&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.since, since) || other.since == since)&&(identical(other.at, at) || other.at == at)&&const DeepCollectionEquality().equals(other.generations, _generations));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,since,at,const DeepCollectionEquality().hash(_generations));
}

@override
String toString() {
    return 'ShadeAction(kind: $kind, since: $since, at: $at, generations: $generations)';
}


}

/// @nodoc
abstract mixin class _$ShadeActionCopyWith<$Res> implements $ShadeActionCopyWith<$Res> {
  factory _$ShadeActionCopyWith(_ShadeAction value, $Res Function(_ShadeAction) _then) = __$ShadeActionCopyWithImpl;
@override @useResult
$Res call({
 ShadeActionKind kind, DateTime since, DateTime at, Map<String, int> generations
});




}
/// @nodoc
class __$ShadeActionCopyWithImpl<$Res>
    implements _$ShadeActionCopyWith<$Res> {
  __$ShadeActionCopyWithImpl(this._self, this._then);

  final _ShadeAction _self;
  final $Res Function(_ShadeAction) _then;

/// Create a copy of ShadeAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? since = null,Object? at = null,Object? generations = null,}) {
  return _then(_ShadeAction(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ShadeActionKind,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,generations: null == generations ? _self._generations : generations // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}

/// @nodoc
mixin _$NotificationAccess {

 bool get granted; bool get canAsk; int get sdkInt;
/// Create a copy of NotificationAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationAccessCopyWith<NotificationAccess> get copyWith => _$NotificationAccessCopyWithImpl<NotificationAccess>(this as NotificationAccess, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NotificationAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationAccess&&(identical(other.granted, _this.granted) || other.granted == _this.granted)&&(identical(other.canAsk, _this.canAsk) || other.canAsk == _this.canAsk)&&(identical(other.sdkInt, _this.sdkInt) || other.sdkInt == _this.sdkInt));
}


@override
int get hashCode {
  final _this = this as NotificationAccess;
  return Object.hash(runtimeType,_this.granted,_this.canAsk,_this.sdkInt);
}

@override
String toString() {
  final _this = this as NotificationAccess;
  return 'NotificationAccess(granted: ${_this.granted}, canAsk: ${_this.canAsk}, sdkInt: ${_this.sdkInt})';
}


}

/// @nodoc
abstract mixin class $NotificationAccessCopyWith<$Res>  {
  factory $NotificationAccessCopyWith(NotificationAccess value, $Res Function(NotificationAccess) _then) = _$NotificationAccessCopyWithImpl;
@useResult
$Res call({
 bool granted, bool canAsk, int sdkInt
});




}
/// @nodoc
class _$NotificationAccessCopyWithImpl<$Res>
    implements $NotificationAccessCopyWith<$Res> {
  _$NotificationAccessCopyWithImpl(this._self, this._then);

  final NotificationAccess _self;
  final $Res Function(NotificationAccess) _then;

/// Create a copy of NotificationAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? granted = null,Object? canAsk = null,Object? sdkInt = null,}) {
  return _then(NotificationAccess(
granted: null == granted ? _self.granted : granted // ignore: cast_nullable_to_non_nullable
as bool,canAsk: null == canAsk ? _self.canAsk : canAsk // ignore: cast_nullable_to_non_nullable
as bool,sdkInt: null == sdkInt ? _self.sdkInt : sdkInt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationAccess].
extension NotificationAccessPatterns on NotificationAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationAccess value)  $default,){
final _that = this;
switch (_that) {
case _NotificationAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationAccess value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool granted,  bool canAsk,  int sdkInt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationAccess() when $default != null:
return $default(_that.granted,_that.canAsk,_that.sdkInt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool granted,  bool canAsk,  int sdkInt)  $default,) {final _that = this;
switch (_that) {
case _NotificationAccess():
return $default(_that.granted,_that.canAsk,_that.sdkInt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool granted,  bool canAsk,  int sdkInt)?  $default,) {final _that = this;
switch (_that) {
case _NotificationAccess() when $default != null:
return $default(_that.granted,_that.canAsk,_that.sdkInt);case _:
  return null;

}
}

}

/// @nodoc


class _NotificationAccess implements NotificationAccess {
  const _NotificationAccess({required this.granted, required this.canAsk, required this.sdkInt});
  

@override final  bool granted;
@override final  bool canAsk;
@override final  int sdkInt;

/// Create a copy of NotificationAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationAccessCopyWith<_NotificationAccess> get copyWith => __$NotificationAccessCopyWithImpl<_NotificationAccess>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationAccess&&(identical(other.granted, granted) || other.granted == granted)&&(identical(other.canAsk, canAsk) || other.canAsk == canAsk)&&(identical(other.sdkInt, sdkInt) || other.sdkInt == sdkInt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,granted,canAsk,sdkInt);
}

@override
String toString() {
    return 'NotificationAccess(granted: $granted, canAsk: $canAsk, sdkInt: $sdkInt)';
}


}

/// @nodoc
abstract mixin class _$NotificationAccessCopyWith<$Res> implements $NotificationAccessCopyWith<$Res> {
  factory _$NotificationAccessCopyWith(_NotificationAccess value, $Res Function(_NotificationAccess) _then) = __$NotificationAccessCopyWithImpl;
@override @useResult
$Res call({
 bool granted, bool canAsk, int sdkInt
});




}
/// @nodoc
class __$NotificationAccessCopyWithImpl<$Res>
    implements _$NotificationAccessCopyWith<$Res> {
  __$NotificationAccessCopyWithImpl(this._self, this._then);

  final _NotificationAccess _self;
  final $Res Function(_NotificationAccess) _then;

/// Create a copy of NotificationAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? granted = null,Object? canAsk = null,Object? sdkInt = null,}) {
  return _then(_NotificationAccess(
granted: null == granted ? _self.granted : granted // ignore: cast_nullable_to_non_nullable
as bool,canAsk: null == canAsk ? _self.canAsk : canAsk // ignore: cast_nullable_to_non_nullable
as bool,sdkInt: null == sdkInt ? _self.sdkInt : sdkInt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$Launch {

 LaunchAction get action; int? get reelId;
/// Create a copy of Launch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LaunchCopyWith<Launch> get copyWith => _$LaunchCopyWithImpl<Launch>(this as Launch, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Launch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Launch&&(identical(other.action, _this.action) || other.action == _this.action)&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId));
}


@override
int get hashCode {
  final _this = this as Launch;
  return Object.hash(runtimeType,_this.action,_this.reelId);
}

@override
String toString() {
  final _this = this as Launch;
  return 'Launch(action: ${_this.action}, reelId: ${_this.reelId})';
}


}

/// @nodoc
abstract mixin class $LaunchCopyWith<$Res>  {
  factory $LaunchCopyWith(Launch value, $Res Function(Launch) _then) = _$LaunchCopyWithImpl;
@useResult
$Res call({
 LaunchAction action, int? reelId
});




}
/// @nodoc
class _$LaunchCopyWithImpl<$Res>
    implements $LaunchCopyWith<$Res> {
  _$LaunchCopyWithImpl(this._self, this._then);

  final Launch _self;
  final $Res Function(Launch) _then;

/// Create a copy of Launch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? action = null,Object? reelId = freezed,}) {
  return _then(Launch(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as LaunchAction,reelId: freezed == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Launch].
extension LaunchPatterns on Launch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Launch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Launch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Launch value)  $default,){
final _that = this;
switch (_that) {
case _Launch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Launch value)?  $default,){
final _that = this;
switch (_that) {
case _Launch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LaunchAction action,  int? reelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Launch() when $default != null:
return $default(_that.action,_that.reelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LaunchAction action,  int? reelId)  $default,) {final _that = this;
switch (_that) {
case _Launch():
return $default(_that.action,_that.reelId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LaunchAction action,  int? reelId)?  $default,) {final _that = this;
switch (_that) {
case _Launch() when $default != null:
return $default(_that.action,_that.reelId);case _:
  return null;

}
}

}

/// @nodoc


class _Launch implements Launch {
  const _Launch(this.action, {this.reelId});
  

@override final  LaunchAction action;
@override final  int? reelId;

/// Create a copy of Launch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LaunchCopyWith<_Launch> get copyWith => __$LaunchCopyWithImpl<_Launch>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Launch&&(identical(other.action, action) || other.action == action)&&(identical(other.reelId, reelId) || other.reelId == reelId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,action,reelId);
}

@override
String toString() {
    return 'Launch(action: $action, reelId: $reelId)';
}


}

/// @nodoc
abstract mixin class _$LaunchCopyWith<$Res> implements $LaunchCopyWith<$Res> {
  factory _$LaunchCopyWith(_Launch value, $Res Function(_Launch) _then) = __$LaunchCopyWithImpl;
@override @useResult
$Res call({
 LaunchAction action, int? reelId
});




}
/// @nodoc
class __$LaunchCopyWithImpl<$Res>
    implements _$LaunchCopyWith<$Res> {
  __$LaunchCopyWithImpl(this._self, this._then);

  final _Launch _self;
  final $Res Function(_Launch) _then;

/// Create a copy of Launch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? action = null,Object? reelId = freezed,}) {
  return _then(_Launch(
null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as LaunchAction,reelId: freezed == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
