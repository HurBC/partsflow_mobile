// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Failure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Failure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure()';
}


}

/// @nodoc
class $FailureCopyWith<$Res>  {
$FailureCopyWith(Failure _, $Res Function(Failure) __);
}


/// Adds pattern-matching-related methods to [Failure].
extension FailurePatterns on Failure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ValidationFormFailure value)?  validationForms,TResult Function( NetworkFailure value)?  network,TResult Function( ServerFailure value)?  server,TResult Function( UnauthorizatedFailure value)?  unauthorization,TResult Function( UnknownFailure value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ValidationFormFailure() when validationForms != null:
return validationForms(_that);case NetworkFailure() when network != null:
return network(_that);case ServerFailure() when server != null:
return server(_that);case UnauthorizatedFailure() when unauthorization != null:
return unauthorization(_that);case UnknownFailure() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ValidationFormFailure value)  validationForms,required TResult Function( NetworkFailure value)  network,required TResult Function( ServerFailure value)  server,required TResult Function( UnauthorizatedFailure value)  unauthorization,required TResult Function( UnknownFailure value)  unknown,}){
final _that = this;
switch (_that) {
case ValidationFormFailure():
return validationForms(_that);case NetworkFailure():
return network(_that);case ServerFailure():
return server(_that);case UnauthorizatedFailure():
return unauthorization(_that);case UnknownFailure():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ValidationFormFailure value)?  validationForms,TResult? Function( NetworkFailure value)?  network,TResult? Function( ServerFailure value)?  server,TResult? Function( UnauthorizatedFailure value)?  unauthorization,TResult? Function( UnknownFailure value)?  unknown,}){
final _that = this;
switch (_that) {
case ValidationFormFailure() when validationForms != null:
return validationForms(_that);case NetworkFailure() when network != null:
return network(_that);case ServerFailure() when server != null:
return server(_that);case UnauthorizatedFailure() when unauthorization != null:
return unauthorization(_that);case UnknownFailure() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Map<String, List<String>> fields)?  validationForms,TResult Function()?  network,TResult Function()?  server,TResult Function()?  unauthorization,TResult Function()?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ValidationFormFailure() when validationForms != null:
return validationForms(_that.fields);case NetworkFailure() when network != null:
return network();case ServerFailure() when server != null:
return server();case UnauthorizatedFailure() when unauthorization != null:
return unauthorization();case UnknownFailure() when unknown != null:
return unknown();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Map<String, List<String>> fields)  validationForms,required TResult Function()  network,required TResult Function()  server,required TResult Function()  unauthorization,required TResult Function()  unknown,}) {final _that = this;
switch (_that) {
case ValidationFormFailure():
return validationForms(_that.fields);case NetworkFailure():
return network();case ServerFailure():
return server();case UnauthorizatedFailure():
return unauthorization();case UnknownFailure():
return unknown();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Map<String, List<String>> fields)?  validationForms,TResult? Function()?  network,TResult? Function()?  server,TResult? Function()?  unauthorization,TResult? Function()?  unknown,}) {final _that = this;
switch (_that) {
case ValidationFormFailure() when validationForms != null:
return validationForms(_that.fields);case NetworkFailure() when network != null:
return network();case ServerFailure() when server != null:
return server();case UnauthorizatedFailure() when unauthorization != null:
return unauthorization();case UnknownFailure() when unknown != null:
return unknown();case _:
  return null;

}
}

}

/// @nodoc


class ValidationFormFailure implements Failure {
   ValidationFormFailure(final  Map<String, List<String>> fields): _fields = fields;
  

 final  Map<String, List<String>> _fields;
 Map<String, List<String>> get fields {
  if (_fields is EqualUnmodifiableMapView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fields);
}


/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidationFormFailureCopyWith<ValidationFormFailure> get copyWith => _$ValidationFormFailureCopyWithImpl<ValidationFormFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidationFormFailure&&const DeepCollectionEquality().equals(other._fields, _fields));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_fields));

@override
String toString() {
  return 'Failure.validationForms(fields: $fields)';
}


}

/// @nodoc
abstract mixin class $ValidationFormFailureCopyWith<$Res> implements $FailureCopyWith<$Res> {
  factory $ValidationFormFailureCopyWith(ValidationFormFailure value, $Res Function(ValidationFormFailure) _then) = _$ValidationFormFailureCopyWithImpl;
@useResult
$Res call({
 Map<String, List<String>> fields
});




}
/// @nodoc
class _$ValidationFormFailureCopyWithImpl<$Res>
    implements $ValidationFormFailureCopyWith<$Res> {
  _$ValidationFormFailureCopyWithImpl(this._self, this._then);

  final ValidationFormFailure _self;
  final $Res Function(ValidationFormFailure) _then;

/// Create a copy of Failure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fields = null,}) {
  return _then(ValidationFormFailure(
null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, List<String>>,
  ));
}


}

/// @nodoc


class NetworkFailure implements Failure {
   NetworkFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.network()';
}


}




/// @nodoc


class ServerFailure implements Failure {
   ServerFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.server()';
}


}




/// @nodoc


class UnauthorizatedFailure implements Failure {
   UnauthorizatedFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnauthorizatedFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.unauthorization()';
}


}




/// @nodoc


class UnknownFailure implements Failure {
   UnknownFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Failure.unknown()';
}


}




// dart format on
