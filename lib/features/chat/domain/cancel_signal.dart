import 'dart:async';

/// Señal de cancelación mínima e independiente de Dio. Presentation la crea y
/// la pasa al repositorio (domain); la capa data la traduce a su propio token
/// HTTP (`CancelToken`), así domain no depende de la librería de red.
class CancelSignal {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Se completa al cancelar (nunca con error).
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
