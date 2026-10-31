// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_session_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TagSessionState {

/// The clips that were in To tag when the player opened, in shooting
/// order. Fixed for the session: clips that arrive later are not in it.
 List<int> get session;/// The clip showing, an index into [session].
 int get index;/// "Pick several" is on. Sticky: it stays on from clip to clip until the
/// user turns it off (owner ruling, D-91).
 bool get multi;/// The reels picked for the clip showing, in the order picked. Cleared at
/// every new clip.
 List<int> get picked;/// The reel whose chip was just tapped, during its hold (the chip shows
/// a check). Null otherwise.
 int? get confirmingReelId;/// A write is running (a tag, a skip, a new reel, an Undo).
 bool get busy;/// Nothing in the session is waiting any more: "All done!".
 bool get done;/// How many clips this session put into each reel, by reel id (the done
/// screen's "+{n}" rows).
 Map<int, int> get taggedPerReel;/// How many clips this session skipped.
 int get skipped;/// The clip of the last tag or skip.
 int? get lastActedClipId;/// The ids of [session] still in To tag.
 Set<int> get pending;/// The session's clips by id. A waiting clip's row is refreshed at each
/// change of To tag, so the player plays it from its current identity.
 Map<int, Clip> get clips;/// The time where each clip was shot (D-83), once `ClipTimeService` has
/// answered; empty until then.
 Map<int, ClipLocalTime> get times;/// All the session's clips in scenes (D-95), also the ones that have
/// left To tag. Until [times] arrive they use the phone's time.
 List<Scene> get scenes;
/// Create a copy of TagSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagSessionStateCopyWith<TagSessionState> get copyWith => _$TagSessionStateCopyWithImpl<TagSessionState>(this as TagSessionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TagSessionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagSessionState&&const DeepCollectionEquality().equals(other.session, _this.session)&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.multi, _this.multi) || other.multi == _this.multi)&&const DeepCollectionEquality().equals(other.picked, _this.picked)&&(identical(other.confirmingReelId, _this.confirmingReelId) || other.confirmingReelId == _this.confirmingReelId)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.done, _this.done) || other.done == _this.done)&&const DeepCollectionEquality().equals(other.taggedPerReel, _this.taggedPerReel)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped)&&(identical(other.lastActedClipId, _this.lastActedClipId) || other.lastActedClipId == _this.lastActedClipId)&&const DeepCollectionEquality().equals(other.pending, _this.pending)&&const DeepCollectionEquality().equals(other.clips, _this.clips)&&const DeepCollectionEquality().equals(other.times, _this.times)&&const DeepCollectionEquality().equals(other.scenes, _this.scenes));
}


@override
int get hashCode {
  final _this = this as TagSessionState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.session),_this.index,_this.multi,const DeepCollectionEquality().hash(_this.picked),_this.confirmingReelId,_this.busy,_this.done,const DeepCollectionEquality().hash(_this.taggedPerReel),_this.skipped,_this.lastActedClipId,const DeepCollectionEquality().hash(_this.pending),const DeepCollectionEquality().hash(_this.clips),const DeepCollectionEquality().hash(_this.times),const DeepCollectionEquality().hash(_this.scenes));
}

@override
String toString() {
  final _this = this as TagSessionState;
  return 'TagSessionState(session: ${_this.session}, index: ${_this.index}, multi: ${_this.multi}, picked: ${_this.picked}, confirmingReelId: ${_this.confirmingReelId}, busy: ${_this.busy}, done: ${_this.done}, taggedPerReel: ${_this.taggedPerReel}, skipped: ${_this.skipped}, lastActedClipId: ${_this.lastActedClipId}, pending: ${_this.pending}, clips: ${_this.clips}, times: ${_this.times}, scenes: ${_this.scenes})';
}


}

