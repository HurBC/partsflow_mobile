class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.name,
    required this.familyName,
    required this.subsidiaryId,
    required this.subsidiaryName,
    required this.supplierName,
    required this.schemaName,
  });

  final String id;
  final String email;
  final String name;
  final String familyName;
  final String subsidiaryId;
  final String subsidiaryName;
  final String supplierName;
  final String schemaName;

  String get fullName => '$name $familyName'.trim();

  /// Iniciales para el avatar; cae al correo si no hay nombre.
  String get initials {
    final first = name.trim();
    final last = familyName.trim();
    final letters =
        '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}';
    if (letters.isNotEmpty) return letters.toUpperCase();
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }
}
