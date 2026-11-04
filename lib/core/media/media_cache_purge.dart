import 'dart:io';

/// Nombre del subdirectorio de caché de media descargada.
const mediaCacheDirName = 'pf_media';

class PurgeResult {
  const PurgeResult({required this.deleted, required this.freedBytes});
  final int deleted;
  final int freedBytes;
}

/// Envíos fallidos reintentables: solo se purgan por antigüedad, no por tamaño.
bool _isRetryable(String path) {
  final n = path.split(Platform.pathSeparator).last;
  return n.startsWith('pf_rec_') || n.startsWith('pegado-');
}

bool _isLegacyTemp(String name) =>
    name.startsWith('pf_') || name.startsWith('pegado-');

/// Purga la caché de media: `<tempDir>/pf_media/*` y (migración) los archivos
/// sueltos `pf_*` / `pegado-*` de [tempDir] de versiones anteriores.
///
/// 1. Borra los de más de [maxAge] (mtime).
/// 2. Si el total restante supera [maxBytes], borra los más antiguos hasta
///    quedar por debajo.
/// Nunca toca archivos modificados dentro de [inUseGrace] (pueden estar en uso).
Future<PurgeResult> purgeMediaCache(
  Directory tempDir, {
  DateTime Function()? now,
  Duration maxAge = const Duration(days: 7),
  int maxBytes = 200 * 1024 * 1024,
  Duration inUseGrace = const Duration(minutes: 10),
}) async {
  final t = (now ?? DateTime.now)();
  final entries = <({File file, DateTime mtime, int size})>[];

  Future<void> scan(Directory d, bool Function(String name) accept) async {
    if (!await d.exists()) return;
    await for (final e in d.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.path.split(Platform.pathSeparator).last;
      if (!accept(name)) continue;
      try {
        final st = await e.stat();
        entries.add((file: e, mtime: st.modified, size: st.size));
      } catch (_) {}
    }
  }

  await scan(Directory('${tempDir.path}/$mediaCacheDirName'), (_) => true);
  await scan(tempDir, _isLegacyTemp);

  var deleted = 0;
  var freed = 0;
  Future<void> remove(({File file, DateTime mtime, int size}) e) async {
    try {
      await e.file.delete();
      deleted++;
      freed += e.size;
    } catch (_) {}
  }

  final survivors = <({File file, DateTime mtime, int size})>[];
  for (final e in entries) {
    final age = t.difference(e.mtime);
    if (age < inUseGrace) {
      survivors.add(e);
    } else if (age > maxAge) {
      await remove(e);
    } else {
      survivors.add(e);
    }
  }

  var total = survivors.fold<int>(0, (a, e) => a + e.size);
  if (total > maxBytes) {
    final candidates =
        survivors
            .where(
              (e) =>
                  t.difference(e.mtime) >= inUseGrace &&
                  !_isRetryable(e.file.path),
            )
            .toList()
          ..sort((a, b) => a.mtime.compareTo(b.mtime));
    for (final e in candidates) {
      if (total <= maxBytes) break;
      await remove(e);
      total -= e.size;
    }
  }
  return PurgeResult(deleted: deleted, freedBytes: freed);
}
