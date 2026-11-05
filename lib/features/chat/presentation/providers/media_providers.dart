import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_playback_coordinator.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_waveform.dart';
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

/// Ondas de audios propios (memoria de sesión).
final audioWaveformStoreProvider = Provider<AudioWaveformStore>((ref) {
  ref.keepAlive();
  return AudioWaveformStore();
});

/// Última velocidad de reproducción elegida (sesión; se reinicia con la app).
class AudioSpeedNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  /// Avanza 1× → 1.5× → 2× → 1× y devuelve la nueva.
  double cycle() => state = nextAudioSpeed(state);
}

final audioSpeedProvider = NotifierProvider<AudioSpeedNotifier, double>(
  AudioSpeedNotifier.new,
);
