import 'package:flutter/animation.dart';

/// Duraciones y curvas de movimiento reutilizables.
abstract class PfMotion {
  // Aviso (PfToast).
  static const toastEnter = Duration(milliseconds: 480);
  static const toastExit = Duration(milliseconds: 220);
  static const toastChipPop = Duration(milliseconds: 440);
  static const toastChipDelay = Duration(milliseconds: 110);
  static const toastIconDelay = Duration(milliseconds: 300);

  /// Con "reducir animaciones" solo hay fundido.
  static const reducedFade = Duration(milliseconds: 160);

  /// Rebote de entrada ≈ cubic(.34, 1.56, .64, 1).
  static const Curve overshoot = Curves.easeOutBack;
  static const Curve exit = Curves.easeIn;
}
