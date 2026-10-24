// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QrState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QrState()';
}


}

/// @nodoc
class $QrStateCopyWith<$Res>  {
$QrStateCopyWith(QrState _, $Res Function(QrState) __);
}


/// Adds pattern-matching-related methods to [QrState].
extension QrStatePatterns on QrState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( QrState_Expired value)?  expired,TResult Function( QrState_Waiting value)?  waiting,TResult Function( QrState_Scanned value)?  scanned,TResult Function( QrState_Authorized value)?  authorized,TResult Function( QrState_Failed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case QrState_Expired() when expired != null:
return expired(_that);case QrState_Waiting() when waiting != null:
return waiting(_that);case QrState_Scanned() when scanned != null:
return scanned(_that);case QrState_Authorized() when authorized != null:
return authorized(_that);case QrState_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( QrState_Expired value)  expired,required TResult Function( QrState_Waiting value)  waiting,required TResult Function( QrState_Scanned value)  scanned,required TResult Function( QrState_Authorized value)  authorized,required TResult Function( QrState_Failed value)  failed,}){
final _that = this;
switch (_that) {
case QrState_Expired():
return expired(_that);case QrState_Waiting():
return waiting(_that);case QrState_Scanned():
return scanned(_that);case QrState_Authorized():
return authorized(_that);case QrState_Failed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( QrState_Expired value)?  expired,TResult? Function( QrState_Waiting value)?  waiting,TResult? Function( QrState_Scanned value)?  scanned,TResult? Function( QrState_Authorized value)?  authorized,TResult? Function( QrState_Failed value)?  failed,}){
final _that = this;
switch (_that) {
case QrState_Expired() when expired != null:
return expired(_that);case QrState_Waiting() when waiting != null:
return waiting(_that);case QrState_Scanned() when scanned != null:
return scanned(_that);case QrState_Authorized() when authorized != null:
return authorized(_that);case QrState_Failed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  expired,TResult Function()?  waiting,TResult Function( String nickname,  String? avatarUrl)?  scanned,TResult Function()?  authorized,TResult Function( String message)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case QrState_Expired() when expired != null:
return expired();case QrState_Waiting() when waiting != null:
return waiting();case QrState_Scanned() when scanned != null:
return scanned(_that.nickname,_that.avatarUrl);case QrState_Authorized() when authorized != null:
return authorized();case QrState_Failed() when failed != null:
return failed(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  expired,required TResult Function()  waiting,required TResult Function( String nickname,  String? avatarUrl)  scanned,required TResult Function()  authorized,required TResult Function( String message)  failed,}) {final _that = this;
switch (_that) {
case QrState_Expired():
return expired();case QrState_Waiting():
return waiting();case QrState_Scanned():
return scanned(_that.nickname,_that.avatarUrl);case QrState_Authorized():
return authorized();case QrState_Failed():
return failed(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  expired,TResult? Function()?  waiting,TResult? Function( String nickname,  String? avatarUrl)?  scanned,TResult? Function()?  authorized,TResult? Function( String message)?  failed,}) {final _that = this;
switch (_that) {
case QrState_Expired() when expired != null:
return expired();case QrState_Waiting() when waiting != null:
return waiting();case QrState_Scanned() when scanned != null:
return scanned(_that.nickname,_that.avatarUrl);case QrState_Authorized() when authorized != null:
return authorized();case QrState_Failed() when failed != null:
return failed(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class QrState_Expired extends QrState {
  const QrState_Expired(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState_Expired);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QrState.expired()';
}


}




/// @nodoc


class QrState_Waiting extends QrState {
  const QrState_Waiting(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState_Waiting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QrState.waiting()';
}


}




/// @nodoc


class QrState_Scanned extends QrState {
  const QrState_Scanned({required this.nickname, this.avatarUrl}): super._();
  

 final  String nickname;
 final  String? avatarUrl;

/// Create a copy of QrState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QrState_ScannedCopyWith<QrState_Scanned> get copyWith => _$QrState_ScannedCopyWithImpl<QrState_Scanned>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState_Scanned&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,nickname,avatarUrl);
}

@override
String toString() {
    return 'QrState.scanned(nickname: $nickname, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $QrState_ScannedCopyWith<$Res> implements $QrStateCopyWith<$Res> {
  factory $QrState_ScannedCopyWith(QrState_Scanned value, $Res Function(QrState_Scanned) _then) = _$QrState_ScannedCopyWithImpl;
@useResult
$Res call({
 String nickname, String? avatarUrl
});




}
/// @nodoc
class _$QrState_ScannedCopyWithImpl<$Res>
    implements $QrState_ScannedCopyWith<$Res> {
  _$QrState_ScannedCopyWithImpl(this._self, this._then);

  final QrState_Scanned _self;
  final $Res Function(QrState_Scanned) _then;

/// Create a copy of QrState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? nickname = null,Object? avatarUrl = freezed,}) {
  return _then(QrState_Scanned(
nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class QrState_Authorized extends QrState {
  const QrState_Authorized(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState_Authorized);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QrState.authorized()';
}


}




/// @nodoc


class QrState_Failed extends QrState {
  const QrState_Failed({required this.message}): super._();
  

 final  String message;

/// Create a copy of QrState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QrState_FailedCopyWith<QrState_Failed> get copyWith => _$QrState_FailedCopyWithImpl<QrState_Failed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QrState_Failed&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'QrState.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $QrState_FailedCopyWith<$Res> implements $QrStateCopyWith<$Res> {
  factory $QrState_FailedCopyWith(QrState_Failed value, $Res Function(QrState_Failed) _then) = _$QrState_FailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$QrState_FailedCopyWithImpl<$Res>
    implements $QrState_FailedCopyWith<$Res> {
  _$QrState_FailedCopyWithImpl(this._self, this._then);

  final QrState_Failed _self;
  final $Res Function(QrState_Failed) _then;

/// Create a copy of QrState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(QrState_Failed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UiEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent()';
}


}

/// @nodoc
class $UiEventCopyWith<$Res>  {
$UiEventCopyWith(UiEvent _, $Res Function(UiEvent) __);
}


/// Adds pattern-matching-related methods to [UiEvent].
extension UiEventPatterns on UiEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UiEvent_State value)?  state,TResult Function( UiEvent_Position value)?  position,TResult Function( UiEvent_TrackChanged value)?  trackChanged,TResult Function( UiEvent_QueueChanged value)?  queueChanged,TResult Function( UiEvent_SettingsChanged value)?  settingsChanged,TResult Function( UiEvent_DownloadsChanged value)?  downloadsChanged,TResult Function( UiEvent_Raise value)?  raise,TResult Function( UiEvent_Quit value)?  quit,TResult Function( UiEvent_Notice value)?  notice,TResult Function( UiEvent_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UiEvent_State() when state != null:
return state(_that);case UiEvent_Position() when position != null:
return position(_that);case UiEvent_TrackChanged() when trackChanged != null:
return trackChanged(_that);case UiEvent_QueueChanged() when queueChanged != null:
return queueChanged(_that);case UiEvent_SettingsChanged() when settingsChanged != null:
return settingsChanged(_that);case UiEvent_DownloadsChanged() when downloadsChanged != null:
return downloadsChanged(_that);case UiEvent_Raise() when raise != null:
return raise(_that);case UiEvent_Quit() when quit != null:
return quit(_that);case UiEvent_Notice() when notice != null:
return notice(_that);case UiEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UiEvent_State value)  state,required TResult Function( UiEvent_Position value)  position,required TResult Function( UiEvent_TrackChanged value)  trackChanged,required TResult Function( UiEvent_QueueChanged value)  queueChanged,required TResult Function( UiEvent_SettingsChanged value)  settingsChanged,required TResult Function( UiEvent_DownloadsChanged value)  downloadsChanged,required TResult Function( UiEvent_Raise value)  raise,required TResult Function( UiEvent_Quit value)  quit,required TResult Function( UiEvent_Notice value)  notice,required TResult Function( UiEvent_Error value)  error,}){
final _that = this;
switch (_that) {
case UiEvent_State():
return state(_that);case UiEvent_Position():
return position(_that);case UiEvent_TrackChanged():
return trackChanged(_that);case UiEvent_QueueChanged():
return queueChanged(_that);case UiEvent_SettingsChanged():
return settingsChanged(_that);case UiEvent_DownloadsChanged():
return downloadsChanged(_that);case UiEvent_Raise():
return raise(_that);case UiEvent_Quit():
return quit(_that);case UiEvent_Notice():
return notice(_that);case UiEvent_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UiEvent_State value)?  state,TResult? Function( UiEvent_Position value)?  position,TResult? Function( UiEvent_TrackChanged value)?  trackChanged,TResult? Function( UiEvent_QueueChanged value)?  queueChanged,TResult? Function( UiEvent_SettingsChanged value)?  settingsChanged,TResult? Function( UiEvent_DownloadsChanged value)?  downloadsChanged,TResult? Function( UiEvent_Raise value)?  raise,TResult? Function( UiEvent_Quit value)?  quit,TResult? Function( UiEvent_Notice value)?  notice,TResult? Function( UiEvent_Error value)?  error,}){
final _that = this;
switch (_that) {
case UiEvent_State() when state != null:
return state(_that);case UiEvent_Position() when position != null:
return position(_that);case UiEvent_TrackChanged() when trackChanged != null:
return trackChanged(_that);case UiEvent_QueueChanged() when queueChanged != null:
return queueChanged(_that);case UiEvent_SettingsChanged() when settingsChanged != null:
return settingsChanged(_that);case UiEvent_DownloadsChanged() when downloadsChanged != null:
return downloadsChanged(_that);case UiEvent_Raise() when raise != null:
return raise(_that);case UiEvent_Quit() when quit != null:
return quit(_that);case UiEvent_Notice() when notice != null:
return notice(_that);case UiEvent_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PlayerState field0)?  state,TResult Function( PlatformInt64 positionMs,  PlatformInt64 durationMs,  double buffered)?  position,TResult Function( SongItem? field0)?  trackChanged,TResult Function()?  queueChanged,TResult Function()?  settingsChanged,TResult Function()?  downloadsChanged,TResult Function()?  raise,TResult Function()?  quit,TResult Function( String field0)?  notice,TResult Function( String field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UiEvent_State() when state != null:
return state(_that.field0);case UiEvent_Position() when position != null:
return position(_that.positionMs,_that.durationMs,_that.buffered);case UiEvent_TrackChanged() when trackChanged != null:
return trackChanged(_that.field0);case UiEvent_QueueChanged() when queueChanged != null:
return queueChanged();case UiEvent_SettingsChanged() when settingsChanged != null:
return settingsChanged();case UiEvent_DownloadsChanged() when downloadsChanged != null:
return downloadsChanged();case UiEvent_Raise() when raise != null:
return raise();case UiEvent_Quit() when quit != null:
return quit();case UiEvent_Notice() when notice != null:
return notice(_that.field0);case UiEvent_Error() when error != null:
return error(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PlayerState field0)  state,required TResult Function( PlatformInt64 positionMs,  PlatformInt64 durationMs,  double buffered)  position,required TResult Function( SongItem? field0)  trackChanged,required TResult Function()  queueChanged,required TResult Function()  settingsChanged,required TResult Function()  downloadsChanged,required TResult Function()  raise,required TResult Function()  quit,required TResult Function( String field0)  notice,required TResult Function( String field0)  error,}) {final _that = this;
switch (_that) {
case UiEvent_State():
return state(_that.field0);case UiEvent_Position():
return position(_that.positionMs,_that.durationMs,_that.buffered);case UiEvent_TrackChanged():
return trackChanged(_that.field0);case UiEvent_QueueChanged():
return queueChanged();case UiEvent_SettingsChanged():
return settingsChanged();case UiEvent_DownloadsChanged():
return downloadsChanged();case UiEvent_Raise():
return raise();case UiEvent_Quit():
return quit();case UiEvent_Notice():
return notice(_that.field0);case UiEvent_Error():
return error(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PlayerState field0)?  state,TResult? Function( PlatformInt64 positionMs,  PlatformInt64 durationMs,  double buffered)?  position,TResult? Function( SongItem? field0)?  trackChanged,TResult? Function()?  queueChanged,TResult? Function()?  settingsChanged,TResult? Function()?  downloadsChanged,TResult? Function()?  raise,TResult? Function()?  quit,TResult? Function( String field0)?  notice,TResult? Function( String field0)?  error,}) {final _that = this;
switch (_that) {
case UiEvent_State() when state != null:
return state(_that.field0);case UiEvent_Position() when position != null:
return position(_that.positionMs,_that.durationMs,_that.buffered);case UiEvent_TrackChanged() when trackChanged != null:
return trackChanged(_that.field0);case UiEvent_QueueChanged() when queueChanged != null:
return queueChanged();case UiEvent_SettingsChanged() when settingsChanged != null:
return settingsChanged();case UiEvent_DownloadsChanged() when downloadsChanged != null:
return downloadsChanged();case UiEvent_Raise() when raise != null:
return raise();case UiEvent_Quit() when quit != null:
return quit();case UiEvent_Notice() when notice != null:
return notice(_that.field0);case UiEvent_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class UiEvent_State extends UiEvent {
  const UiEvent_State(this.field0): super._();
  

 final  PlayerState field0;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_StateCopyWith<UiEvent_State> get copyWith => _$UiEvent_StateCopyWithImpl<UiEvent_State>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_State&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'UiEvent.state(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEvent_StateCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_StateCopyWith(UiEvent_State value, $Res Function(UiEvent_State) _then) = _$UiEvent_StateCopyWithImpl;
@useResult
$Res call({
 PlayerState field0
});




}
/// @nodoc
class _$UiEvent_StateCopyWithImpl<$Res>
    implements $UiEvent_StateCopyWith<$Res> {
  _$UiEvent_StateCopyWithImpl(this._self, this._then);

  final UiEvent_State _self;
  final $Res Function(UiEvent_State) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiEvent_State(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as PlayerState,
  ));
}


}

/// @nodoc


class UiEvent_Position extends UiEvent {
  const UiEvent_Position({required this.positionMs, required this.durationMs, required this.buffered}): super._();
  

 final  PlatformInt64 positionMs;
 final  PlatformInt64 durationMs;
 final  double buffered;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_PositionCopyWith<UiEvent_Position> get copyWith => _$UiEvent_PositionCopyWithImpl<UiEvent_Position>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Position&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.buffered, buffered) || other.buffered == buffered));
}


