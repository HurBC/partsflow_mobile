import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast_owner.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast_scope.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast_view.dart';

export 'package:partsflow_mobile/core/ui/toast/pf_toast_scope.dart';

enum PfToastKind { success, julia, info, warning, error, loading }

/// Destino de un aviso que no necesita un BuildContext vivo: el overlay raíz,
/// la separación inferior y la pantalla dueña, capturados antes de un await/pop.
/// Sin [owner] el aviso no pertenece a ninguna pantalla (siempre visible).
@immutable
class PfToastTarget {
  const PfToastTarget(this.overlay, this.bottomClearance, [this.owner]);

  final OverlayState overlay;
  final double bottomClearance;
  final PfToastOwner? owner;
}

/// Identifica un aviso mostrado (para cerrarlo solo si sigue vigente).
class PfToastHandle {
  PfToastHandle._();

  late final OverlayEntry _entry;
  VoidCallback? _animateOut;
  bool _removed = false;
  VoidCallback? _unwatch;

  void _remove() {
    if (_removed) return;
    _removed = true;
    _unwatch?.call();
    _unwatch = null;
    if (identical(PfToast._active, this)) PfToast._active = null;
    _entry.remove(); // no-op si el overlay ya no lo tiene (no usar `mounted`)
    _entry.dispose();
  }
}

/// Aviso compacto y expresivo que reemplaza a los avisos de Material. Uno a la vez.
abstract final class PfToast {
  static PfToastHandle? _active;

  static Duration? _autoClose(PfToastKind kind, String? actionLabel) {
    if (actionLabel != null) return null;
    return switch (kind) {
      PfToastKind.success ||
      PfToastKind.julia => const Duration(milliseconds: 2200),
      PfToastKind.info => const Duration(seconds: 3),
      PfToastKind.warning => const Duration(milliseconds: 4500),
      PfToastKind.error => const Duration(seconds: 5),
      PfToastKind.loading => null,
    };
  }

  /// Captura overlay raíz + separación inferior (scope o [bottomClearance]) +
  /// pantalla dueña (la ruta desde la que se muestra).
  /// Null si no hay overlay.
  static PfToastTarget? capture(
    BuildContext context, {
    double? bottomClearance,
  }) {
    if (!context.mounted) return null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
    return PfToastTarget(
      overlay,
      bottomClearance ?? PfToastScope.clearanceOf(context),
      PfToastOwner.of(context),
    );
  }

  /// Muestra el aviso en el overlay raíz; reemplaza al actual (sin apilar).
  /// Con [actionLabel] no se cierra solo. [icon] reemplaza el ícono del tipo.
  /// [bottomClearance] reemplaza al del [PfToastScope].
  static PfToastHandle? show(
    BuildContext context,
    String title, {
    String? body,
    PfToastKind kind = PfToastKind.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double? bottomClearance,
  }) {
    final target = capture(context, bottomClearance: bottomClearance);
    if (target == null) return null;
    return showOn(
      target,
      title,
      body: body,
      kind: kind,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Como [show] pero sobre un [PfToastTarget] capturado antes (el contexto
  /// original puede haberse desmontado).
  static PfToastHandle? showOn(
    PfToastTarget target,
    String title, {
    String? body,
    PfToastKind kind = PfToastKind.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    if (title.isEmpty || !target.overlay.mounted) return null;
    // La pantalla dueña ya se cerró o quedó cubierta/oculta: no se muestra.
    if (!(target.owner?.visible ?? true)) return null;
    final auto = actionLabel != null || kind == PfToastKind.loading
        ? null
        : (duration ?? _autoClose(kind, actionLabel));

    _removeActive();
    final handle = PfToastHandle._();
    handle._entry = OverlayEntry(
      builder: (_) => PfToastView(
        title: title,
        body: body,
        kind: kind,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        autoClose: auto,
        bottomClearance: target.bottomClearance,
        onReady: (animateOut) => handle._animateOut = animateOut,
        onClosed: handle._remove,
        isCurrent: () => identical(_active, handle),
      ),
    );
    _active = handle;
    target.overlay.insert(handle._entry);
    handle._unwatch = target.owner?.watch(() {
      if (!(target.owner?.visible ?? true)) dismissIfCurrent(handle);
    });
    return handle;
  }

  /// Cierra [handle] (con animación) solo si sigue siendo el aviso actual.
  static void dismissIfCurrent(PfToastHandle? handle) {
    if (handle != null && identical(_active, handle)) dismiss();
  }

  /// Cierra el aviso actual con su animación de salida.
  static void dismiss() {
    final a = _active;
    if (a == null) return;
    final out = a._animateOut;
    if (out != null) {
      out();
    } else {
      _removeActive();
    }
  }

  static void _removeActive() {
    _active?._remove();
  }
}
