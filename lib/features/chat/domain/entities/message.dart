class ContactCard {
  const ContactCard({required this.name, this.phones = const []});

  final String name;
  final List<String> phones;
}

enum MessageAuthor { client, julia, david, assistant, welcome, me, otherAgent }

class Message {
  const Message({
    required this.id,
    required this.date,
    this.messageId,
    this.type = 'text',
    this.flow,
    this.text,
    this.status,
    this.reference,
    this.senderName,
    this.agent,
    this.responsibleId,
    this.source,
    this.mediaUrl,
    this.mediaFilename,
    this.quotedBody,
    this.quotedFrom,
    this.quotedWid,
    this.quotedType,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.contactNames = const [],
    this.contacts = const [],
    this.mediaId,
    this.mediaMime,
    this.localPath,
    this.uploadProgress,
    this.isLocal = false,
    this.errorText,
    this.websocketId,
  });

  final String id;

  /// `message_id` del JSON (id de WhatsApp): lo que el BO usa para citar y
  /// para los previews de media. Null si el servidor no lo envió.
  final String? messageId;
  final DateTime date;
  final String type;
  final String? flow;
  final String? text;
  final String? status;
  final String? reference;
  final String? senderName;
  final String? agent;
  final String? responsibleId;
  final String? source;
  final String? mediaUrl;
  final String? mediaFilename;
  final String? quotedBody;
  final String? quotedFrom;

  /// Id (wid) del mensaje citado; sirve para saltar a él si está cargado.
  final String? quotedWid;
  final String? quotedType;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final List<String> contactNames;
  final List<ContactCard> contacts;

  /// `media.id` (para preview/download de audio, video y documentos).
  final String? mediaId;
  final String? mediaMime;

  /// Archivo local de un mensaje saliente aún no confirmado.
  final String? localPath;

  /// 0..1 mientras se sube el archivo; null si no aplica.
  final double? uploadProgress;

  /// Mensaje optimista aún no confirmado por el servidor.
  final bool isLocal;
  final String? errorText;

  /// Id que Wali usa en los eventos de estado por WebSocket.
  final String? websocketId;

  /// Id a usar como `quote` y como `message_id` de previews (fallback a [id]).
  String get replyId => messageId ?? id;

  bool get isInbound => flow == 'inbound';
  bool get isOutbound => flow == 'outbound';
  bool get hasMedia => mediaId != null || mediaUrl != null || localPath != null;

  /// Texto a citar: cuerpo o, si no hay, el tipo.
  String get quoteBody =>
      (text != null && text!.trim().isNotEmpty) ? text! : type;

  bool get hasError => status == 'error' || errorText != null;

  /// `myUserId`: id de SAPI del usuario actual (para distinguir "mis" mensajes).
  MessageAuthor author(String? myUserId) {
    if (!isOutbound) return MessageAuthor.client;
    switch (reference) {
      case 'ai_analyzer':
      case 'order_taker':
        return MessageAuthor.julia;
      case 'quotation_refinement':
        return MessageAuthor.david;
      case 'oem_finder':
        return MessageAuthor.assistant;
      case 'welcome_message':
        return MessageAuthor.welcome;
    }
    if (responsibleId != null && responsibleId == myUserId) {
      return MessageAuthor.me;
    }
    if (responsibleId == null && isLocal) return MessageAuthor.me;
    return MessageAuthor.otherAgent;
  }

  Message copyWith({
    String? status,
    String? errorText,
    bool clearError = false,
    double? uploadProgress,
    bool clearProgress = false,
  }) => Message(
    id: id,
    messageId: messageId,
    date: date,
    type: type,
    flow: flow,
    text: text,
    status: status ?? this.status,
    reference: reference,
    senderName: senderName,
    agent: agent,
    responsibleId: responsibleId,
    source: source,
    mediaUrl: mediaUrl,
    mediaFilename: mediaFilename,
    quotedBody: quotedBody,
    quotedFrom: quotedFrom,
    quotedWid: quotedWid,
    quotedType: quotedType,
    locationLabel: locationLabel,
    latitude: latitude,
    longitude: longitude,
    contactNames: contactNames,
    contacts: contacts,
    mediaId: mediaId,
    mediaMime: mediaMime,
    localPath: localPath,
    uploadProgress: clearProgress
        ? null
        : (uploadProgress ?? this.uploadProgress),
    isLocal: isLocal,
    errorText: clearError ? null : (errorText ?? this.errorText),
    websocketId: websocketId,
  );
}
