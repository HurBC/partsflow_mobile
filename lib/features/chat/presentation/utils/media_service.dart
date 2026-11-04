import 'dart:io';

import 'package:partsflow_mobile/core/media/async_dedupe_cache.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';

typedef MediaFileResult = ({File? file, String? error});

/// Previews y descargas de media recibida con memoización y dedupe.
///
/// - Preview: clave (tipo, mediaId, messageId); caché LRU de [previewCapacity]
///   solo para resultados Ok (un error se puede reintentar).
/// - Descarga: dedupe in-flight por nombre de caché (msgId); el resultado
///   persistente es el archivo en `pf_media/` (cachedMedia).
class MediaService {
  MediaService(
    this._repo, {
    Future<Directory> Function()? cacheDir,
    int previewCapacity = 200,
  }) : _cacheDir = cacheDir ?? mediaCacheDir,
       _previews = AsyncDedupeCache<String, Result<MediaPreview>>(
         maxEntries: previewCapacity,
         cacheable: (r) => r is Ok<MediaPreview>,
       );

  final ChatRepository _repo;
  final Future<Directory> Function() _cacheDir;
  final AsyncDedupeCache<String, Result<MediaPreview>> _previews;
  final _downloads = AsyncDedupeCache<String, MediaFileResult>(maxEntries: 0);

  Future<Result<MediaPreview>> preview(
    RemoteMediaKind kind,
    String mediaId,
    String messageId,
  ) => _previews.load(
    '${kind.name}|$mediaId|$messageId',
    () => _repo.mediaPreview(kind, mediaId, messageId),
  );

  /// Descarga (o reutiliza de la caché) la media; devuelve archivo o error.
  Future<MediaFileResult> fetchFile({
    required RemoteMediaKind kind,
    required String downloadId,
    required String cacheName,
  }) => _downloads.load(cacheName, () async {
    final dir = await _cacheDir();
    final cached = await cachedMedia(cacheName, dir: dir);
    if (cached != null) return (file: cached, error: null);
    final r = await _repo.mediaDownload(kind, downloadId);
    switch (r) {
      case Ok(:final value):
        if (value == null || value.isEmpty) {
          return (
            file: null,
            error: kind == RemoteMediaKind.document
                ? 'No se pueden descargar documentos de 3 MB o más'
                : 'No se pudo descargar el archivo',
          );
        }
        return (
          file: await writeMediaCache(value, cacheName, dir: dir),
          error: null,
        );
      case Err():
        return (file: null, error: 'No se pudo descargar el archivo');
    }
  });
}
