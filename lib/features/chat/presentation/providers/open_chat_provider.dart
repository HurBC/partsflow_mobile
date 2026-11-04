import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registro (no reactivo) de los chats abiertos. Cuenta aperturas por
/// Chat.id: con A abierto y B apilado, cerrar B deja A abierto; un pop+push
/// rápido del mismo chat no borra la marca. Al no notificar, se puede
/// modificar durante initState/dispose sin restricciones de Riverpod. La lista
/// lo consulta con [isOpen] para no sumar no leídos del chat que se está viendo.
class OpenChatRegistry {
  final _counts = <String, int>{};

  void open(String id) => _counts[id] = (_counts[id] ?? 0) + 1;

  void close(String id) {
    final n = _counts[id];
    if (n == null) return;
    if (n <= 1) {
      _counts.remove(id);
    } else {
      _counts[id] = n - 1;
    }
  }

  bool isOpen(String id) => (_counts[id] ?? 0) > 0;
}

final openChatRegistryProvider = Provider<OpenChatRegistry>(
  (ref) {
    ref.keepAlive();
    return OpenChatRegistry();
  },
);
