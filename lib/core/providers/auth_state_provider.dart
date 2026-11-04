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
