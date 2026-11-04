import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/utils/base64_codec.dart';

void main() {
  final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
  final b64 = base64.encode(bytes);

  final variants = <String, String>{
    'plano': b64,
    'comillas': '"$b64"',
    'data uri': 'data:image/png;base64,$b64',
    'saltos': '${b64.substring(0, 100)}\r\n${b64.substring(100)}\n',
    'espacios': ' ${b64.substring(0, 50)} ${b64.substring(50)} ',
    'JSON con \\n escapado': jsonEncode(
      '${b64.substring(0, 100)}\n${b64.substring(100)}',
    ),
    'JSON con \\r\\n': jsonEncode(
      '${b64.substring(0, 60)}\r\n${b64.substring(60, 200)}\r\n${b64.substring(200)}',
    ),
    'JSON con \\/': '"${b64.replaceAll('/', r'\/')}"',
  };

  group('decodeBase64Async', () {
    for (final e in variants.entries) {
      test('${e.key}: inline == isolate == bytes', () async {
        final inline = await decodeBase64Async(e.value, threshold: 1 << 30);
        final iso = await decodeBase64Async(e.value, threshold: 0);
        expect(inline, bytes);
        expect(iso, bytes);
      });
    }

    test('body objeto/array JSON -> null por ambas vías', () async {
      for (final body in ['{"a":1}', '  [1,2]', '\n{"detail":"x"}']) {
        expect(await decodeBase64Async(body, threshold: 1 << 30), isNull);
        expect(await decodeBase64Async(body, threshold: 0), isNull);
      }
    });

    test('literal JSON que no es string lanza', () {
      expect(() => decodeBase64Clean('"abc'), throwsFormatException);
    });

    test('no String -> null', () async {
      expect(await decodeBase64Async(null), isNull);
      expect(await decodeBase64Async(<String, Object?>{}), isNull);
    });

    test('inválido lanza FormatException por ambas vías', () async {
      await expectLater(
        decodeBase64Async('@@@@!', threshold: 1 << 30),
        throwsFormatException,
      );
      await expectLater(
        decodeBase64Async('@@@@!', threshold: 0),
        throwsFormatException,
      );
    });
  });
}