/// @nodoc
abstract mixin class $TagSessionStateCopyWith<$Res>  {
  factory $TagSessionStateCopyWith(TagSessionState value, $Res Function(TagSessionState) _then) = _$TagSessionStateCopyWithImpl;
@useResult
$Res call({
 List<int> session, int index, bool multi, List<int> picked, int? confirmingReelId, bool busy, bool done, Map<int, int> taggedPerReel, int skipped, int? lastActedClipId, Set<int> pending, Map<int, Clip> clips, Map<int, ClipLocalTime> times, List<Scene> scenes
});




}
/// @nodoc
class _$TagSessionStateCopyWithImpl<$Res>
    implements $TagSessionStateCopyWith<$Res> {
  _$TagSessionStateCopyWithImpl(this._self, this._then);

  final TagSessionState _self;
  final $Res Function(TagSessionState) _then;

/// Create a copy of TagSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,Object? index = null,Object? multi = null,Object? picked = null,Object? confirmingReelId = freezed,Object? busy = null,Object? done = null,Object? taggedPerReel = null,Object? skipped = null,Object? lastActedClipId = freezed,Object? pending = null,Object? clips = null,Object? times = null,Object? scenes = null,}) {
  return _then(TagSessionState(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as List<int>,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,multi: null == multi ? _self.multi : multi // ignore: cast_nullable_to_non_nullable
as bool,picked: null == picked ? _self.picked : picked // ignore: cast_nullable_to_non_nullable
as List<int>,confirmingReelId: freezed == confirmingReelId ? _self.confirmingReelId : confirmingReelId // ignore: cast_nullable_to_non_nullable
as int?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,taggedPerReel: null == taggedPerReel ? _self.taggedPerReel : taggedPerReel // ignore: cast_nullable_to_non_nullable
as Map<int, int>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,lastActedClipId: freezed == lastActedClipId ? _self.lastActedClipId : lastActedClipId // ignore: cast_nullable_to_non_nullable
as int?,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as Set<int>,clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as Map<int, Clip>,times: null == times ? _self.times : times // ignore: cast_nullable_to_non_nullable
as Map<int, ClipLocalTime>,scenes: null == scenes ? _self.scenes : scenes // ignore: cast_nullable_to_non_nullable
as List<Scene>,
  ));
}

}


/// Adds pattern-matching-related methods to [TagSessionState].
extension TagSessionStatePatterns on TagSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TagSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TagSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TagSessionState value)  $default,){
final _that = this;
switch (_that) {
case _TagSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TagSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _TagSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<int> session,  int index,  bool multi,  List<int> picked,  int? confirmingReelId,  bool busy,  bool done,  Map<int, int> taggedPerReel,  int skipped,  int? lastActedClipId,  Set<int> pending,  Map<int, Clip> clips,  Map<int, ClipLocalTime> times,  List<Scene> scenes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TagSessionState() when $default != null:
return $default(_that.session,_that.index,_that.multi,_that.picked,_that.confirmingReelId,_that.busy,_that.done,_that.taggedPerReel,_that.skipped,_that.lastActedClipId,_that.pending,_that.clips,_that.times,_that.scenes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<int> session,  int index,  bool multi,  List<int> picked,  int? confirmingReelId,  bool busy,  bool done,  Map<int, int> taggedPerReel,  int skipped,  int? lastActedClipId,  Set<int> pending,  Map<int, Clip> clips,  Map<int, ClipLocalTime> times,  List<Scene> scenes)  $default,) {final _that = this;
switch (_that) {
case _TagSessionState():
return $default(_that.session,_that.index,_that.multi,_that.picked,_that.confirmingReelId,_that.busy,_that.done,_that.taggedPerReel,_that.skipped,_that.lastActedClipId,_that.pending,_that.clips,_that.times,_that.scenes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<int> session,  int index,  bool multi,  List<int> picked,  int? confirmingReelId,  bool busy,  bool done,  Map<int, int> taggedPerReel,  int skipped,  int? lastActedClipId,  Set<int> pending,  Map<int, Clip> clips,  Map<int, ClipLocalTime> times,  List<Scene> scenes)?  $default,) {final _that = this;
switch (_that) {
case _TagSessionState() when $default != null:
return $default(_that.session,_that.index,_that.multi,_that.picked,_that.confirmingReelId,_that.busy,_that.done,_that.taggedPerReel,_that.skipped,_that.lastActedClipId,_that.pending,_that.clips,_that.times,_that.scenes);case _:
  return null;

}
}

}

/// @nodoc


class _TagSessionState extends TagSessionState {
  const _TagSessionState({required  List<int> session, this.index = 0, this.multi = false,  List<int> picked = const <int>[], this.confirmingReelId, this.busy = false, this.done = false,  Map<int, int> taggedPerReel = const <int, int>{}, this.skipped = 0, this.lastActedClipId,  Set<int> pending = const <int>{},  Map<int, Clip> clips = const <int, Clip>{},  Map<int, ClipLocalTime> times = const <int, ClipLocalTime>{},  List<Scene> scenes = const <Scene>[]}): _session = session,_picked = picked,_taggedPerReel = taggedPerReel,_pending = pending,_clips = clips,_times = times,_scenes = scenes,super._();
  

/// The clips that were in To tag when the player opened, in shooting
/// order. Fixed for the session: clips that arrive later are not in it.
 final  List<int> _session;
/// The clips that were in To tag when the player opened, in shooting
/// order. Fixed for the session: clips that arrive later are not in it.
@override List<int> get session {
  if (_session is EqualUnmodifiableListView) return _session;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_session);
}

/// The clip showing, an index into [session].
@override@JsonKey() final  int index;
/// "Pick several" is on. Sticky: it stays on from clip to clip until the
/// user turns it off (owner ruling, D-91).
@override@JsonKey() final  bool multi;
/// The reels picked for the clip showing, in the order picked. Cleared at
/// every new clip.
 final  List<int> _picked;
/// The reels picked for the clip showing, in the order picked. Cleared at
/// every new clip.
@override@JsonKey() List<int> get picked {
  if (_picked is EqualUnmodifiableListView) return _picked;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_picked);
}

