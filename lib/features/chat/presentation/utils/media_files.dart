import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _mimes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  '3gp': 'video/3gpp',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'mp3': 'audio/mpeg',
  'ogg': 'audio/ogg',
  'opus': 'audio/ogg',
  'wav': 'audio/wav',
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'zip': 'application/zip',
};

String extensionOf(String name) {
  final i = name.lastIndexOf('.');
  return (i < 0 || i == name.length - 1)
      ? ''
      : name.substring(i + 1).toLowerCase();
}

String mimeFromName(String name, {String? hint}) {
  if (hint != null && hint.contains('/')) return hint;
  return _mimes[extensionOf(name)] ?? 'application/octet-stream';
}

AttachmentKind kindFromMime(String mime) {
  if (mime.startsWith('image/')) return AttachmentKind.image;
  if (mime.startsWith('video/')) return AttachmentKind.video;
  if (mime.startsWith('audio/')) return AttachmentKind.audio;
  return AttachmentKind.document;
}

Future<OutgoingAttachment> attachmentFromPath(
  String path, {
  String? name,
  String? mime,
  AttachmentKind? kind,
}) async {
  final n = name ?? path.split('/').last;
  final m = mimeFromName(n, hint: mime);
  return OutgoingAttachment(
    path: path,
    name: n,
    mime: m,
    kind: kind ?? kindFromMime(m),
    size: await File(path).length(),
  );
}

String safeName(String s) => s.replaceAll(RegExp(r'[^\w.\-]'), '_');

/// Escribe [bytes] en el directorio temporal; reutiliza el archivo si ya existe.
Future<File> writeTemp(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${safeName(name)}');
  await f.writeAsBytes(bytes, flush: true);
  return f;
}

Future<File?> cachedTemp(String name) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${safeName(name)}');
  return await f.exists() && await f.length() > 0 ? f : null;
}

/// true si algún visor del sistema pudo abrirlo.
Future<bool> openLocalFile(String path, {String? mime}) async {
  final r = await OpenFilex.open(path, type: mime);
  return r.type == ResultType.done;
}

Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

String mmss(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '${d.inMinutes}:$s';
}
