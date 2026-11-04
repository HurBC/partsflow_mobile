import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_playback_coordinator.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_service.dart';

/// Servicio de media (previews memoizados + descargas deduplicadas). keepAlive:
/// sobrevive al cierre/reapertura de chats durante la sesión.
final mediaServiceProvider = Provider<MediaService>((ref) {
  ref.keepAlive();
  return MediaService(ref.watch(chatRepositoryProvider));
});

final audioPlaybackCoordinatorProvider = Provider<AudioPlaybackCoordinator>((
  ref,
) {
  ref.keepAlive();
  return AudioPlaybackCoordinator();
});
