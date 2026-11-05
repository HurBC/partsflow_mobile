import 'package:flutter/services.dart';

/// Háptica de la app. Es independiente de "reducir animaciones".
abstract class PfHaptics {
  static void light() => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.mediumImpact();
  static void error() => HapticFeedback.heavyImpact();
}
