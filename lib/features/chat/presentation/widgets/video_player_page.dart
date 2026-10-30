import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';
import 'package:video_player/video_player.dart';

/// Reproductor de video a pantalla completa: play/pausa, barra de progreso,
/// tiempo y cerrar. "Abrir con otra app" queda como acción secundaria.
Future<void> showVideoPlayer(
  BuildContext context, {
  File? file,
  Uri? uri,
  String? mime,
}) {
  assert(file != null || uri != null);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerPage(file: file, uri: uri, mime: mime),
    ),
  );
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, this.file, this.uri, this.mime});

  final File? file;
  final Uri? uri;
  final String? mime;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;
  bool _controls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _c = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(widget.uri!);
    _c.addListener(_onTick);
    _c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _c.play();
          _scheduleHide();
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onTick() {
    if (!mounted) return;
    if (_c.value.hasError && !_failed) {
      setState(() => _failed = true);
      return;
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    if (_c.value.isPlaying) {
      await _c.pause();
      _hide?.cancel();
    } else {
      final v = _c.value;
      if (v.position >= v.duration) await _c.seekTo(Duration.zero);
      await _c.play();
      _scheduleHide();
    }
  }

  Future<void> _external() async {
    final file = widget.file;
    final ok = file != null
        ? await openLocalFile(file.path, mime: widget.mime)
        : await openExternal(widget.uri!);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No hay una app para abrir este video')),
        );
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final playing = v.isPlaying;
    final pos = v.position;
    final dur = v.duration;
    const white = Colors.white;

    Widget overlay() => Column(
      children: [
        SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cerrar',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: white),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _external,
                style: TextButton.styleFrom(
                  foregroundColor: white,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir con otra app'),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_ready)
          Semantics(
            button: true,
            label: playing ? 'Pausar' : 'Reproducir',
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (_ready)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    mmss(pos),
                    style: const TextStyle(color: white, fontSize: 13),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: dur.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      value: pos.inMilliseconds.toDouble().clamp(
                        0,
                        dur.inMilliseconds.toDouble().clamp(1, double.infinity),
                      ),
                      activeColor: white,
                      inactiveColor: Colors.white30,
                      semanticFormatterCallback: (_) =>
                          '${mmss(pos)} de ${mmss(dur)}',
                      onChangeStart: (_) => _hide?.cancel(),
                      onChanged: (x) =>
                          _c.seekTo(Duration(milliseconds: x.round())),
                      onChangeEnd: (_) => _scheduleHide(),
                    ),
                  ),
                  Text(
                    mmss(dur),
                    style: const TextStyle(color: white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: Center(
                child: AspectRatio(
                  aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
                  child: VideoPlayer(_c),
                ),
              ),
            )
          else if (!_failed)
            Center(
              child: Semantics(
                label: 'Cargando video',
                child: const CircularProgressIndicator(color: white),
              ),
            ),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white70,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pudimos reproducir este video en la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          if (_controls || !_ready || _failed) overlay(),
        ],
      ),
    );
  }
}