@override
int get hashCode {
    return Object.hash(runtimeType,positionMs,durationMs,buffered);
}

@override
String toString() {
    return 'UiEvent.position(positionMs: $positionMs, durationMs: $durationMs, buffered: $buffered)';
}


}

/// @nodoc
abstract mixin class $UiEvent_PositionCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_PositionCopyWith(UiEvent_Position value, $Res Function(UiEvent_Position) _then) = _$UiEvent_PositionCopyWithImpl;
@useResult
$Res call({
 PlatformInt64 positionMs, PlatformInt64 durationMs, double buffered
});




}
/// @nodoc
class _$UiEvent_PositionCopyWithImpl<$Res>
    implements $UiEvent_PositionCopyWith<$Res> {
  _$UiEvent_PositionCopyWithImpl(this._self, this._then);

  final UiEvent_Position _self;
  final $Res Function(UiEvent_Position) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? positionMs = null,Object? durationMs = null,Object? buffered = null,}) {
  return _then(UiEvent_Position(
positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as PlatformInt64,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as PlatformInt64,buffered: null == buffered ? _self.buffered : buffered // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class UiEvent_TrackChanged extends UiEvent {
  const UiEvent_TrackChanged([this.field0]): super._();
  

 final  SongItem? field0;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_TrackChangedCopyWith<UiEvent_TrackChanged> get copyWith => _$UiEvent_TrackChangedCopyWithImpl<UiEvent_TrackChanged>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_TrackChanged&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'UiEvent.trackChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEvent_TrackChangedCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_TrackChangedCopyWith(UiEvent_TrackChanged value, $Res Function(UiEvent_TrackChanged) _then) = _$UiEvent_TrackChangedCopyWithImpl;
@useResult
$Res call({
 SongItem? field0
});




}
/// @nodoc
class _$UiEvent_TrackChangedCopyWithImpl<$Res>
    implements $UiEvent_TrackChangedCopyWith<$Res> {
  _$UiEvent_TrackChangedCopyWithImpl(this._self, this._then);

  final UiEvent_TrackChanged _self;
  final $Res Function(UiEvent_TrackChanged) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = freezed,}) {
  return _then(UiEvent_TrackChanged(
freezed == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as SongItem?,
  ));
}


}

