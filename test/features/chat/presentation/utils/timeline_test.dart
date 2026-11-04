import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/timeline.dart';

import '../../_fixtures.dart';

void main() {
  final t0 = DateTime(2025, 1, 1, 10);
  DateTime at(int min) => t0.add(Duration(minutes: min));

  group('messageSig', () {
    test('combina hasMedia y texto recortado', () {
      expect(messageSig(msg('1', t0, text: '  hola ')), 'false|hola');
    });
    test('texto null equivale a vacío', () {
      expect(messageSig(msg('1', t0)), 'false|');
    });
    test('con media', () {
      expect(messageSig(msg('1', t0, mediaId: 'm', text: 'x')), 'true|x');
    });
  });

  group('buildTimeline', () {
    test('vacío devuelve vacío', () {
      expect(buildTimeline([], [], []), isEmpty);
    });
    test('un día: lista invertida con DayEntry al final (el más antiguo)', () {
      final r = buildTimeline([msg('a', at(0)), msg('b', at(1))], [], []);
      expect(r, hasLength(3));
      expect((r[0] as MsgEntry).message.id, 'b');
      expect((r[1] as MsgEntry).message.id, 'a');
      expect(r[2], isA<DayEntry>());
    });
    test('DayEntry en cada cambio de día', () {
      final r = buildTimeline(
        [
          msg('a', DateTime(2025, 1, 1, 23, 59)),
          msg('b', DateTime(2025, 1, 2, 0, 1)),
        ],
        [],
        [],
      );
      expect(r.map((e) => e.runtimeType), [
        MsgEntry,
        DayEntry,
        MsgEntry,
        DayEntry,
      ]);
    });
    test('ordena mensajes desordenados por fecha', () {
      final r = buildTimeline([msg('b', at(5)), msg('a', at(1))], [], []);
      expect((r.first as MsgEntry).message.id, 'b');
    });
    test('incluye pending y notas intercalados por fecha', () {
      final r = buildTimeline(
        [msg('a', at(0))],
        [msg('p', at(2), isLocal: true)],
        [ThreadNote(at(1), 'nota')],
      );
      expect(r.length, 4);
      expect((r[0] as MsgEntry).message.id, 'p');
      expect((r[1] as NoteEntry).note.text, 'nota');
      expect((r[2] as MsgEntry).message.id, 'a');
    });
  });

  group('messagesJoined', () {
    final entries = buildTimeline(
      [msg('c1', at(0), flow: 'inbound'), msg('c2', at(1), flow: 'inbound')],
      [],
      [],
    );
    test('índice fuera de rango es false', () {
      expect(
        messagesJoined(entries, -1, msg('x', at(1), flow: 'inbound'), null),
        isFalse,
      );
      expect(
        messagesJoined(entries, 99, msg('x', at(1), flow: 'inbound'), null),
        isFalse,
      );
    });
    test('entrada que no es mensaje (DayEntry) es false', () {
      expect(
        messagesJoined(
          entries,
          entries.length - 1,
          msg('x', at(1), flow: 'inbound'),
          null,
        ),
        isFalse,
      );
    });
    test('mismo cliente a <=2 min se une', () {
      expect(
        messagesJoined(
          entries,
          1,
          entries.first.let((e) => (e as MsgEntry).message),
          null,
        ),
        isTrue,
      );
    });
    test('más de 2 min no se une', () {
      expect(
        messagesJoined(entries, 1, msg('x', at(10), flow: 'inbound'), null),
        isFalse,
      );
    });
    test('exactamente 2 min se une', () {
      expect(
        messagesJoined(entries, 0, msg('x', at(3), flow: 'inbound'), null),
        isTrue,
      );
    });
    test('autores distintos no se unen', () {
      expect(
        messagesJoined(
          entries,
          0,
          msg('x', at(1), flow: 'outbound', senderName: 'A'),
          null,
        ),
        isFalse,
      );
    });
    test('agentes con distinto senderName no se unen', () {
      final e = buildTimeline(
        [
          msg(
            'o1',
            at(0),
            flow: 'outbound',
            senderName: 'A',
            responsibleId: 'u2',
          ),
        ],
        [],
        [],
      );
      final m = msg(
        'o2',
        at(1),
        flow: 'outbound',
        senderName: 'B',
        responsibleId: 'u2',
      );
      expect(messagesJoined(e, 0, m, null), isFalse);
    });
    test('eliminado vs no eliminado no se une', () {
      expect(
        messagesJoined(
          entries,
          0,
          msg('x', at(1), flow: 'inbound', status: 'removed'),
          null,
        ),
        isFalse,
      );
    });
  });

  group('classifyMessages', () {
    ClassifyResult run(
      List<Message> all, {
      required bool baselined,
      required Set<String> known,
      List<LocalSig>? sigs,
      DateTime? newest,
      DateTime? now,
    }) => classifyMessages(
      all: all,
      baselined: baselined,
      known: known,
      localSigs: sigs ?? [],
      newest: newest,
      now: now ?? at(0),
    );

    test('primer llamado solo registra, no anima', () {
      final known = <String>{};
      final r = run(
        [msg('a', at(1)), msg('b', at(2))],
        baselined: false,
        known: known,
      );
      expect(r.baselined, isTrue);
      expect(r.entered, isEmpty);
      expect(known, {'a', 'b'});
      expect(r.newest, at(2));
    });
    test('mensaje local nuevo es own y registra firma', () {
      final sigs = <LocalSig>[];
      final r = run(
        [msg('l', at(5), text: 'hi', isLocal: true)],
        baselined: true,
        known: {},
        sigs: sigs,
        newest: at(1),
      );
      expect(r.entered, {'l': EntranceKind.own});
      expect(sigs.single.sig, 'false|hi');
    });
    test('mensaje más viejo que newest se ignora', () {
      final r = run(
        [msg('old', at(1), flow: 'inbound')],
        baselined: true,
        known: {},
        newest: at(5),
      );
      expect(r.entered, isEmpty);
    });
    test('mensaje con fecha igual a newest se ignora', () {
      final r = run(
        [msg('eq', at(5), flow: 'inbound')],
        baselined: true,
        known: {},
        newest: at(5),
      );
      expect(r.entered, isEmpty);
    });
    test('inbound más nuevo es incoming y avanza newest', () {
      final r = run(
        [msg('n', at(9), flow: 'inbound')],
        baselined: true,
        known: {},
        newest: at(5),
      );
      expect(r.entered, {'n': EntranceKind.incoming});
      expect(r.newest, at(9));
    });
    test('id ya conocido no se anima', () {
      final r = run(
        [msg('n', at(9), flow: 'inbound')],
        baselined: true,
        known: {'n'},
        newest: at(5),
      );
      expect(r.entered, isEmpty);
    });
    test('outbound que confirma firma local se consume sin animar', () {
      final sigs = <LocalSig>[(sig: 'false|hola', at: at(0))];
      final r = run(
        [msg('s', at(9), flow: 'outbound', text: 'hola')],
        baselined: true,
        known: {},
        sigs: sigs,
        newest: at(5),
      );
      expect(r.entered, isEmpty);
      expect(sigs, isEmpty);
    });
    test('outbound sin firma local coincidente es incoming', () {
      final r = run(
        [msg('s', at(9), flow: 'outbound', text: 'otro')],
        baselined: true,
        known: {},
        sigs: [(sig: 'false|hola', at: at(0))],
        newest: at(5),
      );
      expect(r.entered, {'s': EntranceKind.incoming});
    });
    test(
      'media outbound consume firma local con media aunque el texto difiera',
      () {
        final sigs = <LocalSig>[(sig: 'true|', at: at(0))];
        final r = run(
          [msg('s', at(9), flow: 'outbound', mediaId: 'm', text: 'leyenda')],
          baselined: true,
          known: {},
          sigs: sigs,
          newest: at(5),
        );
        expect(r.entered, isEmpty);
        expect(sigs, isEmpty);
      },
    );
    test('varias firmas con media y texto exacto: consume la coincidente', () {
      final sigs = <LocalSig>[
        (sig: 'true|foto A', at: at(0)),
        (sig: 'true|foto B', at: at(0)),
      ];
      run(
        [msg('s', at(9), flow: 'outbound', mediaId: 'm', text: 'foto B')],
        baselined: true,
        known: {},
        sigs: sigs,
        newest: at(5),
        now: at(1),
      );
      // la coincidencia exacta tiene prioridad sobre el fallback de media.
      expect(sigs.map((e) => e.sig), ['true|foto A']);
    });
    test(
      'varias firmas con media y texto distinto: consume la primera, no la correcta',
      () {
        final sigs = <LocalSig>[
          (sig: 'true|foto A', at: at(0)),
          (sig: 'true|foto B', at: at(0)),
        ];
        run(
          [msg('s', at(9), flow: 'outbound', mediaId: 'm', text: 'confirmado')],
          baselined: true,
          known: {},
          sigs: sigs,
          newest: at(5),
          now: at(1),
        );
        // comportamiento actual: toma la primera firma con media.
        expect(sigs.map((e) => e.sig), ['true|foto B']);
      },
    );
    test('poda firmas locales de más de 2 minutos', () {
      final sigs = <LocalSig>[
        (sig: 'false|viejo', at: at(0)),
        (sig: 'false|justo', at: at(1)),
      ];
      run(
        [],
        baselined: true,
        known: {},
        sigs: sigs,
        newest: at(0),
        now: at(3),
      );
      // 'viejo' = 3 min (podado); 'justo' = 2 min exactos (se conserva).
      expect(sigs.map((e) => e.sig), ['false|justo']);
    });
    test('newest se mantiene si ya baselined y no hay mensajes más nuevos', () {
      final r = run(
        [msg('a', at(1), flow: 'inbound')],
        baselined: true,
        known: {'a'},
        newest: at(5),
      );
      expect(r.newest, at(5));
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
