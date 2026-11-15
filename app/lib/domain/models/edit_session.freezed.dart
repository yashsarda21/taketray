// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edit_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EditSession {

 int get reelId; EditorApp get editor; String get folderName; DateTime get createdAt;
/// Create a copy of EditSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditSessionCopyWith<EditSession> get copyWith => _$EditSessionCopyWithImpl<EditSession>(this as EditSession, _$identity);

  /// Serializes this EditSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditSession&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.editor, _this.editor) || other.editor == _this.editor)&&(identical(other.folderName, _this.folderName) || other.folderName == _this.folderName)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditSession;
  return Object.hash(runtimeType,_this.reelId,_this.editor,_this.folderName,_this.createdAt);
}

@override
String toString() {
  final _this = this as EditSession;
  return 'EditSession(reelId: ${_this.reelId}, editor: ${_this.editor}, folderName: ${_this.folderName}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $EditSessionCopyWith<$Res>  {
  factory $EditSessionCopyWith(EditSession value, $Res Function(EditSession) _then) = _$EditSessionCopyWithImpl;
@useResult
$Res call({
 int reelId, EditorApp editor, String folderName, DateTime createdAt
});




}
/// @nodoc
class _$EditSessionCopyWithImpl<$Res>
    implements $EditSessionCopyWith<$Res> {
  _$EditSessionCopyWithImpl(this._self, this._then);

  final EditSession _self;
  final $Res Function(EditSession) _then;

/// Create a copy of EditSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? editor = null,Object? folderName = null,Object? createdAt = null,}) {
  return _then(EditSession(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as EditorApp,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EditSession].
extension EditSessionPatterns on EditSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditSession value)  $default,){
final _that = this;
switch (_that) {
case _EditSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditSession value)?  $default,){
final _that = this;
switch (_that) {
case _EditSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  EditorApp editor,  String folderName,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditSession() when $default != null:
return $default(_that.reelId,_that.editor,_that.folderName,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  EditorApp editor,  String folderName,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _EditSession():
return $default(_that.reelId,_that.editor,_that.folderName,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  EditorApp editor,  String folderName,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _EditSession() when $default != null:
return $default(_that.reelId,_that.editor,_that.folderName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditSession implements EditSession {
  const _EditSession({required this.reelId, required this.editor, required this.folderName, required this.createdAt});
  factory _EditSession.fromJson(Map<String, dynamic> json) => _$EditSessionFromJson(json);

@override final  int reelId;
@override final  EditorApp editor;
@override final  String folderName;
@override final  DateTime createdAt;

/// Create a copy of EditSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditSessionCopyWith<_EditSession> get copyWith => __$EditSessionCopyWithImpl<_EditSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditSessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditSession&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.editor, editor) || other.editor == editor)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reelId,editor,folderName,createdAt);
}

@override
String toString() {
    return 'EditSession(reelId: $reelId, editor: $editor, folderName: $folderName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$EditSessionCopyWith<$Res> implements $EditSessionCopyWith<$Res> {
  factory _$EditSessionCopyWith(_EditSession value, $Res Function(_EditSession) _then) = __$EditSessionCopyWithImpl;
@override @useResult
$Res call({
 int reelId, EditorApp editor, String folderName, DateTime createdAt
});




}
/// @nodoc
class __$EditSessionCopyWithImpl<$Res>
    implements _$EditSessionCopyWith<$Res> {
  __$EditSessionCopyWithImpl(this._self, this._then);

  final _EditSession _self;
  final $Res Function(_EditSession) _then;

/// Create a copy of EditSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? editor = null,Object? folderName = null,Object? createdAt = null,}) {
  return _then(_EditSession(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as EditorApp,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$EditState {

 EditSession get session; List<EditCopy> get copies; Set<int> get sentIds;
/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditStateCopyWith<EditState> get copyWith => _$EditStateCopyWithImpl<EditState>(this as EditState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EditState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditState&&(identical(other.session, _this.session) || other.session == _this.session)&&const DeepCollectionEquality().equals(other.copies, _this.copies)&&const DeepCollectionEquality().equals(other.sentIds, _this.sentIds));
}


@override
int get hashCode {
  final _this = this as EditState;
  return Object.hash(runtimeType,_this.session,const DeepCollectionEquality().hash(_this.copies),const DeepCollectionEquality().hash(_this.sentIds));
}

@override
String toString() {
  final _this = this as EditState;
  return 'EditState(session: ${_this.session}, copies: ${_this.copies}, sentIds: ${_this.sentIds})';
}


}

/// @nodoc
abstract mixin class $EditStateCopyWith<$Res>  {
  factory $EditStateCopyWith(EditState value, $Res Function(EditState) _then) = _$EditStateCopyWithImpl;
@useResult
$Res call({
 EditSession session, List<EditCopy> copies, Set<int> sentIds
});


$EditSessionCopyWith<$Res> get session;

}
/// @nodoc
class _$EditStateCopyWithImpl<$Res>
    implements $EditStateCopyWith<$Res> {
  _$EditStateCopyWithImpl(this._self, this._then);

  final EditState _self;
  final $Res Function(EditState) _then;

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,Object? copies = null,Object? sentIds = null,}) {
  return _then(EditState(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as EditSession,copies: null == copies ? _self.copies : copies // ignore: cast_nullable_to_non_nullable
as List<EditCopy>,sentIds: null == sentIds ? _self.sentIds : sentIds // ignore: cast_nullable_to_non_nullable
as Set<int>,
  ));
}
/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EditSessionCopyWith<$Res> get session {
  
  return $EditSessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}


/// Adds pattern-matching-related methods to [EditState].
extension EditStatePatterns on EditState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditState value)  $default,){
final _that = this;
switch (_that) {
case _EditState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditState value)?  $default,){
final _that = this;
switch (_that) {
case _EditState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EditSession session,  List<EditCopy> copies,  Set<int> sentIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that.session,_that.copies,_that.sentIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EditSession session,  List<EditCopy> copies,  Set<int> sentIds)  $default,) {final _that = this;
switch (_that) {
case _EditState():
return $default(_that.session,_that.copies,_that.sentIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EditSession session,  List<EditCopy> copies,  Set<int> sentIds)?  $default,) {final _that = this;
switch (_that) {
case _EditState() when $default != null:
return $default(_that.session,_that.copies,_that.sentIds);case _:
  return null;

}
}

}

/// @nodoc


class _EditState implements EditState {
  const _EditState({required this.session, required  List<EditCopy> copies, required  Set<int> sentIds}): _copies = copies,_sentIds = sentIds;
  

@override final  EditSession session;
 final  List<EditCopy> _copies;
@override List<EditCopy> get copies {
  if (_copies is EqualUnmodifiableListView) return _copies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_copies);
}

 final  Set<int> _sentIds;
@override Set<int> get sentIds {
  if (_sentIds is EqualUnmodifiableSetView) return _sentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_sentIds);
}


/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditStateCopyWith<_EditState> get copyWith => __$EditStateCopyWithImpl<_EditState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditState&&(identical(other.session, session) || other.session == session)&&const DeepCollectionEquality().equals(other.copies, _copies)&&const DeepCollectionEquality().equals(other.sentIds, _sentIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,session,const DeepCollectionEquality().hash(_copies),const DeepCollectionEquality().hash(_sentIds));
}

@override
String toString() {
    return 'EditState(session: $session, copies: $copies, sentIds: $sentIds)';
}


}

/// @nodoc
abstract mixin class _$EditStateCopyWith<$Res> implements $EditStateCopyWith<$Res> {
  factory _$EditStateCopyWith(_EditState value, $Res Function(_EditState) _then) = __$EditStateCopyWithImpl;
@override @useResult
$Res call({
 EditSession session, List<EditCopy> copies, Set<int> sentIds
});


@override $EditSessionCopyWith<$Res> get session;

}
/// @nodoc
class __$EditStateCopyWithImpl<$Res>
    implements _$EditStateCopyWith<$Res> {
  __$EditStateCopyWithImpl(this._self, this._then);

  final _EditState _self;
  final $Res Function(_EditState) _then;

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,Object? copies = null,Object? sentIds = null,}) {
  return _then(_EditState(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as EditSession,copies: null == copies ? _self._copies : copies // ignore: cast_nullable_to_non_nullable
as List<EditCopy>,sentIds: null == sentIds ? _self._sentIds : sentIds // ignore: cast_nullable_to_non_nullable
as Set<int>,
  ));
}