/// @nodoc


class UiEvent_QueueChanged extends UiEvent {
  const UiEvent_QueueChanged(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_QueueChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.queueChanged()';
}


}




/// @nodoc


class UiEvent_SettingsChanged extends UiEvent {
  const UiEvent_SettingsChanged(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_SettingsChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.settingsChanged()';
}


}




/// @nodoc


class UiEvent_DownloadsChanged extends UiEvent {
  const UiEvent_DownloadsChanged(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_DownloadsChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.downloadsChanged()';
}


}




/// @nodoc


class UiEvent_Raise extends UiEvent {
  const UiEvent_Raise(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Raise);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.raise()';
}


}




/// @nodoc


class UiEvent_Quit extends UiEvent {
  const UiEvent_Quit(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Quit);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'UiEvent.quit()';
}


}




/// @nodoc


class UiEvent_Notice extends UiEvent {
  const UiEvent_Notice(this.field0): super._();
  

 final  String field0;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_NoticeCopyWith<UiEvent_Notice> get copyWith => _$UiEvent_NoticeCopyWithImpl<UiEvent_Notice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Notice&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'UiEvent.notice(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEvent_NoticeCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_NoticeCopyWith(UiEvent_Notice value, $Res Function(UiEvent_Notice) _then) = _$UiEvent_NoticeCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$UiEvent_NoticeCopyWithImpl<$Res>
    implements $UiEvent_NoticeCopyWith<$Res> {
  _$UiEvent_NoticeCopyWithImpl(this._self, this._then);

  final UiEvent_Notice _self;
  final $Res Function(UiEvent_Notice) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiEvent_Notice(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class UiEvent_Error extends UiEvent {
  const UiEvent_Error(this.field0): super._();
  

 final  String field0;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UiEvent_ErrorCopyWith<UiEvent_Error> get copyWith => _$UiEvent_ErrorCopyWithImpl<UiEvent_Error>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UiEvent_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'UiEvent.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $UiEvent_ErrorCopyWith<$Res> implements $UiEventCopyWith<$Res> {
  factory $UiEvent_ErrorCopyWith(UiEvent_Error value, $Res Function(UiEvent_Error) _then) = _$UiEvent_ErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$UiEvent_ErrorCopyWithImpl<$Res>
    implements $UiEvent_ErrorCopyWith<$Res> {
  _$UiEvent_ErrorCopyWithImpl(this._self, this._then);

  final UiEvent_Error _self;
  final $Res Function(UiEvent_Error) _then;

/// Create a copy of UiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(UiEvent_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
