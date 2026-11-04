import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/media/async_dedupe_cache.dart';
import 'package:partsflow_mobile/core/media/media_cache_purge.dart';

void main() {
  group('AsyncDedupeCache', () {
    test('misma clave: un solo load, incluso simultáneo', () async {
      var calls = 0;
      final c = AsyncDedupeCache<String, int>(maxEntries: 5);
      final c1 = Completer<int>();
      final a = c.load('k', () {
        calls++;
        return c1.future;
      });
      final b = c.load('k', () {
        calls++;
        return Future.value(0);
      });
      c1.complete(7);
      expect(await a, 7);
      expect(await b, 7);
      expect(await c.load('k', () async => calls++), 7);
      expect(calls, 1);
    });

    test('error no se cachea: permite reintento', () async {
      var calls = 0;
      final c = AsyncDedupeCache<String, int>(
        maxEntries: 5,
        cacheable: (v) => v > 0,
      );
      expect(await c.load('k', () async => (calls++, -1).$2), -1);
      expect(await c.load('k', () async => (calls++, 3).$2), 3);
      expect(calls, 2);
      final t = AsyncDedupeCache<String, int>(maxEntries: 5);
      await expectLater(
        t.load('x', () async => throw StateError('x')),
        throwsStateError,
      );
      expect(await t.load('x', () async => 1), 1);
    });

    test('LRU acotado', () async {
      final c = AsyncDedupeCache<int, int>(maxEntries: 2);
      await c.load(1, () async => 1);
      await c.load(2, () async => 2);
      await c.load(1, () async => 99); // toca 1 => 2 es el más viejo
      await c.load(3, () async => 3);
      expect(c.length, 2);
      expect(c.containsKey(2), isFalse);
      expect(c.containsKey(1) && c.containsKey(3), isTrue);
    });

    test('maxEntries 0: solo dedupe in-flight', () async {
      var calls = 0;
      final c = AsyncDedupeCache<String, int>(maxEntries: 0);
      final comp = Completer<int>();
      final f = [
        c.load('k', () {
          calls++;
          return comp.future;
        }),
        c.load('k', () {
          calls++;
          return comp.future;
        }),
      ];
      comp.complete(1);
      await Future.wait(f);
      await c.load('k', () async => calls++);
      expect(calls, 2);
    });
  });

  group('purgeMediaCache', () {
    late Directory tmp;
    final now = DateTime(2026, 11, 4, 12);
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('pf_purge');
      await Directory('${tmp.path}/pf_media').create();
    });
    tearDown(() => tmp.delete(recursive: true));

    Future<File> mk(String rel, int size, Duration age) async {
      final f = File('${tmp.path}/$rel');
      await f.writeAsBytes(List.filled(size, 1));
      await f.setLastModified(now.subtract(age));
      return f;
    }

    test('borra > 7 días y legacy; conserva recientes y ajenos', () async {
      final old = await mk('pf_media/a.ogg', 10, const Duration(days: 8));
      final fresh = await mk('pf_media/b.ogg', 10, const Duration(days: 1));
      final legacy = await mk('pf_audio_1.ogg', 10, const Duration(days: 9));
      final pegado = await mk('pegado-1.png', 10, const Duration(days: 9));
      final other = await mk('other.tmp', 10, const Duration(days: 30));
      final r = await purgeMediaCache(tmp, now: () => now);
      expect(old.existsSync(), isFalse);
      expect(legacy.existsSync(), isFalse);
      expect(pegado.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
      expect(r.deleted, 3);
    });

    test('tope de tamaño borra los más viejos primero', () async {
      final a = await mk('pf_media/a', 100, const Duration(days: 3));
      final b = await mk('pf_media/b', 100, const Duration(days: 2));
      final c = await mk('pf_media/c', 100, const Duration(days: 1));
      await purgeMediaCache(tmp, now: () => now, maxBytes: 150);
      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isFalse);
      expect(c.existsSync(), isTrue);
    });

    test('archivos muy recientes nunca se tocan', () async {
      final f = await mk('pf_media/x', 1000, const Duration(minutes: 2));
      final g = await mk('pf_rec_1.m4a', 1000, const Duration(days: 20));
      final h = await mk('pf_rec_2.m4a', 1000, const Duration(minutes: 1));
      await purgeMediaCache(tmp, now: () => now, maxBytes: 10);
      expect(f.existsSync(), isTrue);
      expect(h.existsSync(), isTrue);
      expect(g.existsSync(), isFalse);
    });

    test(
      'tope de tamaño no borra pf_rec_* ni pegado-* (solo por edad)',
      () async {
        final rec = await mk('pf_rec_1.m4a', 100, const Duration(days: 5));
        final peg = await mk('pegado-1.png', 100, const Duration(days: 6));
        final a = await mk('pf_media/a', 100, const Duration(days: 1));
        await purgeMediaCache(tmp, now: () => now, maxBytes: 50);
        expect(rec.existsSync(), isTrue);
        expect(peg.existsSync(), isTrue);
        expect(a.existsSync(), isFalse);
      },
    );
  });
}
