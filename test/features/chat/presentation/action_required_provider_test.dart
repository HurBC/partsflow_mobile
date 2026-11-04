import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
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
}
