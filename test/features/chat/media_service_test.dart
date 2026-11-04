import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_playback_coordinator.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/media_service.dart';

class _Repo implements ChatRepository {
  int previews = 0;
  int downloads = 0;
  bool failPreview = false;

  @override
  Future<Result<MediaPreview>> mediaPreview(
    RemoteMediaKind kind,
    String mediaId,
    String messageId,
  ) async {
    previews++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return failPreview
        ? Result.err(Failure.network())
        : Result.ok(MediaPreview(id: mediaId));
  }

  @override
  Future<Result<Uint8List?>> mediaDownload(
    RemoteMediaKind kind,
    String id,
  ) async {
    downloads++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Result.ok(Uint8List.fromList([1, 2, 3]));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAudio implements PausableAudio {
  int pauses = 0;
  @override
  Future<void> pause() async => pauses++;
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('pf_ms'));
  tearDown(() => dir.delete(recursive: true));

  test('preview: misma clave -> 1 request; error permite reintento', () async {
    final repo = _Repo();
    final s = MediaService(repo, cacheDir: () async => dir);
    await Future.wait([
      s.preview(RemoteMediaKind.audio, 'm1', 'x'),
      s.preview(RemoteMediaKind.audio, 'm1', 'x'),
    ]);
    await s.preview(RemoteMediaKind.audio, 'm1', 'x');
    expect(repo.previews, 1);
    await s.preview(RemoteMediaKind.video, 'm1', 'x');
    expect(repo.previews, 2);

    repo.failPreview = true;
    expect(await s.preview(RemoteMediaKind.audio, 'm2', 'x'), isA<Err>());
    repo.failPreview = false;
    expect(await s.preview(RemoteMediaKind.audio, 'm2', 'x'), isA<Ok>());
    expect(repo.previews, 4);
  });

  test('preview: LRU acotado', () async {
    final repo = _Repo();
    final s = MediaService(repo, cacheDir: () async => dir, previewCapacity: 2);
    for (final id in ['a', 'b', 'c']) {
      await s.preview(RemoteMediaKind.audio, id, 'x');
    }
    await s.preview(RemoteMediaKind.audio, 'a', 'x'); // expulsado -> request
    expect(repo.previews, 4);
  });

  test('descarga: 2 simultáneas -> 1; luego sale de disco', () async {
    final repo = _Repo();
    final s = MediaService(repo, cacheDir: () async => dir);
    Future<MediaFileResult> go() => s.fetchFile(
      kind: RemoteMediaKind.audio,
      downloadId: 'd1',
      cacheName: 'pf_audio_1.ogg',
    );
    final r = await Future.wait([go(), go()]);
    expect(r.every((e) => e.file != null), isTrue);
    await go();
    expect(repo.downloads, 1);
  });

  test('coordinador: reproducir B pausa A', () {
    final c = AudioPlaybackCoordinator();
    final a = _FakeAudio();
    final b = _FakeAudio();
    c.claim(a);
    c.claim(a);
    expect(a.pauses, 0);
    c.claim(b);
    expect(a.pauses, 1);
    expect(b.pauses, 0);
    c.release(b);
    expect(c.current, isNull);
  });
}
