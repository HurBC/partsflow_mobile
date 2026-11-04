import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/search_text.dart';

void main() {
  group('hasLetters', () {
    test('true con letras', () => expect(hasLetters('abc1'), isTrue));
    test('true con acentos y ñ', () => expect(hasLetters('123ñ'), isTrue));
    test(
      'false con solo dígitos y símbolos',
      () => expect(hasLetters('+56 9 123-4'), isFalse),
    );
    test('false con vacío', () => expect(hasLetters(''), isFalse));
  });
  group('onlyDigits', () {
    test(
      'quita todo lo no numérico',
      () => expect(onlyDigits('+56 9 (1234)-5678'), '56912345678'),
    );
    test('sin dígitos queda vacío', () => expect(onlyDigits('abc'), ''));
  });
  group('plateFrom', () {
    test('4 letras + 2 dígitos', () => expect(plateFrom('BCDF12'), 'BCDF12'));
    test('2 letras + 4 dígitos', () => expect(plateFrom('AB1234'), 'AB1234'));
    test(
      'minúsculas se normalizan',
      () => expect(plateFrom('bcdf12'), 'BCDF12'),
    );
    test('con guion', () => expect(plateFrom('bc-df-12'), 'BCDF12'));
    test('con espacios', () => expect(plateFrom(' AB 12 34 '), 'AB1234'));
    test('con punto y punto medio', () {
      expect(plateFrom('AB.12·34'), 'AB1234');
    });
    test(
      'teléfono no es patente',
      () => expect(plateFrom('56912345678'), isNull),
    );
    test('palabra no es patente', () => expect(plateFrom('frenos'), isNull));
    test(
      '3 letras + 3 dígitos no es patente',
      () => expect(plateFrom('ABC123'), isNull),
    );
    test('vacío no es patente', () => expect(plateFrom(''), isNull));
    test(
      'largo extra no es patente',
      () => expect(plateFrom('BCDF123'), isNull),
    );
  });
}
