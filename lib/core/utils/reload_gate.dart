import 'dart:async';

/// Política de recargas automáticas (Resync, sondeo, volver a primer plano):
/// se omiten si ya hay una carga en vuelo (se reutiliza) o si la última carga
/// exitosa terminó hace menos de [cooldown]. Las recargas explícitas del
/// usuario pasan por [track]: nunca se omiten, pero cuentan como en vuelo y,
/// al terminar bien ([markSuccess]), reinician el cooldown.
class ReloadGate {
  ReloadGate({
    this.cooldown = const Duration(seconds: 5),
    Duration? signalGap,
    DateTime Function()? now,
  }) : signalGap = signalGap ?? cooldown,
       _now = now ?? DateTime.now;

  final Duration cooldown;

  /// Espaciado mínimo entre cargas disparadas por [signal] (independiente del
  /// [cooldown] de [auto]). Por defecto igual a [cooldown].
  final Duration signalGap;
  final DateTime Function() _now;

  Future<void>? _inFlight;
  DateTime? _lastOk;

  bool get inFlight => _inFlight != null;

  /// Llamar cuando una carga termina con éxito.
  void markSuccess() => _lastOk = _now();

  bool get _fresh => _lastOk != null && _now().difference(_lastOk!) < cooldown;

  bool get _signalFresh =>
      _lastOk != null && _now().difference(_lastOk!) < signalGap;

  /// Carga explícita: siempre se ejecuta; queda registrada como en vuelo.
  Future<T> track<T>(Future<T> Function() load) {
    final f = load();
    late final Future<void> marker;
    marker = f.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inFlight, marker)) {
        _inFlight = null;
        _runPending();
      }
    });
    _inFlight = marker;
    return f;
  }

  /// Carga automática: reutiliza la que está en vuelo o se omite si hay una
  /// carga exitosa reciente.
  Future<void> auto(Future<void> Function() load) {
    final running = _inFlight;
    if (running != null) return running;
    if (_fresh) return Future.value();
    return track(load);
  }

  // ---- Señal de datos nuevos ------------------------------------------------

  Future<void> Function()? _pending;
  Timer? _timer;
  bool _disposed = false;

  /// Recarga por señal de datos nuevos (evento realtime): nunca se pierde, se
  /// coalesce. Con carga en vuelo queda UNA pendiente que corre al terminar
  /// (la en vuelo pudo empezar antes del evento); dentro de [signalGap] se
  /// programa UNA al cumplirse; si no, corre ya. Una trailing fallida no se
  /// reintenta (lo cubre el siguiente evento o el sondeo).
  void signal(Future<void> Function() load) {
    if (_disposed) return;
    if (_inFlight != null) {
      _pending = load;
      return;
    }
    if (_signalFresh) {
      _pending = load;
      _timer ??= Timer(signalGap - _now().difference(_lastOk!), () {
        _timer = null;
        _runPending();
      });
      return;
    }
    _run(load);
  }

  void _runPending() {
    final load = _pending;
    if (load == null || _disposed || _timer != null) return;
    _pending = null;
    _run(load);
  }

  void _run(Future<void> Function() load) {
    track(load).catchError((Object _) {});
  }

  /// Cancela el timer y la recarga pendiente.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
