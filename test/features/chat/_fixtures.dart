import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';

Message msg(
  String id,
  DateTime date, {
  String? text,
  String? flow,
  String? status,
  String? websocketId,
  String? mediaId,
  bool isLocal = false,
  String? senderName,
  String? reference,
  String? responsibleId,
}) => Message(
  id: id,
  date: date,
  text: text,
  flow: flow,
  status: status,
  websocketId: websocketId,
  mediaId: mediaId,
  isLocal: isLocal,
  senderName: senderName,
  reference: reference,
  responsibleId: responsibleId,
);

Chat chat(
  String id, {
  DateTime? lastMessageAt,
  ChatLastMessage? lastMessage,
  int unreadCount = 0,
  ChatClient? client,
}) => Chat(
  id: id,
  phone: id,
  lastMessageAt: lastMessageAt,
  lastMessage: lastMessage,
  unreadCount: unreadCount,
  client: client,
);