/// Create a copy of EditState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EditSessionCopyWith<$Res> get session {
  
  return $EditSessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

/// @nodoc
mixin _$EditSessionSummary {

 int get reelId;/// The reel's name now (it may differ from [folderName]: a rename keeps
/// the folder).
 String get reelName; EditorApp get editor; String get folderName; DateTime get createdAt;/// How many copy files are recorded, and their total size in bytes.
 int get copyCount; int get copyBytes;/// When the newest recorded copy was made; null with no copies.
 DateTime? get lastCopiedAt;
/// Create a copy of EditSessionSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditSessionSummaryCopyWith<EditSessionSummary> get copyWith => _$EditSessionSummaryCopyWithImpl<EditSessionSummary>(this as EditSessionSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EditSessionSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditSessionSummary&&(identical(other.reelId, _this.reelId) || other.reelId == _this.reelId)&&(identical(other.reelName, _this.reelName) || other.reelName == _this.reelName)&&(identical(other.editor, _this.editor) || other.editor == _this.editor)&&(identical(other.folderName, _this.folderName) || other.folderName == _this.folderName)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.copyCount, _this.copyCount) || other.copyCount == _this.copyCount)&&(identical(other.copyBytes, _this.copyBytes) || other.copyBytes == _this.copyBytes)&&(identical(other.lastCopiedAt, _this.lastCopiedAt) || other.lastCopiedAt == _this.lastCopiedAt));
}


