import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/network/token_refresher.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state_provider.g.dart';

@riverpod
Future<bool> authState(Ref ref) async {
  final token = await ref.read(tokenStoreProvider).readToken();
  if (token == null) return false;

  // Token guardado ya vencido (o por vencer): renovar antes de decidir.
  if (ref.read(tokenRefresherProvider).isTokenExpiring(token)) {
    final result = await ref.read(tokenRefresherProvider).refresh();
    // Solo un rechazo definitivo cierra la sesión; sin red se conserva.
    return result != RefreshResult.rejected;
  }
  return true;
}

/// Identidad de sesión: `true` solo con sesión activa. Los consumidores de
/// larga vida (sockets, listas) observan esto y no `authState` completo: un
/// `invalidate` con la misma sesión pasa por loading conservando el valor
/// previo, así que este provider no notifica y nada se reconstruye.
final sessionActiveProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider.select((a) => a.value == true)),
  name: 'sessionActiveProvider',
);
