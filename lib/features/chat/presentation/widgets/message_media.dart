import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String _extForMime(String? mime, String fallback) {
  final m = (mime ?? '').toLowerCase();
  if (m.contains('ogg') || m.contains('opus')) return 'ogg';
  if (m.contains('mp4') || m.contains('m4a') || m.contains('aac')) return 'm4a';
  if (m.contains('mpeg') || m.contains('mp3')) return 'mp3';
  if (m.contains('wav')) return 'wav';
  if (m.contains('3gpp')) return '3gp';
  if (m.contains('quicktime')) return 'mov';
  if (m.contains('webm')) return 'webm';
  return fallback;
}

/// Descarga (o reutiliza del caché temporal) la media recibida.
/// Devuelve el archivo o un mensaje de error.
Future<({File? file, String? error})> _fetchFile(
  WidgetRef ref, {
  required RemoteMediaKind kind,
  required String downloadId,
  required String cacheName,
}) async {
  final cached = await cachedTemp(cacheName);
  if (cached != null) return (file: cached, error: null);
  final r = await ref
      .read(chatRepositoryProvider)
      .mediaDownload(kind, downloadId);
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
      return (file: await writeTemp(value, cacheName), error: null);
    case Err():
      return (file: null, error: 'No se pudo descargar el archivo');
  }
}

// ---- Audio -------------------------------------------------------------------

class AudioMessageView extends ConsumerStatefulWidget {
  const AudioMessageView({
    super.key,
    required this.message,
    required this.color,
    required this.accent,
  });

  final Message message;
  final Color color;
  final Color accent;

  @override
  ConsumerState<AudioMessageView> createState() => _AudioMessageViewState();
}

