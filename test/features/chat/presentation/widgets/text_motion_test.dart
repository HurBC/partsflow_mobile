import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/composer_action_button.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_ticks.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('ErrorShake', () {
    Widget shake(bool err, void Function() on) => _host(
      ErrorShake(error: err, onError: on, child: const SizedBox(width: 20)),
    );

    testWidgets('dispara una vez por transición a error', (t) async {
      var n = 0;
      await t.pumpWidget(shake(false, () => n++));
      await t.pumpWidget(shake(true, () => n++));
      expect(n, 1);
      await t.pumpWidget(shake(true, () => n++)); // rebuild en error
      await t.pump(const Duration(milliseconds: 500));
      expect(n, 1);
      await t.pumpWidget(shake(false, () => n++));
      await t.pumpWidget(shake(true, () => n++)); // nuevo fallo
      await t.pump(const Duration(milliseconds: 500));
      expect(n, 2);
    });

    testWidgets('montarse ya en error no dispara', (t) async {
      var n = 0;
      await t.pumpWidget(shake(true, () => n++));
      await t.pump(const Duration(milliseconds: 500));
      expect(n, 0);
    });
  });

  group('ComposerActionButton', () {
    testWidgets('enviar: háptica light solo si se envió', (t) async {
      final calls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (c) async {
          if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var sent = false;
      var recorded = 0;
      await t.pumpWidget(
        _host(
          ComposerActionButton(
            hasText: true,
            onSend: () => sent,
            onRecord: () => recorded++,
          ),
        ),
      );
      await t.tap(find.byType(InkWell));
      await t.pump();
      expect(calls, isEmpty);
      sent = true;
      await t.tap(find.byType(InkWell));
      await t.pump(const Duration(milliseconds: 400));
      expect(calls, ['HapticFeedbackType.lightImpact']);
      expect(recorded, 0);
    });

    testWidgets('sin texto graba', (t) async {
      var recorded = 0;
      await t.pumpWidget(
        _host(
          ComposerActionButton(
            hasText: false,
            onSend: () => true,
            onRecord: () => recorded++,
          ),
        ),
      );
      await t.tap(find.byType(InkWell));
      expect(recorded, 1);
    });
  });

  group('MessageEntrance own', () {
    testWidgets('anima una vez y termina en estado final', (t) async {
      await t.pumpWidget(
        _host(
          const MessageEntrance(
            animate: true,
            kind: MessageEntranceKind.own,
            child: SizedBox(key: Key('b'), width: 40, height: 20),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      final mid = t.getTopLeft(find.byKey(const Key('b')));
      await t.pump(const Duration(milliseconds: 600));
      final end = t.getTopLeft(find.byKey(const Key('b')));
      expect(mid.dy, greaterThan(end.dy));
    });
  });

  group('MessageTicks', () {
    Widget ticks(String s, {bool reduce = false}) => _host(
      MessageTicks(status: s, color: Colors.grey, readColor: Colors.blue),
      reduce: reduce,
    );

    testWidgets('pasar a enviado dibuja; montar ya enviado no', (t) async {
      await t.pumpWidget(ticks('sent'));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(ticks('pending'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpWidget(ticks('sent'));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Enviado'), findsOneWidget);
    });

    testWidgets('en reposo no hay animaciones ni controladores', (t) async {
      await t.pumpWidget(ticks('read'));
      expect(t.hasRunningAnimations, isFalse);
      expect(
        find.descendant(
          of: find.byType(MessageTicks),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    });

    testWidgets('reducir animaciones: sin animación de trazo', (t) async {
      await t.pumpWidget(ticks('pending', reduce: true));
      await t.pumpWidget(ticks('delivered', reduce: true));
      await t.pump(const Duration(milliseconds: 20));
      await t.pumpAndSettle();
    });
  });
}
