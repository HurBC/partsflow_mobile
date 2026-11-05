import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/media_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/audio_waveform.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/audio_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_media.dart';

Widget _host(Widget child, {ProviderContainer? container}) =>
    UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('amplitud y muestras', () {
    test('normalizeDb: piso -50 dB → 0, 0 dB → 1, lineal en medio', () {
      expect(normalizeDb(-80), 0);
      expect(normalizeDb(-50), 0);
      expect(normalizeDb(-25), closeTo(0.5, 1e-9));
      expect(normalizeDb(0), 1);
      expect(normalizeDb(3), 1);
      expect(normalizeDb(double.nan), 0);
      expect(normalizeDb(double.negativeInfinity), 0);
    });

    test('downsampleWaveform reduce a N barras promediando', () {
      final r = downsampleWaveform(
        List.generate(100, (i) => i < 50 ? 0.0 : 1.0),
        bars: 4,
      );
      expect(r, [0, 0, 1, 1]);
      expect(downsampleWaveform(const []), isEmpty);
      expect(downsampleWaveform([0.5], bars: 3), [0.5, 0.5, 0.5]);
    });

    test('ciclo de velocidad y etiqueta', () {
      expect(nextAudioSpeed(1), 1.5);
      expect(nextAudioSpeed(1.5), 2);
      expect(nextAudioSpeed(2), 1);
      expect(audioSpeedLabel(1), '1×');
      expect(audioSpeedLabel(1.5), '1,5×');
      expect(audioSpeedLabel(2), '2×');
    });
  });

  group('AudioWaveformStore', () {
    test('tope de ondas enlazadas: se descartan las más antiguas', () {
      final s = AudioWaveformStore();
      for (var i = 0; i < maxLinkedWaveforms + 5; i++) {
        s.putForPath('/p$i', [0.5]);
        s.link('/p$i', 'id$i');
      }
      expect(s.linkedIds.length, maxLinkedWaveforms);
      expect(s.lookup(messageId: 'id0'), isNull);
      expect(s.lookup(messageId: 'id${maxLinkedWaveforms + 4}'), isNotNull);
    });

    test('pendiente por localPath; real por id tras link', () {
      final s = AudioWaveformStore();
      s.putForPath('/tmp/a.ogg', [0.1, 0.9]);
      expect(s.lookup(messageId: 'local-1', localPath: '/tmp/a.ogg'), [
        0.1,
        0.9,
      ]);
      expect(s.lookup(messageId: '77'), isNull);
      s.link('/tmp/a.ogg', '77');
      expect(s.lookup(messageId: '77'), [0.1, 0.9]);
      // Tras enlazar, la entrada por path se libera.
      expect(s.forPath('/tmp/a.ogg'), isNull);
      expect(s.linkedIds, {'77'});
      s.link('/otro', '78'); // sin onda registrada: no enlaza
      expect(s.lookup(messageId: '78'), isNull);
    });
  });

  group('velocidad del audio', () {
    testWidgets('el chip cicla 1× → 1,5× → 2× → 1× y expone su semántica', (
      t,
    ) async {
      final h = t.ensureSemantics();
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await t.pumpWidget(
        _host(
          AudioMessageView(
            message: Message(
              id: 'm1',
              date: DateTime(2026),
              type: 'audio',
              flow: 'outbound',
            ),
            color: Colors.black,
            accent: Colors.blue,
          ),
          container: c,
        ),
      );
      expect(
        find.bySemanticsLabel('Velocidad de reproducción, 1×'),
        findsOneWidget,
      );
      await t.tap(find.text('1×'));
      await t.pump();
      expect(c.read(audioSpeedProvider), 1.5);
      final chip = find.bySemanticsLabel('Velocidad de reproducción, 1,5×');
      expect(
        t.getSemantics(chip),
        matchesSemantics(
          label: 'Velocidad de reproducción, 1,5×',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: false,
        ),
      );
      expect(
        find.bySemanticsLabel('Velocidad de reproducción, 1,5×'),
        findsOneWidget,
      );
      await t.tap(find.text('1,5×'));
      await t.pump();
      await t.tap(find.text('2×'));
      await t.pump();
      expect(c.read(audioSpeedProvider), 1.0);
      h.dispose();
    });

    testWidgets('sin onda se mantiene el Slider; con onda se usa la barra', (
      t,
    ) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      Message msg(String id, {String? path}) => Message(
        id: id,
        date: DateTime(2026),
        type: 'audio',
        flow: 'outbound',
        localPath: path,
      );
      Widget view(Message m) => _host(
        AudioMessageView(message: m, color: Colors.black, accent: Colors.blue),
        container: c,
      );
      await t.pumpWidget(view(msg('a')));
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(WaveformSeekBar), findsNothing);

      c
          .read(audioWaveformStoreProvider)
          .putForPath('/tmp/x.ogg', List.filled(28, 0.5));
      await t.pumpWidget(view(msg('local-9', path: '/tmp/x.ogg')));
      await t.pump();
      expect(find.byType(WaveformSeekBar), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('pickWaveformCandidate', () {
    final t0 = DateTime(2026, 1, 1, 12);
    Message a(String id, {String? ref, String? resp = 'me', int sec = 0}) =>
        Message(
          id: id,
          date: t0.add(Duration(seconds: sec)),
          type: 'audio',
          flow: 'outbound',
          reference: ref,
          responsibleId: resp,
        );

    test('no enlaza audios de Julia ni de otro operador', () {
      final r = pickWaveformCandidate(
        [a('j', ref: 'order_taker'), a('o', resp: 'otro')],
        knownIds: {},
        linkedIds: {},
        localDate: t0,
        myUserId: 'me',
      );
      expect(r, isNull);
    });

    test('envíos concurrentes: no se intercambian ni se reutilizan', () {
      final msgs = [a('A', sec: 1), a('B', sec: 4)];
      // A (local en t0) y B (local en t0+3 s) con ambos ya visibles.
      final forB = pickWaveformCandidate(
        msgs,
        knownIds: {},
        linkedIds: {},
        localDate: t0.add(const Duration(seconds: 3)),
        myUserId: 'me',
      );
      expect(forB, 'B');
      final forA = pickWaveformCandidate(
        msgs,
        knownIds: {},
        linkedIds: {'B'},
        localDate: t0,
        myUserId: 'me',
      );
      expect(forA, 'A');
      // Ya enlazado y sin otro candidato: no se asigna.
      expect(
        pickWaveformCandidate(
          [a('A', sec: 1)],
          knownIds: {},
          linkedIds: {'A'},
          localDate: t0,
          myUserId: 'me',
        ),
        isNull,
      );
    });

    test('ignora conocidos previos y fechas lejanas', () {
      expect(
        pickWaveformCandidate(
          [a('old'), a('far', sec: 600)],
          knownIds: {'old'},
          linkedIds: {},
          localDate: t0,
          myUserId: 'me',
        ),
        isNull,
      );
    });
  });

  group('RecordingPill', () {
    testWidgets('con reducir animaciones no hay loop; sin él sí', (t) async {
      final bars = ValueNotifier<List<double>>(List.filled(24, 0.4));
      addTearDown(bars.dispose);
      Widget pill(bool reduce) =>
          _host(RecordingPill(bars: bars, time: '0:03', reduceMotion: reduce));
      await t.pumpWidget(pill(true));
      await t.pumpAndSettle(); // sin loop: debe asentarse
      await t.pumpWidget(pill(false));
      // El latido es un loop: nunca se asienta.
      var settled = true;
      try {
        await t.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
      } on FlutterError {
        settled = false;
      }
      expect(settled, isFalse);
      await t.pumpWidget(pill(true)); // al activar reducir se detiene
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox()); // dispose sin ticker colgado
    });
  });

  testWidgets('WaveformSeekBar informa la fracción tocada', (t) async {
    double? got;
    await t.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          child: WaveformSeekBar(
            bars: List.filled(28, 0.5),
            color: Colors.black,
            progress: 0,
            onSeek: (f) => got = f,
          ),
        ),
      ),
    );
    final box = t.getTopLeft(find.byType(WaveformSeekBar));
    await t.tapAt(box + const Offset(150, 10));
    expect(got, closeTo(0.75, 0.02));
  });
}
