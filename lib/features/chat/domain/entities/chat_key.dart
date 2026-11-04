import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';

/// Clave de la family del hilo de un chat. La igualdad es SOLO por [id]:
/// todos los call sites de un mismo chat comparten un único provider aunque su
/// snapshot [initial] difiera (el primero que se construya es el que se usa).
class ChatKey {
  const ChatKey(this.initial);

  /// Snapshot del chat con el que se crea el hilo.
  final Chat initial;

  String get id => initial.id;

  @override
  bool operator ==(Object other) => other is ChatKey && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
