import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

void main() {
  group('searchParamFor', () {
    test('texto vacío o solo espacios devuelve null', () {
      expect(searchParamFor(''), isNull);
      expect(searchParamFor('   '), isNull);
    });

    test('dígitos de hasta 7 son un id', () {
      expect(searchParamFor('1234'), 'id:,1234');
      expect(searchParamFor(' 1234567 '), 'id:,1234567');
    });

    test('8 o más dígitos son teléfono, ignorando formato', () {
      expect(searchParamFor('56912345678'), 'client_phone:,56912345678');
      expect(searchParamFor('+56 9 1234-5678'), 'client_phone:,56912345678');
    });

    test('texto con letras devuelve null', () {
      expect(searchParamFor('juan'), isNull);
      expect(searchParamFor('AB1234'), isNull);
    });

    test('pocos dígitos con formato de teléfono devuelve null', () {
      // comportamiento actual: "12-34" no es solo dígitos ni tiene >= 8.
      expect(searchParamFor('12-34'), isNull);
    });

    test('solo símbolos devuelve null', () {
      expect(searchParamFor('+-()'), isNull);
    });
  });
}
