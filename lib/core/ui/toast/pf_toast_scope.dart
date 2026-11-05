import 'package:flutter/widgets.dart';

/// Declara cuánto espacio inferior no debe taparse con un [PfToast] mostrado
/// desde este subárbol (composer, barra de navegación, botón fijo...).
class PfToastScope extends InheritedWidget {
  const PfToastScope({
    super.key,
    required this.bottomClearance,
    required super.child,
  });

  final double bottomClearance;

  /// Valor por defecto cuando no hay scope.
  static const defaultClearance = 16.0;

  static double clearanceOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PfToastScope>()?.bottomClearance ??
      defaultClearance;

  @override
  bool updateShouldNotify(PfToastScope old) =>
      old.bottomClearance != bottomClearance;
}
