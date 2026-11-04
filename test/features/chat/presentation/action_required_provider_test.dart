import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/action_required_counts.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/action_required_provider.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/action_required_bar.dart';

class _Repo implements ChatRepository {
  int calls = 0;
  Result<ActionRequiredCounts> next = Result.ok(
    const ActionRequiredCounts(
      toQuoteOrders: [1, 2],
      importantClients: ['569'],
    ),
  );

  @override
  Future<Result<ActionRequiredCounts>> actionRequiredCounts() async {
    calls++;
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _SlowRepo implements ChatRepository {
  final pending = <Completer<Result<ActionRequiredCounts>>>[];

  @override
  Future<Result<ActionRequiredCounts>> actionRequiredCounts() {
    final c = Completer<Result<ActionRequiredCounts>>();
    pending.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Session extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final _sessionFlag = NotifierProvider<_Session, bool>(_Session.new);

void main() {
  late _Repo repo;
  late ProviderContainer c;

  setUp(() {
    repo = _Repo();
    c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(actionRequiredProvider, (_, _) {});
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('carga al montar; visibles = con elementos, en orden del BO', () async {
    await settle();
    expect(repo.calls, 1);
    final s = c.read(actionRequiredProvider);
    expect(s.visible, [ActionCard.importantClients, ActionCard.toQuote]);
    expect(s.countOf(ActionCard.optionsAccepted), 0);
  });

  test('descartar oculta la tarjeta y sobrevive a un refresh', () async {
    await settle();
    final n = c.read(actionRequiredProvider.notifier);
    n.dismiss(ActionCard.toQuote);
    expect(c.read(actionRequiredProvider).visible, [
      ActionCard.importantClients,
    ]);
    await n.refresh(force: true);
    expect(c.read(actionRequiredProvider).visible, [
      ActionCard.importantClients,
    ]);
  });

  test('refresh sin force respeta el tope de frecuencia', () async {
    await settle();
    final n = c.read(actionRequiredProvider.notifier);
    await n.refresh();
    expect(repo.calls, 1);
    await n.refresh(force: true);
    expect(repo.calls, 2);
  });

  test('error conserva los últimos valores', () async {
    await settle();
    repo.next = Result.err(Failure.network());
    await c.read(actionRequiredProvider.notifier).refresh(force: true);
    expect(c.read(actionRequiredProvider).counts.toQuoteOrders, [1, 2]);
  });

  test('todo en cero: sin tarjetas', () async {
    repo.next = Result.ok(ActionRequiredCounts.empty);
    final c2 = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c2.dispose);
    c2.listen(actionRequiredProvider, (_, _) {});
    await settle();
    expect(c2.read(actionRequiredProvider).visible, isEmpty);
  });

  test('etiqueta del contador: pedidos con tope +50, clientes exactos', () {
    expect(actionCardCountLabel(ActionCard.toQuote, 51), '+50');
    expect(actionCardCountLabel(ActionCard.optionsAccepted, 50), '50');
    expect(actionCardCountLabel(ActionCard.importantClients, 80), '80');
  });

  test('cambio de sesión con request lento en vuelo: la nueva carga y el viejo '
      'resultado se descarta', () async {
    final slow = _SlowRepo();
    final c3 = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(slow),
        sessionActiveProvider.overrideWith((ref) => ref.watch(_sessionFlag)),
      ],
    );
    addTearDown(c3.dispose);
    c3.listen(actionRequiredProvider, (_, _) {});
    await settle();
    expect(slow.pending, hasLength(1)); // sesión vieja, sin responder

    // Cambia la sesión: el notifier se reconstruye y pide de nuevo aunque
    // el request anterior siga en vuelo.
    c3.read(_sessionFlag.notifier).set(false);
    await settle();
    await settle();
    expect(slow.pending, hasLength(2));

    slow.pending[1].complete(
      Result.ok(const ActionRequiredCounts(toQuoteOrders: [9])),
    );
    await settle();
    expect(c3.read(actionRequiredProvider).counts.toQuoteOrders, [9]);

    // El resultado de la sesión vieja llega tarde: se descarta.
    slow.pending[0].complete(
      Result.ok(const ActionRequiredCounts(toQuoteOrders: [1, 2, 3])),
    );
    await settle();
    expect(c3.read(actionRequiredProvider).counts.toQuoteOrders, [9]);
  });
}
