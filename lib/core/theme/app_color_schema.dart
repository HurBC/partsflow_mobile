import 'package:flutter/material.dart';

abstract class AppColorSchema {
  static const _seedColor = Color(0xFF181D84);

  static final light = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
  );

  static final dark = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  );
}
