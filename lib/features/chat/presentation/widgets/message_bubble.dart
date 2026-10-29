import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_media.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_ticks.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.myUserId,
    this.onRetry,
    this.onDiscard,
    this.onLongPress,
    this.onQuoteTap,
  });

  final Message message;
  final String? myUserId;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  /// Mantener pulsado: menú Responder / Copiar texto.
  final VoidCallback? onLongPress;

  /// Tocar la cita: saltar al mensaje original si está cargado.
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final author = message.author(myUserId);
    final inbound = author == MessageAuthor.client;
    final ai = switch (author) {
      MessageAuthor.julia ||
      MessageAuthor.david ||
      MessageAuthor.assistant ||
      MessageAuthor.welcome => true,
      _ => false,
    };
    final navy = !inbound && !ai;

    final bg = inbound
        ? pf.bubbleIn
        : ai
        ? pf.bubbleJulia
        : pf.bubbleOut;
    final fg = navy ? pf.bubbleOutText : pf.text;
    final timeColor = navy ? pf.bubbleOutTime : pf.text2;
    final readColor = navy ? pf.mint : (ai ? pf.juliaFg : pf.link);

    final label = switch (author) {
      MessageAuthor.julia => 'Julia',
      MessageAuthor.david => 'David',
      MessageAuthor.assistant => 'Asistente IA',
      MessageAuthor.welcome => 'Bienvenida automática',
      MessageAuthor.otherAgent => message.senderName ?? message.agent,
      _ => null,
    };

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(inbound ? 4 : 16),
      bottomRight: Radius.circular(inbound ? 16 : 4),
    );

    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    final isImage =
        message.type == 'image' &&
        (message.mediaUrl != null || message.localPath != null);
    final text = message.text;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: isImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        boxShadow: inbound
            ? const [
                BoxShadow(
                  color: Color(0x0F0F1222),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isImage ? 8 : 0,
                isImage ? 4 : 0,
                0,
                2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ai) ...[
                    Icon(Icons.auto_awesome, size: 12, color: pf.juliaFg),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ai ? pf.juliaFg : pf.bubbleOutTime,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (message.quotedBody != null || message.quotedType != null)
            _Quoted(message: message, navy: navy, onTap: onQuoteTap),
          if (message.localPath != null)
            LocalMediaView(message: message, color: fg)
          else if (isImage)
            _ImageContent(url: message.mediaUrl!, bg: pf.divider)
          else
            switch (message.type) {
              'audio' || 'ptt' || 'voice'
                  when message.mediaId != null || message.mediaUrl != null =>
                AudioMessageView(
                  message: message,
                  color: fg,
                  accent: readColor,
                ),
              'video'
                  when message.mediaId != null || message.mediaUrl != null =>
                VideoMessageView(message: message, color: fg),
              'document'
                  when message.mediaId != null || message.mediaUrl != null =>
                DocumentMessageView(message: message, color: fg),
              'location' => LocationMessageView(message: message, color: fg),
              'contacts' when message.contacts.isNotEmpty =>
                ContactsMessageView(message: message, color: fg),
              'text' when text != null => const SizedBox.shrink(),
              _ => _TypeChip(message: message, color: fg),
            },
          if (text != null && text.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isImage ? 8 : 0,
                isImage ? 6 : 0,
                isImage ? 8 : 0,
                0,
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 15, height: 21 / 15, color: fg),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isImage ? 8 : 0,
              2,
              isImage ? 8 : 0,
              isImage ? 4 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  hm(message.date),
                  style: TextStyle(fontSize: 11, color: timeColor),
                ),
                if (message.isOutbound) ...[
                  const SizedBox(width: 4),
                  MessageTicks(
                    status: message.hasError ? 'error' : message.status,
                    color: timeColor,
                    readColor: readColor,
                    errorColor: navy ? pf.errIcon : pf.errIcon,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final error = message.errorText;
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: inbound
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Semantics(
            container: true,
            label: _semanticLabel(label, author),
            onLongPress: onLongPress,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onLongPress: onLongPress,
                child: bubble,
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(error, style: TextStyle(fontSize: 12, color: pf.errFg)),
                  if (onRetry != null) _MiniAction('Reintentar', onRetry!),
                  if (onDiscard != null) _MiniAction('Descartar', onDiscard!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _semanticLabel(String? label, MessageAuthor author) {
    final who = author == MessageAuthor.client ? 'Cliente' : (label ?? 'Tú');
    final body = message.text?.isNotEmpty == true
        ? message.text!
        : labelForType(message.type);
    final status = message.isOutbound
        ? ', ${MessageTicks.labelFor(message.hasError ? 'error' : message.status)}'
        : '';
    return '$who, ${hm(message.date)}: $body$status';
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PfColors.of(context).link,
            ),
          ),
        ),
      ),
    );
  }
}

class _Quoted extends StatelessWidget {
  const _Quoted({required this.message, required this.navy, this.onTap});

  final Message message;
  final bool navy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final fg = navy ? pf.bubbleOutText : pf.textMid;
    final body =
        message.quotedBody ?? labelForType(message.quotedType ?? 'text');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: navy ? const Color(0x26FFFFFF) : pf.divider,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: navy ? pf.mint : pf.link, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.quotedFrom != null)
              Text(
                message.quotedFrom!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.message, required this.color});

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    var label = labelForType(message.type);
    if (message.type == 'document' && message.mediaFilename != null) {
      label = message.mediaFilename!;
    } else if (message.type == 'location' && message.locationLabel != null) {
      label = 'Ubicación · ${message.locationLabel}';
    } else if (message.type == 'contacts' && message.contactNames.isNotEmpty) {
      label = 'Contacto · ${message.contactNames.join(', ')}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForType(message.type), size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.url, required this.bg});

  final String url;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    Widget placeholder(IconData icon) => Container(
      width: 200,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: pf.text2),
    );

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  tooltip: 'Cerrar',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : placeholder(Icons.image_outlined),
          errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
