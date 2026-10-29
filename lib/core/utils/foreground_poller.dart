import 'dart:async';

import 'package:flutter/widgets.dart';

/// Ejecuta [onTick] cada [interval] solo con la app en primer plano y mientras
/// [isEnabled] devuelva true. Al volver al primer plano dispara un tick.
class ForegroundPoller with WidgetsBindingObserver {
  ForegroundPoller({
    required this.interval,
    required this.onTick,
    this.isEnabled,
  });

  Duration interval;
  final VoidCallback onTick;
  final bool Function()? isEnabled;

  Timer? _timer;
  bool _foreground = true;

  bool get _active => _foreground && (isEnabled?.call() ?? true);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  /// Cambia la frecuencia (p. ej. al conectar/caer el tiempo real).
  void setInterval(Duration d) {
    if (d == interval) return;
    interval = d;
    if (_timer != null) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_active) onTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg && !_foreground && (isEnabled?.call() ?? true)) onTick();
    _foreground = fg;
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