/// The reel whose chip was just tapped, during its hold (the chip shows
/// a check). Null otherwise.
@override final  int? confirmingReelId;
/// A write is running (a tag, a skip, a new reel, an Undo).
@override@JsonKey() final  bool busy;
/// Nothing in the session is waiting any more: "All done!".
@override@JsonKey() final  bool done;
/// How many clips this session put into each reel, by reel id (the done
/// screen's "+{n}" rows).
 final  Map<int, int> _taggedPerReel;
/// How many clips this session put into each reel, by reel id (the done
/// screen's "+{n}" rows).
@override@JsonKey() Map<int, int> get taggedPerReel {
  if (_taggedPerReel is EqualUnmodifiableMapView) return _taggedPerReel;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_taggedPerReel);
}

/// How many clips this session skipped.
@override@JsonKey() final  int skipped;
/// The clip of the last tag or skip.
@override final  int? lastActedClipId;
/// The ids of [session] still in To tag.
 final  Set<int> _pending;
/// The ids of [session] still in To tag.
@override@JsonKey() Set<int> get pending {
  if (_pending is EqualUnmodifiableSetView) return _pending;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pending);
}

/// The session's clips by id. A waiting clip's row is refreshed at each
/// change of To tag, so the player plays it from its current identity.
 final  Map<int, Clip> _clips;
/// The session's clips by id. A waiting clip's row is refreshed at each
/// change of To tag, so the player plays it from its current identity.
@override@JsonKey() Map<int, Clip> get clips {
  if (_clips is EqualUnmodifiableMapView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_clips);
}

/// The time where each clip was shot (D-83), once `ClipTimeService` has
/// answered; empty until then.
 final  Map<int, ClipLocalTime> _times;
/// The time where each clip was shot (D-83), once `ClipTimeService` has
/// answered; empty until then.
@override@JsonKey() Map<int, ClipLocalTime> get times {
  if (_times is EqualUnmodifiableMapView) return _times;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_times);
}

/// All the session's clips in scenes (D-95), also the ones that have
/// left To tag. Until [times] arrive they use the phone's time.
 final  List<Scene> _scenes;
/// All the session's clips in scenes (D-95), also the ones that have
/// left To tag. Until [times] arrive they use the phone's time.
@override@JsonKey() List<Scene> get scenes {
  if (_scenes is EqualUnmodifiableListView) return _scenes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scenes);
}


