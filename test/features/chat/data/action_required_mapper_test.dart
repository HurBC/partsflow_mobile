import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/action_required_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/action_required_counts.dart';

void main() {
  test('parsea la respuesta real de SAPI', () {
    final c = actionRequiredFromJson({
      'to_quote_orders': [101, 102, 103],
      'options_accepted_orders': [7],
      'important_clients': ['56911112222', '56933334444'],
    });
    expect(c.toQuoteOrders, [101, 102, 103]);
    expect(c.optionsAcceptedOrders, [7]);
    expect(c.importantClients, ['56911112222', '56933334444']);
    expect(c.isEmpty, isFalse);
  });

  test('tolera claves ausentes, nulls e ids como string', () {
    final c = actionRequiredFromJson({
      'to_quote_orders': ['5', null, 'x', 6],
      'important_clients': ['', null, 'cc'],
    });
    expect(c.toQuoteOrders, [5, 6]);
    expect(c.optionsAcceptedOrders, isEmpty);
    expect(c.importantClients, ['cc']);
  });

  test('cuerpo inválido o vacío -> empty', () {
    expect(actionRequiredFromJson(null).isEmpty, isTrue);
    expect(actionRequiredFromJson([1]).isEmpty, isTrue);
    expect(actionRequiredFromJson(<String, Object?>{}).isEmpty, isTrue);
  });

  test('igualdad por valor', () {
    const a = ActionRequiredCounts(toQuoteOrders: [1, 2]);
    expect(a, const ActionRequiredCounts(toQuoteOrders: [1, 2]));
    expect(a == const ActionRequiredCounts(toQuoteOrders: [1]), isFalse);
  });
}
