import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/ui/pf_haptics.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/julia_working_indicator.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

Finder get _burst => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_BurstPainter',
);

Widget _sw(bool v, {bool celebrate = true}) => PfSwitch(
  value: v,
  onIcon: Icons.auto_awesome,
  offIcon: Icons.pause_rounded,
  celebrate: celebrate,
);

double _burstValue(WidgetTester t) {
  final cp = t.widget<CustomPaint>(_burst);
  return ((cp.painter! as dynamic).anim as Animation<double>).value;
}

void main() {
  testWidgets('celebrate: la ráfaga solo corre al pasar a ON', (t) async {
    await t.pumpWidget(_host(_sw(false)));
    expect(_burstValue(t), 0);
    await t.pumpWidget(_host(_sw(true)));
    await t.pump(const Duration(milliseconds: 100));
    expect(_burstValue(t), greaterThan(0));
    await t.pumpAndSettle();
    expect(_burstValue(t), 1);
    // Pausar no la dispara.
    await t.pumpWidget(_host(_sw(false)));
    await t.pump(const Duration(milliseconds: 100));
    expect(_burstValue(t), 1);
    await t.pumpAndSettle();
  });

  testWidgets('sin celebrate no hay ráfaga', (t) async {
    await t.pumpWidget(_host(_sw(false, celebrate: false)));
    await t.pumpWidget(_host(_sw(true, celebrate: false)));
    await t.pumpAndSettle();
    expect(_burst, findsNothing);
  });

  testWidgets('reducir animaciones: no hay ráfaga', (t) async {
    await t.pumpWidget(_host(_sw(false), reduce: true));
    await t.pumpWidget(_host(_sw(true), reduce: true));
    await t.pump(const Duration(milliseconds: 100));
    expect(_burstValue(t), 0);
    await t.pumpAndSettle();
  });

  testWidgets('el ícono cambia con el valor', (t) async {
    await t.pumpWidget(_host(_sw(false)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await t.pumpWidget(_host(_sw(true)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('API antigua (sin íconos) sigue funcionando', (t) async {
    await t.pumpWidget(_host(const PfSwitch(value: true)));
    await t.pumpAndSettle();
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('indicador: texto, liveRegion y sin loops con reduce', (t) async {
    await t.pumpWidget(_host(const JuliaWorkingIndicator(), reduce: true));
    await t.pumpAndSettle();
    expect(find.text(juliaWorkingText), findsOneWidget);
    expect(find.bySemanticsLabel(juliaWorkingText), findsOneWidget);
  });

  testWidgets('indicador anima en loop sin reduce y se libera', (t) async {
    await t.pumpWidget(_host(const JuliaWorkingIndicator()));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(_host(const SizedBox()));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('píldora: celebra solo si el cambio a ON fue un toque', (
    t,
  ) async {
    var consumed = 0;
    var tap = false;
    bool consume() {
      consumed++;
      final v = tap;
      tap = false;
      return v;
    }

    Widget pill(bool v) =>
        _host(JuliaPill(julia: v, consumeCelebrate: consume));
    await t.pumpWidget(pill(false));
    // Cambio ajeno (realtime / revert): sin ráfaga.
    await t.pumpWidget(pill(true));
    await t.pump(const Duration(milliseconds: 100));
    expect(consumed, 1);
    expect(_burst, findsNothing);
    await t.pumpAndSettle();
    await t.pumpWidget(pill(false));
    await t.pumpAndSettle();
    // Toque del usuario: ráfaga.
    tap = true;
    await t.pumpWidget(pill(true));
    await t.pump(const Duration(milliseconds: 100));
    expect(_burstValue(t), greaterThan(0));
    await t.pumpAndSettle();
  });

  testWidgets('indicador: altura anima desde 0 y no snapea', (t) async {
    await t.pumpWidget(_host(const JuliaWorkingIndicator()));
    final h0 = t.getSize(find.byType(JuliaWorkingIndicator)).height;
    await t.pump(const Duration(milliseconds: 150));
    final h1 = t.getSize(find.byType(JuliaWorkingIndicator)).height;
    await t.pump(const Duration(milliseconds: 400));
    final h2 = t.getSize(find.byType(JuliaWorkingIndicator)).height;
    expect(h0, lessThan(h1));
    expect(h1, lessThan(h2));
    await t.pumpWidget(_host(const SizedBox()));
  });

  test('PfHaptics dispara el canal correcto (siempre)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
          if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
          return null;
        });
    PfHaptics.light();
    PfHaptics.selection();
    PfHaptics.success();
    PfHaptics.error();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
