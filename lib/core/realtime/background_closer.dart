import 'dart:async';

/// Política de cierre en segundo plano: tras [delay] seguidos en background
/// llama a [onClose]; si la app vuelve antes, cancela. [onForeground] devuelve
/// true si hubo cierre (hay que reabrir).
class BackgroundCloser {
  BackgroundCloser({
    required this.onClose,
    this.delay = const Duration(seconds: 45),
  });

  final void Function() onClose;
  final Duration delay;

  Timer? _timer;
  bool _closed = false;

  void onBackground() {
    if (_closed || _timer != null) return;
    _timer = Timer(delay, () {
      _timer = null;
      _closed = true;
      onClose();
    });
  }

  bool onForeground() {
    _timer?.cancel();
    _timer = null;
    final was = _closed;
    _closed = false;
    return was;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
