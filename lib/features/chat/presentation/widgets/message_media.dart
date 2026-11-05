import 'dart:async';
import '../utils/image_sizing.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/theme/pf_motion.dart';
import 'package:partsflow_mobile/core/ui/pf_haptics.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/media_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_playback_coordinator.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_waveform.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/audio_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/video_player_page.dart';

void _toast(BuildContext context, String text) =>
    PfToast.show(context, text, kind: PfToastKind.error);

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

class _AudioMessageViewState extends ConsumerState<AudioMessageView>
    with SingleTickerProviderStateMixin
    implements PausableAudio {
  late final AnimationController _playIcon = AnimationController(
    vsync: this,
    duration: PfMotion.audioPlayMorph,
  );
  List<double>? _bars;
  late final AudioPlaybackCoordinator _coordinator;
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];
  MediaPreview? _preview;
  bool _loading = false;
  bool _ready = false;
  bool _playing = false;
  final ValueNotifier<Duration> _posN = ValueNotifier(Duration.zero);
  Duration? _dur;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(audioPlaybackCoordinatorProvider);
    final m = widget.message;
    // Onda solo para audios propios de esta sesión.
    _bars = ref
        .read(audioWaveformStoreProvider)
        .lookup(messageId: m.id, localPath: m.localPath);
    if (m.mediaId != null) _loadPreview();
  }

  @override
  void didUpdateWidget(AudioMessageView old) {
    super.didUpdateWidget(old);
    // Pendiente → real: el id cambia, la onda se enlaza por el controlador.
    if (_bars == null) {
      final m = widget.message;
      _bars = ref
          .read(audioWaveformStoreProvider)
          .lookup(messageId: m.id, localPath: m.localPath);
    }
  }

  void _syncPlayIcon(bool playing) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _playIcon.value = playing ? 1 : 0;
    } else if (playing) {
      _playIcon.forward();
    } else {
      _playIcon.reverse();
    }
  }

  void _cycleSpeed() {
    PfHaptics.selection();
    ref.read(audioSpeedProvider.notifier).cycle();
  }

  @override
  void dispose() {
    _coordinator.release(this);
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    _posN.dispose();
    _playIcon.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final m = widget.message;
    final r = await ref
        .read(mediaServiceProvider)
        .preview(RemoteMediaKind.audio, m.mediaId!, m.replyId);
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
              .read(mediaServiceProvider)
              .preview(RemoteMediaKind.audio, m.mediaId!, m.replyId);
          if (r case Ok(:final value)) pv = value;
        }
        final id = pv?.id ?? m.mediaId!;
        final ext = _extForMime(pv?.mime ?? m.mediaMime, 'ogg');
        final res = await ref
            .read(mediaServiceProvider)
            .fetchFile(
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
      await player.setSpeed(ref.read(audioSpeedProvider));
      _subs
        ..add(
          player.playerStateStream.listen((s) {
            if (!mounted) return;
            if (s.processingState == ProcessingState.completed) {
              player.pause();
              player.seek(Duration.zero);
              _posN.value = Duration.zero;
              setState(() => _playing = false);
              _syncPlayIcon(false);
            } else {
              setState(() => _playing = s.playing);
              _syncPlayIcon(s.playing);
            }
          }),
        )
        ..add(
          player.positionStream.listen((p) {
            if (!mounted) return;
            final d = (p - _posN.value).inMilliseconds.abs();
            if (d >= 200 || p == Duration.zero || p == _dur) _posN.value = p;
          }),
        );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
      _coordinator.claim(this);
      await player.play();
    } catch (_) {
      _player?.dispose();
      _player = null;
      if (mounted) {
        setState(() => _loading = false);
        _toast(context, 'No se pudo reproducir el audio');
      }
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (!_ready) return _prepare();
    if (_playing) {
      await _player!.pause();
    } else {
      _coordinator.claim(this);
      await _player!.play();
    }
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Widget build(BuildContext context) {
    final speed = ref.watch(audioSpeedProvider);
    ref.listen(audioSpeedProvider, (_, s) {
      _player?.setSpeed(s).catchError((Object _) {});
    });
    final total = _dur ?? Duration.zero;
    final max = total.inMilliseconds.toDouble();
    final bars = _bars;
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
                      : Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.color.withValues(alpha: 0.18),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedIcon(
                              icon: AnimatedIcons.play_pause,
                              progress: _playIcon,
                              size: 24,
                              color: widget.color,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: _posN,
                  builder: (_, pos, _) {
                    if (bars != null) {
                      final canSeek = _ready && max > 0;
                      void seekBy(int secs) {
                        final ms = (pos.inMilliseconds + secs * 1000).clamp(
                          0,
                          max.toInt(),
                        );
                        final d = Duration(milliseconds: ms);
                        _posN.value = d;
                        _player?.seek(d);
                      }

                      String at(int secs) => mmss(
                        Duration(
                          milliseconds: (pos.inMilliseconds + secs * 1000)
                              .clamp(0, max.toInt()),
                        ),
                      );
                      return Semantics(
                        slider: true,
                        label: 'Progreso del audio',
                        value: mmss(pos),
                        increasedValue: canSeek ? at(5) : null,
                        decreasedValue: canSeek ? at(-5) : null,
                        onIncrease: canSeek ? () => seekBy(5) : null,
                        onDecrease: canSeek ? () => seekBy(-5) : null,
                        child: WaveformSeekBar(
                          bars: bars,
                          color: widget.color,
                          progress: max <= 0
                              ? 0
                              : (pos.inMilliseconds / max).clamp(0.0, 1.0),
                          onSeek: _ready && max > 0
                              ? (f) {
                                  final d = Duration(
                                    milliseconds: (f * max).round(),
                                  );
                                  _posN.value = d;
                                  _player?.seek(d);
                                }
                              : null,
                        ),
                      );
                    }
                    return SliderTheme(
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
                        value: max <= 0
                            ? 0.0
                            : pos.inMilliseconds.clamp(0, max).toDouble(),
                        max: max <= 0 ? 1 : max,
                        onChanged: _ready && max > 0
                            ? (v) {
                                final d = Duration(milliseconds: v.round());
                                _posN.value = d;
                                _player?.seek(d);
                              }
                            : null,
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      ValueListenableBuilder<Duration>(
                        valueListenable: _posN,
                        builder: (_, pos, _) {
                          final shown =
                              _ready && _playing || pos > Duration.zero
                              ? pos
                              : total;
                          return Text(
                            total == Duration.zero && !_ready
                                ? 'Audio'
                                : mmss(shown),
                            style: TextStyle(fontSize: 12, color: widget.color),
                          );
                        },
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        onTap: _cycleSpeed,
                        label:
                            'Velocidad de reproducción, ${audioSpeedLabel(speed)}',
                        child: ExcludeSemantics(
                          // Área táctil ≥ 40 px; el chip visual sigue pequeño.
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _cycleSpeed,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 40,
                              ),
                              child: Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 24,
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: widget.color.withValues(alpha: 0.18),
                                  ),
                                  child: Text(
                                    audioSpeedLabel(speed),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: widget.color,
                                    ),
                                  ),
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
  Uint8List? _thumbBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.message;
    if (m.mediaId != null) {
      ref
          .read(mediaServiceProvider)
          .preview(RemoteMediaKind.video, m.mediaId!, m.replyId)
          .then((r) {
            if (mounted && r is Ok<MediaPreview>) {
              setState(() {
                _preview = r.value;
                final t = r.value.thumbnailBytes;
                _thumbBytes = t == null
                    ? null
                    : (t is Uint8List ? t : Uint8List.fromList(t));
              });
            }
          });
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final m = widget.message;
    if (m.mediaId == null) {
      final url = m.mediaUrl;
      if (url != null) {
        await showVideoPlayer(context, uri: Uri.parse(url));
        return;
      }
      if (mounted) _toast(context, 'No se pudo abrir el video');
      return;
    }
    setState(() => _busy = true);
    final mime = _preview?.mime ?? m.mediaMime ?? 'video/mp4';
    final res = await ref
        .read(mediaServiceProvider)
        .fetchFile(
          kind: RemoteMediaKind.video,
          downloadId: _preview?.id ?? m.mediaId!,
          cacheName: 'pf_video_${m.id}.${_extForMime(mime, 'mp4')}',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.file == null) return _toast(context, res.error!);
    await showVideoPlayer(context, file: res.file, mime: mime);
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final thumb = _thumbBytes;
    final dur = _preview?.durationSeconds;
    return Semantics(
      button: true,
      label: 'Video. Toca para reproducir',
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
                      thumb,
                      cacheWidth: decodePx(context, 200),
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
          .read(mediaServiceProvider)
          .preview(RemoteMediaKind.document, m.mediaId!, m.replyId)
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
      if (mounted) _toast(context, 'No se pudo abrir el documento');
      return;
    }
    setState(() => _busy = true);
    final name = _name;
    final res = await ref
        .read(mediaServiceProvider)
        .fetchFile(
          kind: RemoteMediaKind.document,
          downloadId: m.mediaId!,
          cacheName: 'pf_doc_${m.id}_$name',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.file == null) return _toast(context, res.error!);
    final ok = await openLocalFile(
      res.file!.path,
      mime: mimeFromName(name, hint: m.mediaMime),
    );
    if (!ok && mounted) {
      _toast(context, 'No hay una app para abrir este documento');
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
                    _toast(context, 'No se pudo abrir el mapa');
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
                            _toast(context, 'No se pudo abrir el marcador');
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
              cacheWidth: decodePx(context, 200),
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