class _AudioMessageViewState extends ConsumerState<AudioMessageView> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];
  MediaPreview? _preview;
  bool _loading = false;
  bool _ready = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _dur;

  @override
  void initState() {
    super.initState();
    final m = widget.message;
    if (m.mediaId != null) _loadPreview();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final m = widget.message;
    final r = await ref
        .read(chatRepositoryProvider)
        .mediaPreview(RemoteMediaKind.audio, m.mediaId!, m.replyId);
    if (!mounted) return;
    if (r case Ok(:final value)) {
      setState(() {
        _preview = value;
        final d = value.durationSeconds;
        if (d != null && _dur == null) {
          _dur = Duration(milliseconds: (d * 1000).round());
        }
      });
    }
  }

  Future<void> _prepare() async {
    final m = widget.message;
    setState(() => _loading = true);
    try {
      final player = AudioPlayer();
      _player = player;
      if (m.mediaId != null) {
        var pv = _preview;
        if (pv == null) {
          final r = await ref
              .read(chatRepositoryProvider)
              .mediaPreview(RemoteMediaKind.audio, m.mediaId!, m.replyId);
          if (r case Ok(:final value)) pv = value;
        }
        final id = pv?.id ?? m.mediaId!;
        final ext = _extForMime(pv?.mime ?? m.mediaMime, 'ogg');
        final res = await _fetchFile(
          ref,
          kind: RemoteMediaKind.audio,
          downloadId: id,
          cacheName: 'pf_audio_${m.id}.$ext',
        );
        if (res.file == null) throw StateError(res.error ?? 'audio');
        _dur = await player.setFilePath(res.file!.path) ?? _dur;
      } else if (m.mediaUrl != null) {
        _dur = await player.setUrl(m.mediaUrl!) ?? _dur;
      } else {
        throw StateError('sin audio');
      }
      _subs
        ..add(
          player.playerStateStream.listen((s) {
            if (!mounted) return;
            if (s.processingState == ProcessingState.completed) {
              player.pause();
              player.seek(Duration.zero);
              setState(() {
                _playing = false;
                _pos = Duration.zero;
              });
            } else {
              setState(() => _playing = s.playing);
            }
          }),
        )
        ..add(
          player.positionStream.listen((p) {
            if (mounted) setState(() => _pos = p);
          }),
        );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
      await player.play();
    } catch (_) {
      _player?.dispose();
      _player = null;
      if (mounted) {
        setState(() => _loading = false);
        _snack(context, 'No se pudo reproducir el audio');
      }
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (!_ready) return _prepare();
    if (_playing) {
      await _player!.pause();
    } else {
      await _player!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur ?? Duration.zero;
    final max = total.inMilliseconds.toDouble();
    final value = max <= 0 ? 0.0 : _pos.inMilliseconds.clamp(0, max).toDouble();
    final shown = _ready && _playing || _pos > Duration.zero ? _pos : total;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Pausar audio' : 'Reproducir audio',
            child: ExcludeSemantics(
              child: InkResponse(
                onTap: _toggle,
                radius: 24,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: widget.color,
                          ),
                        )
                      : Icon(
                          _playing ? Icons.pause_circle : Icons.play_circle,
                          size: 38,
                          color: widget.color,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: widget.color,
                    inactiveTrackColor: widget.color.withValues(alpha: 0.3),
                    thumbColor: widget.color,
                  ),
                  child: Slider(
                    value: value,
                    max: max <= 0 ? 1 : max,
                    onChanged: _ready && max > 0
                        ? (v) =>
                              _player?.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      total == Duration.zero && !_ready ? 'Audio' : mmss(shown),
                      style: TextStyle(fontSize: 12, color: widget.color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Video -------------------------------------------------------------------

class VideoMessageView extends ConsumerStatefulWidget {
  const VideoMessageView({
    super.key,
    required this.message,
    required this.color,
  });

  final Message message;
  final Color color;

  @override
  ConsumerState<VideoMessageView> createState() => _VideoMessageViewState();
}

class _VideoMessageViewState extends ConsumerState<VideoMessageView> {
  MediaPreview? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.message;
    if (m.mediaId != null) {
      ref
          .read(chatRepositoryProvider)
          .mediaPreview(RemoteMediaKind.video, m.mediaId!, m.replyId)
          .then((r) {
            if (mounted && r is Ok<MediaPreview>) {
              setState(() => _preview = r.value);
            }
          });
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final m = widget.message;
    if (m.mediaId == null) {
      final url = m.mediaUrl;
      if (url != null && await openExternal(Uri.parse(url))) return;
      if (mounted) _snack(context, 'No se pudo abrir el video');
      return;
    }
    setState(() => _busy = true);
    final mime = _preview?.mime ?? m.mediaMime ?? 'video/mp4';
    final res = await _fetchFile(
      ref,
      kind: RemoteMediaKind.video,
      downloadId: _preview?.id ?? m.mediaId!,
      cacheName: 'pf_video_${m.id}.${_extForMime(mime, 'mp4')}',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.file == null) return _snack(context, res.error!);
    final ok = await openLocalFile(res.file!.path, mime: mime);
    if (!ok && mounted) _snack(context, 'No hay una app para abrir este video');
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final thumb = _preview?.thumbnailBytes;
    final dur = _preview?.durationSeconds;
    return Semantics(
      button: true,
      label: 'Video. Toca para abrir',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: _open,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 200,
              height: 150,
              color: pf.divider,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb != null)
                    Image.memory(
                      Uint8List.fromList(thumb),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                  ),
                  if (dur != null)
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mmss(Duration(seconds: dur.round())),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Documento ---------------------------------------------------------------

class DocumentMessageView extends ConsumerStatefulWidget {
  const DocumentMessageView({
    super.key,
    required this.message,
    required this.color,
  });

  final Message message;
  final Color color;

  @override
  ConsumerState<DocumentMessageView> createState() =>
      _DocumentMessageViewState();
}

class _DocumentMessageViewState extends ConsumerState<DocumentMessageView> {
  MediaPreview? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.message;
    if (m.mediaId != null && m.mediaFilename == null) {
      ref
          .read(chatRepositoryProvider)
          .mediaPreview(RemoteMediaKind.document, m.mediaId!, m.replyId)
          .then((r) {
            if (mounted && r is Ok<MediaPreview>) {
              setState(() => _preview = r.value);
            }
          });
    }
  }

  String get _name {
    final m = widget.message;
    final pv = _preview;
    var n = m.mediaFilename ?? pv?.filename ?? 'Documento';
    final ext = pv?.extension;
    if (ext != null && extensionOf(n).isEmpty) {
      n = '$n.${ext.replaceAll('.', '')}';
    }
    return n;
  }

  Future<void> _open() async {
    if (_busy) return;
    final m = widget.message;
    if (m.mediaId == null) {
      final url = m.mediaUrl;
      if (url != null && await openExternal(Uri.parse(url))) return;
      if (mounted) _snack(context, 'No se pudo abrir el documento');
      return;
    }
    setState(() => _busy = true);
    final name = _name;
    final res = await _fetchFile(
      ref,
      kind: RemoteMediaKind.document,
      downloadId: m.mediaId!,
      cacheName: 'pf_doc_${m.id}_$name',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.file == null) return _snack(context, res.error!);
    final ok = await openLocalFile(
      res.file!.path,
      mime: mimeFromName(name, hint: m.mediaMime),
    );
    if (!ok && mounted) {
      _snack(context, 'No hay una app para abrir este documento');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Semantics(
      button: true,
      label: 'Documento $_name. Toca para abrir',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c,
                        ),
                      )
                    : Icon(
                        Icons.insert_drive_file_outlined,
                        size: 24,
                        color: c,
                      ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c,
                        ),
                      ),
                      Text(
                        'Toca para abrir',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Ubicación y contactos -----------------------------------------------------

class LocationMessageView extends StatelessWidget {
  const LocationMessageView({
    super.key,
    required this.message,
    required this.color,
  });

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude;
    final lon = message.longitude;
    final label = message.locationLabel ?? 'Ubicación';
    return Semantics(
      button: lat != null && lon != null,
      label: 'Ubicación $label. Toca para abrir en el mapa',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: lat == null || lon == null
              ? null
              : () async {
                  final ok = await openExternal(
                    Uri.parse('https://www.google.com/maps?q=$lat,$lon'),
                  );
                  if (!ok && context.mounted) {
                    _snack(context, 'No se pudo abrir el mapa');
                  }
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 24, color: color),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (lat != null && lon != null)
                        Text(
                          'Abrir en el mapa',
                          style: TextStyle(
                            fontSize: 12,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContactsMessageView extends StatelessWidget {
  const ContactsMessageView({
    super.key,
    required this.message,
    required this.color,
  });

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cards = message.contacts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 22, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final p in c.phones)
                  Semantics(
                    button: true,
                    label: 'Llamar a $p',
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () async {
                          final ok = await openExternal(
                            Uri.parse(
                              'tel:${p.replaceAll(RegExp(r'[^\d+]'), '')}',
                            ),
                          );
                          if (!ok && context.mounted) {
                            _snack(context, 'No se pudo abrir el marcador');
                          }
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 30),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.call_outlined,
                                  size: 18,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: color,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- Mensaje saliente local (subiendo) -------------------------------------------

class LocalMediaView extends StatelessWidget {
  const LocalMediaView({super.key, required this.message, required this.color});

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final progress = message.uploadProgress;
    final uploading = progress != null && message.status == 'temp';
    final path = message.localPath!;
    Widget progressRing(Color c) => SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        value: progress != null && progress > 0 && progress < 1
            ? progress
            : null,
        color: c,
      ),
    );

    if (message.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.file(
              File(path),
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 150,
                color: pf.divider,
                child: Icon(Icons.broken_image_outlined, color: pf.text2),
              ),
            ),
            if (uploading)
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: progressRing(Colors.white),
              ),
          ],
        ),
      );
    }
    final icon = switch (message.type) {
      'video' => Icons.videocam_outlined,
      'audio' => Icons.mic_none,
      _ => Icons.insert_drive_file_outlined,
    };
    final name = message.type == 'audio'
        ? 'Audio'
        : (message.mediaFilename ?? 'Archivo');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (uploading) ...[const SizedBox(width: 10), progressRing(color)],
      ],
    );
  }
}
