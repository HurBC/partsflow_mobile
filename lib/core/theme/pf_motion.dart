import 'package:flutter/animation.dart';

/// Duraciones y curvas de movimiento reutilizables.
abstract class PfMotion {
  // Aviso (PfToast).
  static const toastEnter = Duration(milliseconds: 480);
  static const toastExit = Duration(milliseconds: 220);
  static const toastChipPop = Duration(milliseconds: 440);
  static const toastChipDelay = Duration(milliseconds: 110);
  static const toastIconDelay = Duration(milliseconds: 300);

  // Toggle de Julia (PfSwitch / píldora / indicador).
  static const switchKnob = Duration(milliseconds: 340);
  static const switchTrack = Duration(milliseconds: 260);
  static const switchIconPop = Duration(milliseconds: 380);
  static const switchBurst = Duration(milliseconds: 520);
  static const juliaPill = Duration(milliseconds: 300);
  static const juliaPillRing = Duration(milliseconds: 700);
  static const juliaDots = Duration(milliseconds: 1100);
  static const juliaDotStagger = Duration(milliseconds: 150);
  static const juliaSpin = Duration(milliseconds: 2400);
  static const juliaWorkingEnter = Duration(milliseconds: 300);
  static const juliaWorkingExit = Duration(milliseconds: 200);

  /// Con "reducir animaciones" solo hay fundido.
  static const reducedFade = Duration(milliseconds: 160);

  /// Rebote de entrada ≈ cubic(.34, 1.56, .64, 1).
  static const Curve overshoot = Curves.easeOutBack;
  static const Curve exit = Curves.easeIn;
}
