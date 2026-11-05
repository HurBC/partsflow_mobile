import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/ui/toast/pf_toast.dart';

late BuildContext _ctx;

Widget _app({bool disableAnimations = false, double? clearance}) {
  Widget body = Builder(
    builder: (c) {
      _ctx = c;
      return const SizedBox.expand();
    },
  );
  if (clearance != null) {
    body = PfToastScope(bottomClearance: clearance, child: body);
  }
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(body: body),
  );
}

/// Deja correr la animación de salida (el ticker arranca en el cuadro siguiente).
Future<void> _out(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

void main() {
  tearDown(PfToast.dismiss);

  testWidgets('muestra título y cuerpo', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Hola', body: 'Detalle', kind: PfToastKind.julia);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Hola'), findsOneWidget);
    expect(find.text('Detalle'), findsOneWidget);
    PfToast.dismiss();
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('autocierra tras la duración del tipo', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Listo', kind: PfToastKind.success);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Listo'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await _out(t);
    expect(find.text('Listo'), findsNothing);
  });

  testWidgets('con acción persiste y ejecuta onAction', (t) async {
    await t.pumpWidget(_app());
    var taps = 0;
    PfToast.show(
      _ctx,
      'Falló',
      kind: PfToastKind.warning,
      actionLabel: 'Reintentar',
      onAction: () => taps++,
    );
    await t.pump(const Duration(seconds: 20));
    expect(find.text('Falló'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    expect(taps, 1);
    await _out(t);
    expect(find.text('Falló'), findsNothing);
  });

  testWidgets('cerrar tiene etiqueta accesible y cierra', (t) async {
    final sem = t.ensureSemantics();
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Persistente', actionLabel: 'Ok', onAction: () {});
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.bySemanticsLabel('Cerrar aviso'));
    await _out(t);
    expect(find.text('Persistente'), findsNothing);
    sem.dispose();
  });

  testWidgets('la acción que muestra otro aviso no lo cierra', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(
      _ctx,
      'Primero',
      actionLabel: 'Reintentar',
      onAction: () =>
          PfToast.show(_ctx, 'Reintentando…', kind: PfToastKind.loading),
    );
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Reintentar'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Reintentando…'), findsOneWidget);
    expect(find.text('Primero'), findsNothing);
  });

  testWidgets('un show nuevo reemplaza al actual (sin apilar)', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Uno');
    await t.pump(const Duration(milliseconds: 600));
    PfToast.show(_ctx, 'Dos');
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Uno'), findsNothing);
    expect(find.text('Dos'), findsOneWidget);
  });

  testWidgets('loading no se cierra solo', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Cargando…', kind: PfToastKind.loading);
    await t.pump(const Duration(seconds: 30));
    expect(find.text('Cargando…'), findsOneWidget);
  });

  testWidgets('deslizar hacia abajo lo descarta', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Deslizame', actionLabel: 'X', onAction: () {});
    await t.pump(const Duration(milliseconds: 600));
    await t.drag(find.text('Deslizame'), const Offset(0, 80));
    await _out(t);
    expect(find.text('Deslizame'), findsNothing);
  });

  testWidgets('sin animaciones: solo fundido (sin desplazamiento ni escala)', (
    t,
  ) async {
    await t.pumpWidget(_app(disableAnimations: true));
    PfToast.show(_ctx, 'Quieto', kind: PfToastKind.error);
    await t.pump();
    await t.pump(const Duration(milliseconds: 160));
    final rest = t.getTopLeft(find.text('Quieto'));
    final size = t.getSize(find.text('Quieto'));
    // Con animación completa habría rebote; aquí la posición es estable
    // desde el primer cuadro visible.
    await t.pump(const Duration(milliseconds: 16));
    expect(t.getTopLeft(find.text('Quieto')), rest);
    expect(t.getSize(find.text('Quieto')), size);
  });

  testWidgets('con movimiento entra desde abajo y sube', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Sube');
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    final early = t.getTopLeft(find.text('Sube')).dy;
    await t.pump(const Duration(milliseconds: 700));
    final settled = t.getTopLeft(find.text('Sube')).dy;
    expect(early, greaterThan(settled));
  });

  testWidgets('el scope fija la separación inferior', (t) async {
    await t.pumpWidget(_app(clearance: 100));
    PfToast.show(_ctx, 'Arriba', actionLabel: 'X', onAction: () {});
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    final capsule = find.byKey(const ValueKey('pf-toast-capsule'));
    expect(t.getBottomLeft(capsule).dy, closeTo(screen.height - 100, 1));
  });

  testWidgets('sin scope la separación es 16', (t) async {
    await t.pumpWidget(_app());
    PfToast.show(_ctx, 'Abajo', actionLabel: 'X', onAction: () {});
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    final capsule = find.byKey(const ValueKey('pf-toast-capsule'));
    expect(t.getBottomLeft(capsule).dy, closeTo(screen.height - 16, 1));
  });

  testWidgets('los toques fuera de la cápsula pasan al contenido', (t) async {
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              _ctx = c;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
    PfToast.show(_ctx, 'No bloquea', kind: PfToastKind.loading);
    await t.pump(const Duration(milliseconds: 700));
    await t.tapAt(const Offset(200, 100));
    expect(taps, 1);
  });

  testWidgets(
    'showOn con destino capturado funciona con el contexto desmontado',
    (t) async {
      var show = true;
      late StateSetter set;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (c, s) {
                set = s;
                return show
                    ? Builder(
                        builder: (c2) {
                          _ctx = c2;
                          return const SizedBox.expand();
                        },
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final target = PfToast.capture(_ctx, bottomClearance: 50)!;
      final orphan = _ctx;
      set(() => show = false);
      await t.pump();
      expect(orphan.mounted, isFalse);
      PfToast.showOn(target, 'Sigue vivo');
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Sigue vivo'), findsOneWidget);
    },
  );

  testWidgets('dismissIfCurrent solo cierra el aviso propio', (t) async {
    await t.pumpWidget(_app());
    final a = PfToast.show(_ctx, 'A', kind: PfToastKind.loading);
    final b = PfToast.show(_ctx, 'B', kind: PfToastKind.loading);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    PfToast.dismissIfCurrent(a);
    await _out(t);
    expect(find.text('B'), findsOneWidget);
    PfToast.dismissIfCurrent(b);
    await _out(t);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('bottomClearance explícito gana al scope', (t) async {
    await t.pumpWidget(_app(clearance: 100));
    PfToast.show(_ctx, 'X', kind: PfToastKind.loading, bottomClearance: 30);
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    final capsule = find.byKey(const ValueKey('pf-toast-capsule'));
    expect(t.getBottomLeft(capsule).dy, closeTo(screen.height - 30, 1));
  });
}
