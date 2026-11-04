import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/orders/data/mappers/order_mapper.dart';

void main() {
  group('orderFromKanban', () {
    test('combina el pedido con los datos del cliente padre', () {
      final o = orderFromKanban(
        {
          'id': '12',
          'status': 'quoting',
          'source': 'ai_order_taker',
          'ticket': 5,
          'responsible': {'first_name': 'Ana', 'last_name': 'Paz'},
          'client_car': {'name': 'Mazda 3', 'plate': 'AB1234'},
          'opqs': [
            {
              'product': {'name': 'Filtro'},
              'quantity': 2,
            },
            {'product': {}},
          ],
        },
        {'id': 4, 'full_name': 'Juan', 'phone': '569'},
      )!;
      expect(o.id, 12);
      expect(o.isJulia, isTrue);
      expect(o.responsibleName, 'Ana Paz');
      expect(o.clientId, '4');
      expect(o.clientName, 'Juan');
      expect(o.plate, 'AB1234');
      expect(o.products.single.quantity, 2);
    });

    test('devuelve null sin id o con entrada no mapa', () {
      expect(orderFromKanban({'status': 'x'}, {}), isNull);
      expect(orderFromKanban('x', {}), isNull);
    });

    test('campos faltantes quedan null y products vacío', () {
      final o = orderFromKanban({'id': 1}, {})!;
      expect(o.status, isNull);
      expect(o.clientName, isNull);
      expect(o.responsibleName, isNull);
      expect(o.products, isEmpty);
    });
  });

  group('ordersPageFromJson', () {
    test('aplana los pedidos de cada cliente', () {
      final (items, count, more) = ordersPageFromJson({
        'count': 10,
        'next': 'url',
        'results': [
          {
            'id': 1,
            'full_name': 'A',
            'order_list': [
              {'id': 10},
              {'id': 11},
            ],
          },
          {
            'id': 2,
            'order_list': [
              {'id': 20},
              {'sin_id': true},
            ],
          },
        ],
      });
      expect(items.map((e) => e.id), [10, 11, 20]);
      expect(items.last.clientId, '2');
      expect(count, 10);
      expect(more, isTrue);
    });

    test('JSON vacío o inválido da lista vacía, count 0 y sin más', () {
      final (items, count, more) = ordersPageFromJson(null);
      expect(items, isEmpty);
      expect(count, 0);
      expect(more, isFalse);
    });

    test('sin count usa la cantidad de pedidos aplanados', () {
      final (_, count, _) = ordersPageFromJson({
        'results': [
          {
            'order_list': [
              {'id': 1},
            ],
          },
        ],
      });
      expect(count, 1);
    });
  });

  group('orderFromDetail', () {
    test('mapea cliente, email y auto', () {
      final o = orderFromDetail({
        'id': 3,
        'status': 'quoted',
        'client': {'id': 8, 'name': 'Luis', 'email': 'l@x.cl'},
        'client_car': {'name': 'Kia', 'plate': 'ZZ'},
      })!;
      expect(o.clientName, 'Luis');
      expect(o.clientEmail, 'l@x.cl');
      expect(o.carName, 'Kia');
    });

    test('client_car numérico no rompe', () {
      final o = orderFromDetail({'id': 3, 'client_car': 55})!;
      expect(o.carName, isNull);
    });

    test('devuelve null sin id', () {
      expect(orderFromDetail({'status': 'x'}), isNull);
      expect(orderFromDetail(null), isNull);
    });
  });

  group('productsFromJson / quoteFromJson / notesFromJson', () {
    test('productsFromJson acepta lista o {results}', () {
      final raw = [
        {
          'product': {'name': 'A'},
        },
      ];
      expect(productsFromJson(raw), hasLength(1));
      expect(productsFromJson({'results': raw}), hasLength(1));
      expect(productsFromJson(null), isEmpty);
    });

    test('quoteFromJson prioriza unit_cost y trata montos <= 0 como null', () {
      final q = quoteFromJson([
        {
          'product': {'name': 'P'},
          'brand': {'name': 'Bosch'},
          'unit_cost': 100,
          'cost': 999,
          'vat_cost': 0,
          'discount': '10.5',
          'is_accepted': true,
        },
        {
          'product': {'name': 'Q'},
          'brand': 'NGK',
          'unit_cost': 0,
          'cost': 50,
        },
        {'product': {}},
      ]);
      expect(q, hasLength(2));
      expect(q[0].brand, 'Bosch');
      expect(q[0].unitPrice, 100);
      expect(q[0].lineTotal, isNull);
      expect(q[0].discount, 10.5);
      expect(q[0].isAccepted, isTrue);
      expect(q[1].brand, 'NGK');
      expect(q[1].unitPrice, 50);
      expect(q[1].quantity, 1);
    });

    test('notesFromJson lee autor de user, descarta notas sin comment', () {
      final n = notesFromJson({
        'results': [
          {
            'comment': 'hola',
            'user': {'first_name': 'Ana', 'last_name': 'P'},
          },
          {'comment': 'x', 'author': 'Bob'},
          {'comment': ''},
        ],
      });
      expect(n, hasLength(2));
      expect(n[0].author, 'Ana P');
      expect(n[1].author, 'Bob');
    });
  });
}
