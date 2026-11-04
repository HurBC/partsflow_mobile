/// Memoización + dedupe in-flight por clave, con tope LRU de entradas.
///
/// - Dos llamadas simultáneas con la misma clave comparten un solo Future.
/// - Si el resultado es "cacheable" se guarda (LRU, máximo [maxEntries]);
///   si no (error) o si el loader lanza, no se guarda y se puede reintentar.
/// - `maxEntries == 0` => solo dedupe in-flight, sin caché de resultados.
class AsyncDedupeCache<K, V> {
  AsyncDedupeCache({required this.maxEntries, this.cacheable});

  final int maxEntries;
  final bool Function(V value)? cacheable;

  // LinkedHashMap mantiene orden de inserción; reinsertar = "usado ahora".
  final _values = <K, V>{};
  final _inflight = <K, Future<V>>{};

  int get length => _values.length;
  bool containsKey(K key) => _values.containsKey(key);

  Future<V> load(K key, Future<V> Function() loader) {
    if (_values.containsKey(key)) {
      final v = _values.remove(key) as V;
      _values[key] = v;
      return Future<V>.value(v);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;
    final f = loader().then<V>((v) {
      if (maxEntries > 0 && (cacheable?.call(v) ?? true)) _store(key, v);
      return v;
    });
    _inflight[key] = f;
    // Limpia el in-flight al terminar (ok o error) sin propagar el error aquí.
    f.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_inflight[key], f)) _inflight.remove(key);
    });
    return f;
  }

  void _store(K key, V v) {
    _values.remove(key);
    _values[key] = v;
    while (_values.length > maxEntries) {
      _values.remove(_values.keys.first);
    }
  }

  void clear() => _values.clear();
}
