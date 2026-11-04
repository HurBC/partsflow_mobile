import 'package:flutter/widgets.dart';

/// Expone el índice de la tab activa del shell. Las páginas de cada rama
/// (que siguen vivas en el IndexedStack) lo usan para pausar pollers cuando
/// su tab está oculta y refrescar al volver a mostrarse.
class TabVisibility extends InheritedModel<int> {
  const TabVisibility({
    super.key,
    required this.activeIndex,
    required super.child,
  });

  final int activeIndex;

  /// true si [tab] es la visible. Sin shell (tests) cuenta como visible.
  /// Solo se reconstruye cuando cambia la visibilidad de [tab].
  static bool isActive(BuildContext context, int tab) {
    final model = InheritedModel.inheritFrom<TabVisibility>(
      context,
      aspect: tab,
    );
    return model == null || model.activeIndex == tab;
  }

  @override
  bool updateShouldNotify(TabVisibility old) => old.activeIndex != activeIndex;

  @override
  bool updateShouldNotifyDependent(TabVisibility old, Set<int> dependencies) =>
      dependencies.any((t) => (old.activeIndex == t) != (activeIndex == t));
}
