/// Usuario de SAPI (`users/?cognito_id=<sub>`): su `id` es el que usan
/// `client_responsible`, `responsible` y `responsible_id`.
class ApiUser {
  const ApiUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName'.trim();
}
