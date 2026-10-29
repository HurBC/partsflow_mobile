sealed class LoginOutcome {
  const LoginOutcome();
}

/// Sesión iniciada: los tokens ya quedaron guardados.
class LoggedIn extends LoginOutcome {
  const LoggedIn();
}

/// La cuenta tiene contraseña temporal: hay que crear una definitiva.
class NewPasswordRequired extends LoginOutcome {
  const NewPasswordRequired({required this.email, required this.session});

  final String email;
  final String session;
}
