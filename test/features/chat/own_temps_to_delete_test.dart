import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  test('borra solo los confirmados como enviados', () {
    expect(ownTempsToDelete(['a', 'b', 'c'], {'a', 'c'}), ['a', 'c']);
  });
  test('nada confirmado (salió del chat / falló) no borra nada', () {
    expect(ownTempsToDelete(['a', 'b'], <String>{}), isEmpty);
  });
  test('ignora confirmados que no se pidieron y duplicados', () {
    expect(ownTempsToDelete(['a', 'a'], {'a', 'z'}), ['a']);
  });
}
