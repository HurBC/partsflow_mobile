import 'dart:math' as math;

/// Piso de la escala de amplitud (dBFS). Por debajo se considera silencio.
const double waveformFloorDb = -50;

/// Barras de la onda en vivo (composer) y de la onda de la burbuja.
const int liveWaveformBars = 24;
const int bubbleWaveformBars = 28;

/// dBFS (≤ 0) → 0..1 lineal entre [floorDb] y 0. NaN/-inf → 0.
double normalizeDb(double db, {double floorDb = waveformFloorDb}) {
  if (db.isNaN || db <= floorDb) return 0;
  if (db >= 0) return 1;
  return (db - floorDb) / -floorDb;
}

/// Reduce [samples] (0..1) a [bars] barras promediando cada tramo. Con menos
/// muestras que barras, repite la última de forma proporcional. Vacío → vacío.
List<double> downsampleWaveform(
  List<double> samples, {
  int bars = bubbleWaveformBars,
}) {
  if (samples.isEmpty || bars <= 0) return const [];
  final out = List<double>.filled(bars, 0);
  for (var i = 0; i < bars; i++) {
    final start = (i * samples.length / bars).floor();
    final end = math.max(start + 1, ((i + 1) * samples.length / bars).floor());
    var sum = 0.0;
    var n = 0;
    for (var j = start; j < end && j < samples.length; j++) {
      sum += samples[j];
      n++;
    }
    out[i] = n == 0 ? samples.last : sum / n;
  }
  return out;
}

const int maxLinkedWaveforms = 200;

/// Ondas de audios PROPIOS, solo en memoria de sesión (no persisten).
///
/// Clave estable: el mensaje pendiente (`local-…`) y el definitivo no
/// comparten id. Se registra por `localPath` (lo que tiene el pendiente) y,
/// al confirmar el envío, el controlador enlaza el id real del mensaje
/// recién aparecido. Límite: si el servidor devuelve el mensaje por una vía que
/// no se detecta como "nuevo" (p. ej. carrera con otro audio propio enviado
/// desde otro dispositivo en la misma ventana), la burbuja queda sin onda.
class AudioWaveformStore {
  final Map<String, List<double>> _byPath = {};
  final Map<String, List<double>> _byMessageId = {};

  void putForPath(String path, List<double> bars) {
    if (bars.isNotEmpty) _byPath[path] = bars;
  }

  List<double>? forPath(String? path) => path == null ? null : _byPath[path];

  /// Enlaza la onda registrada por [path] con el id real [messageId].
  void link(String path, String messageId) {
    final bars = _byPath.remove(path);
    if (bars == null) return;
    _byMessageId[messageId] = bars;
    // Tope: se descartan las más antiguas (LinkedHashMap conserva el orden).
    while (_byMessageId.length > maxLinkedWaveforms) {
      _byMessageId.remove(_byMessageId.keys.first);
    }
  }

  /// Ids reales ya enlazados (evita asignar dos audios a la misma onda).
  Set<String> get linkedIds => _byMessageId.keys.toSet();

  /// Onda para un mensaje: por id real o, si es pendiente, por su archivo local.
  List<double>? lookup({required String messageId, String? localPath}) =>
      _byMessageId[messageId] ?? forPath(localPath);
}

/// Ciclo de velocidad 1× → 1.5× → 2× → 1×.
double nextAudioSpeed(double current) {
  if (current < 1.25) return 1.5;
  if (current < 1.75) return 2.0;
  return 1.0;
}

/// "1×", "1,5×", "2×".
String audioSpeedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed.toString().replaceAll('.', ',')}×';
