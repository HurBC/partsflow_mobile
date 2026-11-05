import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pantalla (ruta) a la que pertenece un aviso y si sigue siendo la visible.
///
/// Se resuelve al capturar el contexto: la ruta de página más cercana y las de
/// los navegadores que la contienen (p. ej. la del shell de pestañas), más el
/// estado de tickers de la rama (pestaña oculta en un IndexedStack). Una hoja o
/// un diálogo (PopupRoute) encima no cuentan como "cubierta"; una página sí.
@immutable
class PfToastOwner {
  const PfToastOwner._(this._routes, this._ticker, this._popup);

  final List<ModalRoute<dynamic>> _routes;

  /// Hoja/diálogo desde el que se mostró (no dueño: su cierre no descarta el
  /// aviso), pero si otra ruta se apila encima mientras sigue abierto, el aviso
  /// queda cubierto. No hay API pública para hallar la página de abajo.
  final PopupRoute<dynamic>? _popup;
  final ValueListenable<TickerModeData>? _ticker;

  /// Sin rutas ni TickerMode (p. ej. contexto sin navegador): siempre visible.
  static PfToastOwner of(BuildContext context) {
    final routes = <ModalRoute<dynamic>>[];
    BuildContext? ctx = context;
    var first = true;
    PopupRoute<dynamic>? popup;
    while (ctx != null && ctx.mounted) {
      final r = ModalRoute.of(ctx);
      if (r == null) break;
      // Una hoja/diálogo no es dueña: su cierre no debe llevarse el aviso.
      if (first && r is PopupRoute) {
        popup = r;
      } else {
        routes.add(r);
      }
      first = false;
      final nav = r.navigator;
      ctx = nav != null && nav.mounted ? nav.context : null;
    }
    return PfToastOwner._(routes, TickerMode.getValuesNotifier(context), popup);
  }

  /// true si todas las rutas dueñas siguen activas, sin cerrarse ni quedar
  /// cubiertas por otra página, y la rama no está oculta.
  bool get visible {
    if (_ticker != null && !_ticker.value.enabled) return false;
    final pop = _popup;
    if (pop != null && pop.isActive && !pop.isCurrent) return false;
    for (final r in _routes) {
      if (!r.isActive) return false;
      if (r.animation?.status == AnimationStatus.reverse ||
          r.animation?.status == AnimationStatus.dismissed) {
        return false;
      }
      final sec = r.secondaryAnimation;
      if (sec != null && sec.status != AnimationStatus.dismissed) return false;
    }
    return true;
  }

  /// Avisa cuando algo que afecta a [visible] cambia. Devuelve la baja.
  VoidCallback watch(VoidCallback onChange) {
    void status(AnimationStatus _) => onChange();
    final anims = <Animation<double>>[
      for (final r in _routes) ...[?r.animation, ?r.secondaryAnimation],
    ];
    for (final a in anims) {
      a.addStatusListener(status);
    }
    _ticker?.addListener(onChange);
    // Apilar una ruta sobre la hoja no cambia ninguna animación: se revisa en
    // cada cuadro (los hay mientras el aviso anima/cuenta).
    var stopped = false;
    void frame(Duration _) {
      if (stopped) return;
      onChange();
      SchedulerBinding.instance.addPostFrameCallback(frame);
    }

    if (_popup != null) SchedulerBinding.instance.addPostFrameCallback(frame);
    return () {
      stopped = true;
      for (final a in anims) {
        try {
          a.removeStatusListener(status);
        } catch (_) {}
      }
      try {
        _ticker?.removeListener(onChange);
      } catch (_) {}
    };
  }
}
