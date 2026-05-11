import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';

part 'result.freezed.dart';

@freezed
sealed class Result<T> with _$Result<T> {
  factory Result.ok(T value) = Ok<T>;
  factory Result.err(Failure failure) = Err<T>;
}
