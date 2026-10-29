import 'dart:async';

import 'package:partsflow_mobile/core/config/app_info.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_session.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'realtime_provider.g.dart';

final _uuid = RegExp(r'^[0-9a-f-]{8,}$');

/// Conexión de tiempo real. El estado es "¿hay conexión en tiempo real?".
/// Conecta tras el login y se cierra con el logout; sin `WS_BASE_URL` /
/// `WS_ORIGIN` no hace nada (solo sondeo).
@Riverpod(keepAlive: true)
class Realtime extends _$Realtime {
  final _events = StreamController<RealtimeEvent>.broadcast();

  /// Eventos del servidor (más `RealtimeResync` en cada conexión).
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  bool build() {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading || auth.value != true) return false;
    if (wsBaseUrl.isEmpty || wsOrigin.isEmpty) return false;
    final me = ref.watch(currentUserProvider).value;
    // El servidor solo acepta ids en minúscula (hex y guiones).
    final id = me?.subsidiaryId.trim().toLowerCase() ?? '';
    if (!_uuid.hasMatch(id)) return false;

    final session = RealtimeSession(
      baseUrl: wsBaseUrl,
      origin: wsOrigin,
      subsidiaryId: id,
      onEvent: (e) {
        if (ref.mounted && !_events.isClosed) _events.add(e);
      },
      onConnectedChanged: (v) {
        if (ref.mounted && state != v) state = v;
      },
    );
    ref.onDispose(session.dispose);
    session.start();
    return false;
  }
}
