import 'package:flutter/material.dart';

abstract class AppColorSchema {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF181D84),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF43DBAD),
    onSecondary: Color(0xFF181D84),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F1222),
    onSurfaceVariant: Color(0xFF5B6275),
    outline: Color(0xFFD3D6E4),
    outlineVariant: Color(0xFFECEEF5),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3F4F9),
    surfaceContainer: Color(0xFFF3F4F9),
    surfaceContainerHigh: Color(0xFFECEEF5),
    surfaceContainerHighest: Color(0xFFE4E6F7),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF43DBAD),
    onPrimary: Color(0xFF0E1133),
    secondary: Color(0xFF43DBAD),
    onSecondary: Color(0xFF0E1133),
    error: Color(0xFFFF9EA2),
    onError: Color(0xFF0E1133),
    surface: Color(0xFF171B45),
    onSurface: Color(0xFFEEF0FF),
    onSurfaceVariant: Color(0xFFA9AFDA),
    outline: Color(0xFF2C3270),
    outlineVariant: Color(0xFF232859),
    surfaceContainerLowest: Color(0xFF0E1133),
    surfaceContainerLow: Color(0xFF171B45),
    surfaceContainer: Color(0xFF171B45),
    surfaceContainerHigh: Color(0xFF1F2456),
    surfaceContainerHighest: Color(0xFF2C3270),
  );
}
