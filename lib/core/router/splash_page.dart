import 'package:flutter/material.dart';

/// Pantalla mínima mientras se resuelve la sesión: logo centrado sobre el
/// fondo del tema (coincide con el splash nativo, sin montar el shell).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/images/partsflow_logo_circular.png',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