/// Create a copy of TagSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagSessionStateCopyWith<_TagSessionState> get copyWith => __$TagSessionStateCopyWithImpl<_TagSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TagSessionState&&const DeepCollectionEquality().equals(other.session, _session)&&(identical(other.index, index) || other.index == index)&&(identical(other.multi, multi) || other.multi == multi)&&const DeepCollectionEquality().equals(other.picked, _picked)&&(identical(other.confirmingReelId, confirmingReelId) || other.confirmingReelId == confirmingReelId)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.done, done) || other.done == done)&&const DeepCollectionEquality().equals(other.taggedPerReel, _taggedPerReel)&&(identical(other.skipped, skipped) || other.skipped == skipped)&&(identical(other.lastActedClipId, lastActedClipId) || other.lastActedClipId == lastActedClipId)&&const DeepCollectionEquality().equals(other.pending, _pending)&&const DeepCollectionEquality().equals(other.clips, _clips)&&const DeepCollectionEquality().equals(other.times, _times)&&const DeepCollectionEquality().equals(other.scenes, _scenes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_session),index,multi,const DeepCollectionEquality().hash(_picked),confirmingReelId,busy,done,const DeepCollectionEquality().hash(_taggedPerReel),skipped,lastActedClipId,const DeepCollectionEquality().hash(_pending),const DeepCollectionEquality().hash(_clips),const DeepCollectionEquality().hash(_times),const DeepCollectionEquality().hash(_scenes));
}

@override
String toString() {
    return 'TagSessionState(session: $session, index: $index, multi: $multi, picked: $picked, confirmingReelId: $confirmingReelId, busy: $busy, done: $done, taggedPerReel: $taggedPerReel, skipped: $skipped, lastActedClipId: $lastActedClipId, pending: $pending, clips: $clips, times: $times, scenes: $scenes)';
}


}

/// @nodoc
abstract mixin class _$TagSessionStateCopyWith<$Res> implements $TagSessionStateCopyWith<$Res> {
  factory _$TagSessionStateCopyWith(_TagSessionState value, $Res Function(_TagSessionState) _then) = __$TagSessionStateCopyWithImpl;
@override @useResult
$Res call({
 List<int> session, int index, bool multi, List<int> picked, int? confirmingReelId, bool busy, bool done, Map<int, int> taggedPerReel, int skipped, int? lastActedClipId, Set<int> pending, Map<int, Clip> clips, Map<int, ClipLocalTime> times, List<Scene> scenes
});




}
/// @nodoc
class __$TagSessionStateCopyWithImpl<$Res>
    implements _$TagSessionStateCopyWith<$Res> {
  __$TagSessionStateCopyWithImpl(this._self, this._then);

  final _TagSessionState _self;
  final $Res Function(_TagSessionState) _then;

/// Create a copy of TagSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,Object? index = null,Object? multi = null,Object? picked = null,Object? confirmingReelId = freezed,Object? busy = null,Object? done = null,Object? taggedPerReel = null,Object? skipped = null,Object? lastActedClipId = freezed,Object? pending = null,Object? clips = null,Object? times = null,Object? scenes = null,}) {
  return _then(_TagSessionState(
session: null == session ? _self._session : session // ignore: cast_nullable_to_non_nullable
as List<int>,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,multi: null == multi ? _self.multi : multi // ignore: cast_nullable_to_non_nullable
as bool,picked: null == picked ? _self._picked : picked // ignore: cast_nullable_to_non_nullable
as List<int>,confirmingReelId: freezed == confirmingReelId ? _self.confirmingReelId : confirmingReelId // ignore: cast_nullable_to_non_nullable
as int?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,taggedPerReel: null == taggedPerReel ? _self._taggedPerReel : taggedPerReel // ignore: cast_nullable_to_non_nullable
as Map<int, int>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,lastActedClipId: freezed == lastActedClipId ? _self.lastActedClipId : lastActedClipId // ignore: cast_nullable_to_non_nullable
as int?,pending: null == pending ? _self._pending : pending // ignore: cast_nullable_to_non_nullable
as Set<int>,clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as Map<int, Clip>,times: null == times ? _self._times : times // ignore: cast_nullable_to_non_nullable
as Map<int, ClipLocalTime>,scenes: null == scenes ? _self._scenes : scenes // ignore: cast_nullable_to_non_nullable
as List<Scene>,
  ));
}


}

// dart format on