@override
int get hashCode {
  final _this = this as EditSessionSummary;
  return Object.hash(runtimeType,_this.reelId,_this.reelName,_this.editor,_this.folderName,_this.createdAt,_this.copyCount,_this.copyBytes,_this.lastCopiedAt);
}

@override
String toString() {
  final _this = this as EditSessionSummary;
  return 'EditSessionSummary(reelId: ${_this.reelId}, reelName: ${_this.reelName}, editor: ${_this.editor}, folderName: ${_this.folderName}, createdAt: ${_this.createdAt}, copyCount: ${_this.copyCount}, copyBytes: ${_this.copyBytes}, lastCopiedAt: ${_this.lastCopiedAt})';
}


}

/// @nodoc
abstract mixin class $EditSessionSummaryCopyWith<$Res>  {
  factory $EditSessionSummaryCopyWith(EditSessionSummary value, $Res Function(EditSessionSummary) _then) = _$EditSessionSummaryCopyWithImpl;
@useResult
$Res call({
 int reelId, String reelName, EditorApp editor, String folderName, DateTime createdAt, int copyCount, int copyBytes, DateTime? lastCopiedAt
});




}
/// @nodoc
class _$EditSessionSummaryCopyWithImpl<$Res>
    implements $EditSessionSummaryCopyWith<$Res> {
  _$EditSessionSummaryCopyWithImpl(this._self, this._then);

  final EditSessionSummary _self;
  final $Res Function(EditSessionSummary) _then;

/// Create a copy of EditSessionSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reelId = null,Object? reelName = null,Object? editor = null,Object? folderName = null,Object? createdAt = null,Object? copyCount = null,Object? copyBytes = null,Object? lastCopiedAt = freezed,}) {
  return _then(EditSessionSummary(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,reelName: null == reelName ? _self.reelName : reelName // ignore: cast_nullable_to_non_nullable
as String,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as EditorApp,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,copyCount: null == copyCount ? _self.copyCount : copyCount // ignore: cast_nullable_to_non_nullable
as int,copyBytes: null == copyBytes ? _self.copyBytes : copyBytes // ignore: cast_nullable_to_non_nullable
as int,lastCopiedAt: freezed == lastCopiedAt ? _self.lastCopiedAt : lastCopiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [EditSessionSummary].
extension EditSessionSummaryPatterns on EditSessionSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditSessionSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditSessionSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditSessionSummary value)  $default,){
final _that = this;
switch (_that) {
case _EditSessionSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditSessionSummary value)?  $default,){
final _that = this;
switch (_that) {
case _EditSessionSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int reelId,  String reelName,  EditorApp editor,  String folderName,  DateTime createdAt,  int copyCount,  int copyBytes,  DateTime? lastCopiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditSessionSummary() when $default != null:
return $default(_that.reelId,_that.reelName,_that.editor,_that.folderName,_that.createdAt,_that.copyCount,_that.copyBytes,_that.lastCopiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int reelId,  String reelName,  EditorApp editor,  String folderName,  DateTime createdAt,  int copyCount,  int copyBytes,  DateTime? lastCopiedAt)  $default,) {final _that = this;
switch (_that) {
case _EditSessionSummary():
return $default(_that.reelId,_that.reelName,_that.editor,_that.folderName,_that.createdAt,_that.copyCount,_that.copyBytes,_that.lastCopiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int reelId,  String reelName,  EditorApp editor,  String folderName,  DateTime createdAt,  int copyCount,  int copyBytes,  DateTime? lastCopiedAt)?  $default,) {final _that = this;
switch (_that) {
case _EditSessionSummary() when $default != null:
return $default(_that.reelId,_that.reelName,_that.editor,_that.folderName,_that.createdAt,_that.copyCount,_that.copyBytes,_that.lastCopiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EditSessionSummary implements EditSessionSummary {
  const _EditSessionSummary({required this.reelId, required this.reelName, required this.editor, required this.folderName, required this.createdAt, required this.copyCount, required this.copyBytes, this.lastCopiedAt});
  

@override final  int reelId;
/// The reel's name now (it may differ from [folderName]: a rename keeps
/// the folder).
@override final  String reelName;
@override final  EditorApp editor;
@override final  String folderName;
@override final  DateTime createdAt;
/// How many copy files are recorded, and their total size in bytes.
@override final  int copyCount;
@override final  int copyBytes;
/// When the newest recorded copy was made; null with no copies.
@override final  DateTime? lastCopiedAt;

/// Create a copy of EditSessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditSessionSummaryCopyWith<_EditSessionSummary> get copyWith => __$EditSessionSummaryCopyWithImpl<_EditSessionSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditSessionSummary&&(identical(other.reelId, reelId) || other.reelId == reelId)&&(identical(other.reelName, reelName) || other.reelName == reelName)&&(identical(other.editor, editor) || other.editor == editor)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.copyCount, copyCount) || other.copyCount == copyCount)&&(identical(other.copyBytes, copyBytes) || other.copyBytes == copyBytes)&&(identical(other.lastCopiedAt, lastCopiedAt) || other.lastCopiedAt == lastCopiedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reelId,reelName,editor,folderName,createdAt,copyCount,copyBytes,lastCopiedAt);
}

@override
String toString() {
    return 'EditSessionSummary(reelId: $reelId, reelName: $reelName, editor: $editor, folderName: $folderName, createdAt: $createdAt, copyCount: $copyCount, copyBytes: $copyBytes, lastCopiedAt: $lastCopiedAt)';
}


}

/// @nodoc
abstract mixin class _$EditSessionSummaryCopyWith<$Res> implements $EditSessionSummaryCopyWith<$Res> {
  factory _$EditSessionSummaryCopyWith(_EditSessionSummary value, $Res Function(_EditSessionSummary) _then) = __$EditSessionSummaryCopyWithImpl;
@override @useResult
$Res call({
 int reelId, String reelName, EditorApp editor, String folderName, DateTime createdAt, int copyCount, int copyBytes, DateTime? lastCopiedAt
});




}
/// @nodoc
class __$EditSessionSummaryCopyWithImpl<$Res>
    implements _$EditSessionSummaryCopyWith<$Res> {
  __$EditSessionSummaryCopyWithImpl(this._self, this._then);

  final _EditSessionSummary _self;
  final $Res Function(_EditSessionSummary) _then;

/// Create a copy of EditSessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reelId = null,Object? reelName = null,Object? editor = null,Object? folderName = null,Object? createdAt = null,Object? copyCount = null,Object? copyBytes = null,Object? lastCopiedAt = freezed,}) {
  return _then(_EditSessionSummary(
reelId: null == reelId ? _self.reelId : reelId // ignore: cast_nullable_to_non_nullable
as int,reelName: null == reelName ? _self.reelName : reelName // ignore: cast_nullable_to_non_nullable
as String,editor: null == editor ? _self.editor : editor // ignore: cast_nullable_to_non_nullable
as EditorApp,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,copyCount: null == copyCount ? _self.copyCount : copyCount // ignore: cast_nullable_to_non_nullable
as int,copyBytes: null == copyBytes ? _self.copyBytes : copyBytes // ignore: cast_nullable_to_non_nullable
as int,lastCopiedAt: freezed == lastCopiedAt ? _self.lastCopiedAt : lastCopiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
