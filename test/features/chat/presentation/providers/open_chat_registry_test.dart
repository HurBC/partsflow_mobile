import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/open_chat_provider.dart';

void main() {
  test('A y B abiertos: cerrar B deja A abierto', () {
    final r = OpenChatRegistry()
      ..open('A')
      ..open('B')
      ..close('B');
    expect(r.isOpen('A'), isTrue);
    expect(r.isOpen('B'), isFalse);
  });
  test('open A dos veces y close una: sigue abierto', () {
    final r = OpenChatRegistry()
      ..open('A')
      ..open('A')
      ..close('A');
    expect(r.isOpen('A'), isTrue);
    r.close('A');
    expect(r.isOpen('A'), isFalse);
    r.close('A'); // sin efecto
    expect(r.isOpen('A'), isFalse);
  });
}
