import 'package:partsflow_mobile/core/realtime/realtime_event.dart';

/// Agrupa los [RealtimeResync] que llegan dentro de [window] (cada socket
/// emite uno al conectar, así que una reconexión produce varios): pasa el
/// primero y descarta los demás de la ventana. El resto de eventos pasa igual.
class ResyncCoalescer {
  ResyncCoalescer({
    required this.sink,
    this.window = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final void Function(RealtimeEvent) sink;
  final Duration window;
  final DateTime Function() _now;
  DateTime? _lastResync;

  void add(RealtimeEvent e) {
    if (e is RealtimeResync) {
      final t = _now();
      final last = _lastResync;
      if (last != null && t.difference(last) < window) return;
      _lastResync = t;
    }
    sink(e);
  }
}
