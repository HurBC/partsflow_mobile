import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/utils/reload_gate.dart';

void main() {
  late DateTime t;
  late ReloadGate gate;
  late int calls;

  Future<void> load() async {
    calls++;
    gate.markSuccess();
  }

  setUp(() {
    t = DateTime(2026);
    calls = 0;
    gate = ReloadGate(now: () => t);
  });

  test('dos automáticas seguidas -> 1 request', () async {
    await gate.auto(load);
    await gate.auto(load);
    expect(calls, 1);
  });

  test('automática pasado el cooldown vuelve a cargar', () async {
    await gate.auto(load);
    t = t.add(const Duration(seconds: 6));
    await gate.auto(load);
    expect(calls, 2);
  });

  test('explícita tras automática -> 2 requests', () async {
    await gate.auto(load);
    await gate.track(load);
    expect(calls, 2);
  });

  test('en vuelo: la segunda reutiliza la primera', () async {
    final c = Completer<void>();
    final f1 = gate.auto(() {
      calls++;
      return c.future;
    });
    final f2 = gate.auto(load);
    expect(calls, 1);
    c.complete();
    await Future.wait([f1, f2]);
    expect(calls, 1);
    expect(gate.inFlight, isFalse);
  });

  test('un fallo no activa el cooldown', () async {
    await gate.auto(() async => calls++);
    await gate.auto(load);
    expect(calls, 2);
  });

  group('signal', () {
    late FakeAsync fa;
    late ReloadGate g;
    late int n;
    late DateTime start;

    Future<void> ok() async {
      n++;
      g.markSuccess();
    }

    void run(void Function() body) {
      start = DateTime(2026);
      fakeAsync((f) {
        fa = f;
        g = ReloadGate(now: () => f.getClock(start).now());
        n = 0;
        body();
      });
    }

    test('sin carga reciente: inmediata', () {
      run(() {
        g.signal(ok);
        fa.flushMicrotasks();
        expect(n, 1);
      });
    });

    test('durante vuelo (3 señales): 1 extra al terminar', () {
      run(() {
        final c = Completer<void>();
        g.track(() {
          n++;
          return c.future;
        });
        g.signal(ok);
        g.signal(ok);
        g.signal(ok);
        fa.flushMicrotasks();
        expect(n, 1);
        c.complete();
        fa.flushMicrotasks();
        expect(n, 2);
        fa.elapse(const Duration(minutes: 1));
        expect(n, 2);
      });
    });

    test('dentro del cooldown (3 señales): 1 al cumplirse, no antes', () {
      run(() {
        g.auto(ok);
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        g.signal(ok);
        g.signal(ok);
        g.signal(ok);
        fa.elapse(const Duration(milliseconds: 2900));
        expect(n, 1);
        fa.elapse(const Duration(milliseconds: 200));
        fa.flushMicrotasks();
        expect(n, 2);
        fa.elapse(const Duration(minutes: 1));
        expect(n, 2);
      });
    });

    test('dispose cancela el timer pendiente', () {
      run(() {
        g.auto(ok);
        fa.flushMicrotasks();
        g.signal(ok);
        g.dispose();
        fa.elapse(const Duration(minutes: 1));
        expect(n, 1);
        g.signal(ok);
        fa.flushMicrotasks();
        expect(n, 1);
      });
    });

    test('fallo de la trailing no reintenta', () {
      run(() {
        final c = Completer<void>();
        g.track(() => c.future);
        g.signal(() async {
          n++;
          throw StateError('x');
        });
        c.complete();
        fa.flushMicrotasks();
        fa.elapse(const Duration(minutes: 1));
        expect(n, 1);
      });
    });

    test('signalGap propio: trailing al cumplirse el gap, no el cooldown', () {
      run(() {
        g = ReloadGate(
          signalGap: const Duration(seconds: 1),
          now: () => fa.getClock(start).now(),
        );
        g.auto(ok);
        fa.flushMicrotasks();
        fa.elapse(const Duration(milliseconds: 300));
        g.signal(ok);
        g.signal(ok);
        fa.elapse(const Duration(milliseconds: 600));
        expect(n, 1);
        fa.elapse(const Duration(milliseconds: 200));
        fa.flushMicrotasks();
        expect(n, 2);
        fa.elapse(const Duration(minutes: 1));
        expect(n, 2);
      });
    });

    test('signal pasado el gap (dentro del cooldown): inmediata', () {
      run(() {
        g = ReloadGate(
          signalGap: const Duration(seconds: 1),
          now: () => fa.getClock(start).now(),
        );
        g.auto(ok);
        fa.flushMicrotasks();
        fa.elapse(const Duration(milliseconds: 1500));
        g.signal(ok);
        fa.flushMicrotasks();
        expect(n, 2);
      });
    });

    test('un gate nuevo tras dispose funciona', () {
      run(() {
        g.dispose();
        g = ReloadGate(now: () => fa.getClock(start).now());
        g.signal(ok);
        fa.flushMicrotasks();
        expect(n, 1);
      });
    });
  });
}
