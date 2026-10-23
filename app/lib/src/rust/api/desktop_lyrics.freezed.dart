// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_lyrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DesktopLyricsEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopLyricsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DesktopLyricsEvent()';
}


}

/// @nodoc
class $DesktopLyricsEventCopyWith<$Res>  {
$DesktopLyricsEventCopyWith(DesktopLyricsEvent _, $Res Function(DesktopLyricsEvent) __);
}


/// Adds pattern-matching-related methods to [DesktopLyricsEvent].
extension DesktopLyricsEventPatterns on DesktopLyricsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DesktopLyricsEvent_Track value)?  track,TResult Function( DesktopLyricsEvent_Position value)?  position,TResult Function( DesktopLyricsEvent_Closed value)?  closed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track() when track != null:
return track(_that);case DesktopLyricsEvent_Position() when position != null:
return position(_that);case DesktopLyricsEvent_Closed() when closed != null:
return closed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DesktopLyricsEvent_Track value)  track,required TResult Function( DesktopLyricsEvent_Position value)  position,required TResult Function( DesktopLyricsEvent_Closed value)  closed,}){
final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track():
return track(_that);case DesktopLyricsEvent_Position():
return position(_that);case DesktopLyricsEvent_Closed():
return closed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DesktopLyricsEvent_Track value)?  track,TResult? Function( DesktopLyricsEvent_Position value)?  position,TResult? Function( DesktopLyricsEvent_Closed value)?  closed,}){
final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track() when track != null:
return track(_that);case DesktopLyricsEvent_Position() when position != null:
return position(_that);case DesktopLyricsEvent_Closed() when closed != null:
return closed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String title,  String artist,  List<LyricItem> lines)?  track,TResult Function( PlatformInt64 ms,  bool playing)?  position,TResult Function()?  closed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track() when track != null:
return track(_that.title,_that.artist,_that.lines);case DesktopLyricsEvent_Position() when position != null:
return position(_that.ms,_that.playing);case DesktopLyricsEvent_Closed() when closed != null:
return closed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String title,  String artist,  List<LyricItem> lines)  track,required TResult Function( PlatformInt64 ms,  bool playing)  position,required TResult Function()  closed,}) {final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track():
return track(_that.title,_that.artist,_that.lines);case DesktopLyricsEvent_Position():
return position(_that.ms,_that.playing);case DesktopLyricsEvent_Closed():
return closed();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String title,  String artist,  List<LyricItem> lines)?  track,TResult? Function( PlatformInt64 ms,  bool playing)?  position,TResult? Function()?  closed,}) {final _that = this;
switch (_that) {
case DesktopLyricsEvent_Track() when track != null:
return track(_that.title,_that.artist,_that.lines);case DesktopLyricsEvent_Position() when position != null:
return position(_that.ms,_that.playing);case DesktopLyricsEvent_Closed() when closed != null:
return closed();case _:
  return null;

}
}

}

/// @nodoc


class DesktopLyricsEvent_Track extends DesktopLyricsEvent {
  const DesktopLyricsEvent_Track({required this.title, required this.artist, required  List<LyricItem> lines}): _lines = lines,super._();
  

 final  String title;
 final  String artist;
 final  List<LyricItem> _lines;
 List<LyricItem> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of DesktopLyricsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopLyricsEvent_TrackCopyWith<DesktopLyricsEvent_Track> get copyWith => _$DesktopLyricsEvent_TrackCopyWithImpl<DesktopLyricsEvent_Track>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopLyricsEvent_Track&&(identical(other.title, title) || other.title == title)&&(identical(other.artist, artist) || other.artist == artist)&&const DeepCollectionEquality().equals(other.lines, _lines));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,artist,const DeepCollectionEquality().hash(_lines));
}

@override
String toString() {
    return 'DesktopLyricsEvent.track(title: $title, artist: $artist, lines: $lines)';
}


}

/// @nodoc
abstract mixin class $DesktopLyricsEvent_TrackCopyWith<$Res> implements $DesktopLyricsEventCopyWith<$Res> {
  factory $DesktopLyricsEvent_TrackCopyWith(DesktopLyricsEvent_Track value, $Res Function(DesktopLyricsEvent_Track) _then) = _$DesktopLyricsEvent_TrackCopyWithImpl;
@useResult
$Res call({
 String title, String artist, List<LyricItem> lines
});




}
/// @nodoc
class _$DesktopLyricsEvent_TrackCopyWithImpl<$Res>
    implements $DesktopLyricsEvent_TrackCopyWith<$Res> {
  _$DesktopLyricsEvent_TrackCopyWithImpl(this._self, this._then);

  final DesktopLyricsEvent_Track _self;
  final $Res Function(DesktopLyricsEvent_Track) _then;

/// Create a copy of DesktopLyricsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = null,Object? artist = null,Object? lines = null,}) {
  return _then(DesktopLyricsEvent_Track(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<LyricItem>,
  ));
}


}

/// @nodoc


class DesktopLyricsEvent_Position extends DesktopLyricsEvent {
  const DesktopLyricsEvent_Position({required this.ms, required this.playing}): super._();
  

 final  PlatformInt64 ms;
 final  bool playing;

/// Create a copy of DesktopLyricsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopLyricsEvent_PositionCopyWith<DesktopLyricsEvent_Position> get copyWith => _$DesktopLyricsEvent_PositionCopyWithImpl<DesktopLyricsEvent_Position>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopLyricsEvent_Position&&(identical(other.ms, ms) || other.ms == ms)&&(identical(other.playing, playing) || other.playing == playing));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ms,playing);
}

@override
String toString() {
    return 'DesktopLyricsEvent.position(ms: $ms, playing: $playing)';
}


}

/// @nodoc
abstract mixin class $DesktopLyricsEvent_PositionCopyWith<$Res> implements $DesktopLyricsEventCopyWith<$Res> {
  factory $DesktopLyricsEvent_PositionCopyWith(DesktopLyricsEvent_Position value, $Res Function(DesktopLyricsEvent_Position) _then) = _$DesktopLyricsEvent_PositionCopyWithImpl;
@useResult
$Res call({
 PlatformInt64 ms, bool playing
});




}
/// @nodoc
class _$DesktopLyricsEvent_PositionCopyWithImpl<$Res>
    implements $DesktopLyricsEvent_PositionCopyWith<$Res> {
  _$DesktopLyricsEvent_PositionCopyWithImpl(this._self, this._then);

  final DesktopLyricsEvent_Position _self;
  final $Res Function(DesktopLyricsEvent_Position) _then;

/// Create a copy of DesktopLyricsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ms = null,Object? playing = null,}) {
  return _then(DesktopLyricsEvent_Position(
ms: null == ms ? _self.ms : ms // ignore: cast_nullable_to_non_nullable
as PlatformInt64,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class DesktopLyricsEvent_Closed extends DesktopLyricsEvent {
  const DesktopLyricsEvent_Closed(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopLyricsEvent_Closed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DesktopLyricsEvent.closed()';
}


}




// dart format on
