enum AttachmentKind { image, video, audio, document }

/// Archivo local listo para subir y enviar.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.path,
    required this.name,
    required this.mime,
    required this.kind,
    this.size = 0,
  });

  final String path;
  final String name;
  final String mime;
  final AttachmentKind kind;
  final int size;
}

/// Respuesta de `chat/files/upload/`.
class UploadedFile {
  const UploadedFile({required this.fileId, this.fileName});

  final String fileId;
  final String? fileName;
}

/// Tipo de media recibida que se resuelve con preview/download.
enum RemoteMediaKind { audio, video, document }

class MediaPreview {
  const MediaPreview({
    required this.id,
    this.mime,
    this.durationSeconds,
    this.thumbnailBytes,
    this.filename,
    this.extension,
  });

  /// Id para `download` (para documentos es el mismo `media.id`).
  final String id;
  final String? mime;
  final double? durationSeconds;
  final List<int>? thumbnailBytes;
  final String? filename;
  final String? extension;
}
