import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/utils/jwt_decoder.dart';

String _jwt(Map<String, dynamic> claims) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.${enc(claims)}.firma';
}

void main() {
  group('decodeJwtPayload', () {
    test('lee los claims del payload (incluye tildes y claves con ":")', () {
      final claims = decodeJwtPayload(
        _jwt({
          'name': 'Camila',
          'family_name': 'Rojas',
          'custom:subsidiary_name': 'Ñuñoa',
        }),
      );

      expect(claims['name'], 'Camila');
      expect(claims['family_name'], 'Rojas');
      expect(claims['custom:subsidiary_name'], 'Ñuñoa');
    });

    test('devuelve un mapa vacío con tokens inválidos', () {
      expect(decodeJwtPayload('no-es-un-jwt'), isEmpty);
      expect(decodeJwtPayload('a.%%%.c'), isEmpty);
    });
  });
}
