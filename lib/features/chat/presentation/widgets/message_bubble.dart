import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/send_errors.dart';
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
    this.onTemplate,
    this.auraEntrance = false,
    this.reserveAvatar = false,
    this.flashSerial = 0,
    this.joinedPrev = false,
    this.joinedNext = false,
  });

  final Message message;
  final String? myUserId;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  /// Mantener pulsado: menú Responder / Copiar texto.
  final VoidCallback? onLongPress;

  /// Tocar la cita: saltar al mensaje original si está cargado.
  final VoidCallback? onQuoteTap;

  /// Error 131047 (fuera de la ventana de 24 h): abre el flujo de plantillas.
  final VoidCallback? onTemplate;

  /// Mensaje de Julia recién llegado en tiempo real: el aura del avatar entra
  /// más intensa y se asienta (una sola vez).
  final bool auraEntrance;

  /// El hilo tiene mensajes de Julia: los salientes reservan el hueco del
  /// avatar (36 px) a la derecha para quedar alineados.
  final bool reserveAvatar;

  /// > 0 destella la burbuja (salto desde una cita); cambia para repetir.
  final int flashSerial;

  /// Agrupación estilo WhatsApp: el mensaje anterior / siguiente es del mismo
  /// remitente y llegó casi junto. Cambia esquinas y oculta la etiqueta.
  final bool joinedPrev;
  final bool joinedNext;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
    final readColor = navy
        ? pf.mint
        : (ai ? (dark ? pf.mint : pf.juliaFg) : pf.link);

    final label = switch (author) {
      MessageAuthor.julia => 'Julia',
      MessageAuthor.david => 'David',
      MessageAuthor.assistant => 'Asistente IA',
      MessageAuthor.welcome => 'Bienvenida automática',
      MessageAuthor.otherAgent => message.senderName ?? message.agent,
      _ => null,
    };

    // Lado del remitente: las esquinas que tocan a un vecino bajan a 5 px;
    // el último del grupo conserva la "cola" (4 px) abajo.
    final top = Radius.circular(joinedPrev ? 5 : 16);
    final bottom = Radius.circular(joinedNext ? 5 : 4);
    const full = Radius.circular(16);
    final radius = BorderRadius.only(
      topLeft: inbound ? top : full,
      topRight: inbound ? full : top,
      bottomLeft: inbound ? bottom : full,
      bottomRight: inbound ? full : bottom,
    );

    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    final isImage =
        !message.isDeleted &&
        message.type == 'image' &&
        (message.mediaUrl != null || message.localPath != null);
    final deleted = message.isDeleted;
    var text = deleted ? null : message.text;
    // Documento cuyo pie repite el nombre del archivo: no se muestra dos veces.
    if (text != null &&
        message.type == 'document' &&
        text.trim() == message.mediaFilename?.trim()) {
      text = null;
    }
    final isTemplate = !deleted && message.type == 'template';
    final inlineMeta = text != null && text.isNotEmpty && !isImage;

    final isJulia = author == MessageAuthor.julia;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (message.isEdited && !deleted) ...[
          Text(
            'Editado',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: timeColor,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          hm(message.date),
          style: TextStyle(fontSize: 11, color: timeColor),
        ),
        if (message.isOutbound && !deleted) ...[
          const SizedBox(width: 4),
          MessageTicks(
            status: message.hasError ? 'error' : message.status,
            color: timeColor,
            readColor: readColor,
            errorColor: pf.errIcon,
          ),
        ],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && !joinedPrev)
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
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ai
                          ? (dark ? pf.mint : pf.juliaFg)
                          : pf.bubbleOutTime,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (deleted)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14, color: fg.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                'Mensaje eliminado',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ],
          )
        else if (message.quotedBody != null || message.quotedType != null)
          _Quoted(message: message, navy: navy, onTap: onQuoteTap),
        if (deleted)
          const SizedBox.shrink()
        else if (message.localPath != null)
          LocalMediaView(message: message, color: fg)
        else if (isImage)
          _ImageContent(url: message.mediaUrl!, bg: pf.divider)
        else
          switch (message.type) {
            'audio' || 'ptt' || 'voice'
                when message.mediaId != null || message.mediaUrl != null =>
              AudioMessageView(message: message, color: fg, accent: readColor),
            'video' when message.mediaId != null || message.mediaUrl != null =>
              VideoMessageView(message: message, color: fg),
            'document'
                when message.mediaId != null || message.mediaUrl != null =>
              DocumentMessageView(message: message, color: fg),
            'location' => LocationMessageView(message: message, color: fg),
            'contacts' when message.contacts.isNotEmpty => ContactsMessageView(
              message: message,
              color: fg,
            ),
            // Tipos que el BO muestra como texto plano (campo `message`).
            'text' ||
            'template' ||
            'button' ||
            'interactive' ||
            'link_preview' when text != null => const SizedBox.shrink(),
            _ => _TypeChip(message: message, color: fg),
          },
        if (isTemplate)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 12, color: timeColor),
                const SizedBox(width: 4),
                Text(
                  'Plantilla',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: timeColor,
                  ),
                ),
              ],
            ),
          ),
        if (inlineMeta)
          // Hora y ticks en la última línea del texto si caben (un espacio
          // invisible del tamaño de `meta` reserva el hueco); si no, bajan.
          Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: text,
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.bottom,
                      child: Visibility(
                        visible: false,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: meta,
                        ),
                      ),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 15, height: 21 / 15, color: fg),
              ),
              Positioned(right: 0, bottom: 2, child: meta),
            ],
          )
        else ...[
          if (text != null && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
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
            child: meta,
          ),
        ],
      ],
    );

    Widget decorated(double flash) {
      final color = Color.alphaBlend(
        pf.mint.withValues(alpha: 0.5 * flash),
        bg,
      );
      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: isJulia
              ? Border.all(
                  color: pf.mint.withValues(alpha: dark ? 0.28 : 0.55),
                  width: 1,
                )
              : null,
          boxShadow: !isJulia && inbound
              ? const [
                  BoxShadow(
                    color: Color(0x0F0F1222),
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: content,
      );
    }

    var bubble = decorated(0);
    if (flashSerial > 0) {
      bubble = TweenAnimationBuilder<double>(
        key: ValueKey('flash-$flashSerial'),
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, flash, _) => decorated(flash),
      );
    }

    // Avatar de Julia a la derecha, solo en el último mensaje del grupo; el
    // resto (y los salientes de otros autores en hilos con Julia) reserva el
    // mismo hueco.
    if (isJulia || (reserveAvatar && !inbound)) {
      bubble = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: bubble),
          const SizedBox(width: 8),
          if (isJulia && !joinedNext)
            _JuliaAvatar(animate: auraEntrance && !reduce)
          else
            const SizedBox(width: 28),
        ],
      );
    }

    final code = message.errorCode;
    final error =
        message.errorText ?? (code == null ? null : sendErrorText(code));
    final windowError =
        code != null && isWindowError(code) && onTemplate != null;
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
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Text(
                      error,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12, color: pf.errFg),
                    ),
                  ),
                  if (windowError) _MiniAction('Enviar plantilla', onTemplate!),
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
    final body = message.isDeleted
        ? 'Mensaje eliminado'
        : (message.text?.isNotEmpty == true
              ? message.text!
              : labelForType(message.type));
    final status = message.isOutbound
        ? ', ${MessageTicks.labelFor(message.hasError ? 'error' : message.status)}'
        : '';
    final edited = message.isEdited && !message.isDeleted ? ', editado' : '';
    final err = message.errorCode == null
        ? ''
        : '. ${sendErrorText(message.errorCode!)}';
    return '$who, ${hm(message.date)}: $body$edited$status$err';
  }
}

class _JuliaAvatar extends StatelessWidget {
  const _JuliaAvatar({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ring = dark ? 0.20 : 0.25;
    final glow = dark ? 0.55 : 0.6;
    Widget avatar(double t) {
      // t (1..0): entrada; el glow parte intenso (~0,85) y se asienta.
      final glowAlpha = glow + (0.85 - glow) * t;
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: pf.mint,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: pf.mint.withValues(alpha: ring),
              spreadRadius: 3,
              blurRadius: 0,
            ),
            BoxShadow(
              color: pf.mint.withValues(alpha: glowAlpha),
              spreadRadius: dark ? 3 : 2,
              blurRadius: dark ? 18 : 16,
            ),
          ],
        ),
        child: Icon(Icons.auto_awesome, size: 16, color: pf.onMint),
      );
    }

    if (!animate) return avatar(0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => avatar(t),
          ),
        ),
      ],
    );
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
      behavior: HitTestBehavior.opaque,
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
