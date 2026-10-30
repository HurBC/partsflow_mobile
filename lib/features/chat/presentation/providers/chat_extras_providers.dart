import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message_template.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/quick_answer.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_extras_providers.g.dart';

/// Respuestas rápidas del proveedor (se recargan al cambiar de usuario).
/// Si falla, lanza: la UI ofrece reintentar con `ref.invalidate`.
@riverpod
Future<List<QuickAnswer>> quickAnswers(Ref ref) async {
  await ref.watch(currentUserProvider.future);
  final r = await ref.read(chatRepositoryProvider).quickAnswers();
  return switch (r) {
    Ok(:final value) => value,
    Err() => throw StateError('quick answers'),
  };
}

/// Plantillas aprobadas (sin `hello_world`).
@riverpod
Future<List<MessageTemplate>> approvedTemplates(Ref ref) async {
  await ref.watch(currentUserProvider.future);
  final r = await ref.read(chatRepositoryProvider).templates();
  return switch (r) {
    Ok(:final value) =>
      value
          .where((t) => t.status == 'APPROVED' && t.name != 'hello_world')
          .toList(),
    Err() => throw StateError('templates'),
  };
}

/// Etiquetas del proveedor para el filtro de la lista.
@riverpod
Future<List<ClientTag>> filterTags(Ref ref) async {
  await ref.watch(currentUserProvider.future);
  final r = await ref.read(chatRepositoryProvider).allTags();
  return switch (r) {
    Ok(:final value) => value,
    Err() => throw StateError('tags'),
  };
}

/// Estados de cliente disponibles en la sucursal.
@riverpod
Future<List<String>> filterStatuses(Ref ref) async {
  await ref.watch(currentUserProvider.future);
  final r = await ref.read(chatRepositoryProvider).clientStatuses();
  return switch (r) {
    Ok(:final value) => value,
    Err() => throw StateError('statuses'),
  };
}
