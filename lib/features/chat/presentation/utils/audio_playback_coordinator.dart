/// Algo que puede estar sonando y que se puede pausar.
abstract interface class PausableAudio {
  Future<void> pause();
}

/// Garantiza un solo audio sonando a la vez.
///
/// Decisión: el audio desplazado se PAUSA (no se libera). Así conserva
/// posición y archivo cargado y reanudar es instantáneo (sin re-descargar ni
/// re-preparar); su AudioPlayer se libera cuando su burbuja se desmonta.
class AudioPlaybackCoordinator {
  PausableAudio? _current;

  PausableAudio? get current => _current;

  /// Llamar justo antes de reproducir [next]: pausa el que sonaba.
  void claim(PausableAudio next) {
    final prev = _current;
    _current = next;
    if (prev != null && !identical(prev, next)) {
      prev.pause().catchError((Object _) {});
    }
  }

  /// Llamar al desmontar/liberar [p].
  void release(PausableAudio p) {
    if (identical(_current, p)) _current = null;
  }
}
