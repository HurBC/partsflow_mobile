import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  factory Failure.validationForms(Map<String, List<String>> fields) =
      ValidationFormFailure;
  factory Failure.network() = NetworkFailure;
  factory Failure.server() = ServerFailure;
  factory Failure.unauthorization() = UnauthorizatedFailure;
  factory Failure.unknown() = UnknownFailure;

  /// Error con motivo legible (p. ej. "HTTP 400: detalle") para mostrar en la UI.
  factory Failure.http(int? status, String reason) = HttpFailure;
  factory Failure.invalidCredentials() = InvalidCredentialsFailure;
  factory Failure.temporaryPasswordExpired() = TemporaryPasswordExpiredFailure;
}
