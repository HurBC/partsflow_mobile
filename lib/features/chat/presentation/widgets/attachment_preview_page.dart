import 'dart:io';

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_files.dart';

typedef AttachmentBatch = ({List<OutgoingAttachment> files, String caption});

/// Vista previa a pantalla completa con leyenda antes de enviar.
/// Devuelve null si el usuario cancela.
Future<AttachmentBatch?> showAttachmentPreview(
  BuildContext context,
  List<OutgoingAttachment> files, {
  String initialCaption = '',
}) => Navigator.of(context).push<AttachmentBatch>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        _AttachmentPreviewPage(files: files, initialCaption: initialCaption),
  ),
);

class _AttachmentPreviewPage extends StatefulWidget {
  const _AttachmentPreviewPage({
    required this.files,
    required this.initialCaption,
  });

  final List<OutgoingAttachment> files;
  final String initialCaption;

  @override
  State<_AttachmentPreviewPage> createState() => _AttachmentPreviewPageState();
}

class _AttachmentPreviewPageState extends State<_AttachmentPreviewPage> {
  late final List<OutgoingAttachment> _files = [...widget.files];
  late final _caption = TextEditingController(text: widget.initialCaption);
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _caption.dispose();
    _page.dispose();
    super.dispose();
  }

  void _remove() {
    if (_files.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _files.removeAt(_index);
      if (_index >= _files.length) _index = _files.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final multi = _files.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Cancelar',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          multi ? '${_index + 1} de ${_files.length}' : 'Vista previa',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: multi ? 'Quitar este archivo' : 'Descartar',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _remove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: ValueKey(_files.length),
              controller: _page,
              itemCount: _files.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _FilePreview(file: _files[i]),
            ),
          ),
          Container(
            color: const Color(0xFF111111),
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _caption,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: multi
                            ? 'Leyenda (solo en el primer archivo)'
                            : 'Agrega una leyenda',
                        hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
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
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: multi ? 'Enviar ${_files.length} archivos' : 'Enviar',
                  child: ExcludeSemantics(
                    child: Material(
                      color: const Color(0xFF43DBAD),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop<AttachmentBatch>(context, (
                          files: _files,
                          caption: _caption.text.trim(),
                        )),
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(
                            Icons.send,
                            size: 24,
                            color: Color(0xFF181D84),
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
}

class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.file});

  final OutgoingAttachment file;

  @override
  Widget build(BuildContext context) {
    if (file.kind == AttachmentKind.image) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            File(file.path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      );
    }
    final icon = switch (file.kind) {
      AttachmentKind.video => Icons.videocam_outlined,
      AttachmentKind.audio => Icons.mic_none,
      _ => Icons.insert_drive_file_outlined,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              file.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatBytes(file.size),
              style: const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
            ),
          ],
        ),
      ),
    );
  }
}
