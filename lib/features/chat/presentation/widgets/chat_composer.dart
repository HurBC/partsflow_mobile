import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/quick_answer.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/attachment_preview_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/quick_answers_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/templates_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum _AttachAction { camera, gallery, file, quick, template }

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.chat,
    required this.templatesEnabled,
  });

  final Chat chat;

  /// true si la cuenta es `api` (WhatsApp oficial): muestra "Plantilla".
  final bool templatesEnabled;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  AudioRecorder? _recorder;
  bool _hasText = false;
  bool _recording = false;
  bool _stopping = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _busy = false;

  ChatThread get _thread => ref.read(chatThreadProvider(widget.chat).notifier);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      // Refresca el panel de "/" mientras se escribe.
      if (_controller.text.startsWith('/') || _slashOpen) {
        setState(() => _slashOpen = _controller.text.startsWith('/'));
      }
    });
  }

  bool _slashOpen = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder?.cancel().whenComplete(() => _recorder?.dispose());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _thread.send(text);
    _controller.clear();
  }

  // ---- Menú "+" --------------------------------------------------------------

  Future<void> _openMenu() async {
    _focus.unfocus();
    final action = await showModalBottomSheet<_AttachAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: Icons.photo_camera_outlined,
              label: 'Cámara',
              onTap: () => Navigator.pop(ctx, _AttachAction.camera),
            ),
            _MenuTile(
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: () => Navigator.pop(ctx, _AttachAction.gallery),
            ),
            _MenuTile(
              icon: Icons.insert_drive_file_outlined,
              label: 'Archivo',
              onTap: () => Navigator.pop(ctx, _AttachAction.file),
            ),
            _MenuTile(
              icon: Icons.bolt_outlined,
              label: 'Respuesta rápida',
              onTap: () => Navigator.pop(ctx, _AttachAction.quick),
            ),
            if (widget.templatesEnabled)
              _MenuTile(
                icon: Icons.description_outlined,
                label: 'Plantilla',
                onTap: () => Navigator.pop(ctx, _AttachAction.template),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _AttachAction.camera:
        await _pickCamera();
      case _AttachAction.gallery:
        await _pickGallery();
      case _AttachAction.file:
        await _pickFiles();
      case _AttachAction.quick:
        await _pickQuick();
      case _AttachAction.template:
        await pickAndSendTemplate(context, ref, widget.chat);
    }
  }

  Future<void> _pickCamera() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (x == null) return;
      await _preview([
        await attachmentFromPath(
          x.path,
          name: x.name.isEmpty ? null : x.name,
          mime: x.mimeType,
        ),
      ]);
    } catch (_) {
      _snack('No se pudo abrir la cámara');
    }
  }

  Future<void> _pickGallery() async {
    try {
      final xs = await _picker.pickMultipleMedia(
        limit: ChatThread.maxBatch,
        imageQuality: 85,
      );
      if (xs.isEmpty) return;
      final files = <OutgoingAttachment>[];
      for (final x in xs) {
        files.add(
          await attachmentFromPath(
            x.path,
            name: x.name.isEmpty ? null : x.name,
            mime: x.mimeType,
          ),
        );
      }
      await _preview(files);
    } catch (_) {
      _snack('No se pudo abrir la galería');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final picked = await FilePicker.pickFiles();
      if (picked.isEmpty) return;
      final files = <OutgoingAttachment>[];
      for (final f in picked) {
        final path = f.path;
        if (path == null) continue;
        files.add(await attachmentFromPath(path, name: f.name));
      }
      await _preview(files);
    } catch (_) {
      _snack('No se pudo abrir el selector de archivos');
    }
  }

  /// Valida tamaño/cantidad, muestra la vista previa y envía.
  Future<void> _preview(
    List<OutgoingAttachment> files, {
    String caption = '',
  }) async {
    if (!mounted) return;
    final ok = <OutgoingAttachment>[];
    final tooBig = <String>[];
    for (final f in files) {
      if (f.size > ChatThread.maxUploadBytes) {
        tooBig.add(f.name);
      } else {
        ok.add(f);
      }
    }
    if (tooBig.isNotEmpty) {
      _snack(
        tooBig.length == 1
            ? '«${tooBig.first}» pesa más de 16 MB y no se puede enviar'
            : '${tooBig.length} archivos pesan más de 16 MB y no se enviarán',
      );
    }
    var batch = ok;
    if (batch.length > ChatThread.maxBatch) {
      batch = batch.sublist(0, ChatThread.maxBatch);
      _snack('Máximo ${ChatThread.maxBatch} archivos por envío');
    }
    if (batch.isEmpty) return;
    final res = await showAttachmentPreview(
      context,
      batch,
      initialCaption: caption,
    );
    if (res == null || !mounted) return;
    unawaited(_thread.sendAttachments(res.files, res.caption));
  }

  // ---- Respuestas rápidas ------------------------------------------------------

  Future<void> _pickQuick() async {
    final qa = await showQuickAnswersSheet(context);
    if (qa != null && mounted) await _applyQuick(qa, fromSlash: false);
  }

  Future<void> _applyQuick(QuickAnswer qa, {required bool fromSlash}) async {
    final msg = qa.message ?? '';
    final url = qa.imageUrl;
    if (url != null) {
      if (_busy) return;
      setState(() => _busy = true);
      final r = await ref.read(chatRepositoryProvider).downloadBytes(url);
      if (!mounted) return;
      setState(() => _busy = false);
      final bytes = switch (r) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (bytes == null || bytes.isEmpty) {
        // Sin imagen, al menos el texto.
        _snack('No se pudo descargar la imagen de la respuesta');
        if (msg.isNotEmpty) _insertText(msg, replaceAll: fromSlash);
        return;
      }
      final path = Uri.tryParse(url)?.path ?? '';
      var ext = extensionOf(path);
      if (ext.isEmpty || ext.length > 5) ext = 'jpg';
      final file = await writeTemp(bytes, 'pf_qa_${qa.id}.$ext');
      if (fromSlash) _controller.clear();
      final att = await attachmentFromPath(
        file.path,
        kind: AttachmentKind.image,
      );
      await _preview([att], caption: msg);
      return;
    }
    if (msg.isEmpty) return;
    _insertText(msg, replaceAll: fromSlash);
  }

  void _insertText(String msg, {required bool replaceAll}) {
    final current = _controller.text;
    final next = replaceAll || current.trim().isEmpty
        ? msg
        : '${current.trimRight()} $msg';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
  }

  // ---- Audio -----------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_recording || _stopping) return;
    final rec = _recorder ??= AudioRecorder();
    try {
      final allowed = await rec.hasPermission();
      if (!allowed) {
        if (mounted) await _explainMic();
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/pf_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      _focus.unfocus();
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      _snack('No se pudo iniciar la grabación');
    }
  }

  Future<void> _explainMic() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Permiso de micrófono'),
      content: const Text(
        'Para grabar audios, Partsflow necesita usar el micrófono. '
        'Actívalo en Ajustes del teléfono > Aplicaciones > Partsflow > Permisos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    setState(() => _recording = false);
    try {
      await _recorder?.cancel();
    } catch (_) {}
  }

  Future<void> _sendRecording() async {
    if (_stopping) return;
    _stopping = true;
    _ticker?.cancel();
    final seconds = _elapsed.inSeconds;
    try {
      final path = await _recorder?.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path == null || seconds < 1) {
        _snack('Audio muy corto. Mantén la grabación al menos un segundo');
        return;
      }
      final name = 'audio-${DateTime.now().millisecondsSinceEpoch}.m4a';
      final size = await File(path).length();
      unawaited(
        _thread.sendAttachments([
          OutgoingAttachment(
            path: path,
            name: name,
            mime: 'audio/mp4',
            kind: AttachmentKind.audio,
            size: size,
          ),
        ], ''),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _recording = false);
        _snack('No se pudo guardar la grabación');
      }
    } finally {
      _stopping = false;
    }
  }

  // ---- UI --------------------------------------------------------------------

  String _replyLabel(Message m) {
    final myId = ref.read(apiUserProvider).value?.id;
    return switch (m.author(myId)) {
      MessageAuthor.client => chatDisplayName(widget.chat),
      MessageAuthor.me => 'Tú',
      MessageAuthor.julia => 'Julia',
      MessageAuthor.david => 'David',
      MessageAuthor.assistant => 'Asistente IA',
      MessageAuthor.welcome => 'Bienvenida automática',
      MessageAuthor.otherAgent => m.senderName ?? m.agent ?? 'Equipo',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final reply = ref.watch(
      chatThreadProvider(widget.chat).select((s) => s.replyTo),
    );
    final slash =
        _controller.text.startsWith('/') &&
            !_controller.text.contains(RegExp(r'\s'))
        ? _controller.text.substring(1)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: pf.surface,
        border: Border(top: BorderSide(color: pf.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slash != null && !_recording)
            _SlashPanel(
              query: slash,
              onPick: (qa) => _applyQuick(qa, fromSlash: true),
            ),
          if (reply != null && !_recording)
            _ReplyBar(
              label: _replyLabel(reply),
              body: reply.quoteBody == reply.type
                  ? labelForType(reply.type)
                  : reply.quoteBody,
              onCancel: () => _thread.setReply(null),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              8 + MediaQuery.paddingOf(context).bottom,
            ),
            child: _recording
                ? _recordingRow(pf)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Adjuntar',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: _busy ? null : _openMenu,
                        icon: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(Icons.add_circle_outline, color: pf.textMid),
                      ),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: pf.bg,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(fontSize: 15, color: pf.text),
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje',
                              hintStyle: TextStyle(color: pf.placeholder),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Semantics(
                        button: true,
                        label: _hasText ? 'Enviar' : 'Grabar audio',
                        child: ExcludeSemantics(
                          child: Material(
                            color: primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _hasText ? _submit : _startRecording,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  _hasText ? Icons.send : Icons.mic,
                                  size: 22,
                                  color: Colors.white,
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
    );
  }

  Widget _recordingRow(PfColors pf) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        IconButton(
          tooltip: 'Cancelar grabación',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: _cancelRecording,
          icon: Icon(Icons.delete_outline, color: pf.errFg),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: 'Grabando, ${mmss(_elapsed)}',
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: pf.bg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: pf.errIcon,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      mmss(_elapsed),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: pf.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Grabando…',
                      style: TextStyle(fontSize: 14, color: pf.text2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: 'Enviar audio',
          child: ExcludeSemantics(
            child: Material(
              color: primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendRecording,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.send, size: 22, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: pf.textMid),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(fontSize: 16, color: pf.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.label,
    required this.body,
    required this.onCancel,
  });

  final String label;
  final String body;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
        decoration: BoxDecoration(
          color: pf.divider,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: pf.link, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Respondiendo a $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pf.link,
                    ),
                  ),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: pf.textMid),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancelar respuesta',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onCancel,
              icon: Icon(Icons.close, size: 20, color: pf.textMid),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sugerencias al escribir "/" al inicio del mensaje.
class _SlashPanel extends ConsumerWidget {
  const _SlashPanel({required this.query, required this.onPick});

  final String query;
  final ValueChanged<QuickAnswer> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);
    final async = ref.watch(quickAnswersProvider);
    final child = async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'No pudimos cargar las respuestas rápidas.',
                style: TextStyle(fontSize: 13, color: pf.text2),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(quickAnswersProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (all) {
        final items = filterQuickAnswers(all, query);
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Sin respuestas rápidas que coincidan',
              style: TextStyle(fontSize: 13, color: pf.text2),
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final a in items.take(30))
              QuickAnswerTile(answer: a, onTap: () => onPick(a)),
          ],
        );
      },
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.3,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pf.divider)),
        ),
        child: child,
      ),
    );
  }
}
