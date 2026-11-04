import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/router/app_router.dart';

void main() {
  const loading = AsyncLoading<bool>();
  const yes = AsyncData(true);
  const no = AsyncData(false);

  test('loading manda a /splash guardando el destino', () {
    expect(
      resolveAuthRedirect(loading, Uri.parse('/orders')),
      '/splash?from=%2Forders',
    );
    expect(
      resolveAuthRedirect(loading, Uri.parse('/splash?from=%2Fchat')),
      isNull,
    );
  });

  test('resuelto autenticado vuelve al destino o a chat', () {
    expect(
      resolveAuthRedirect(yes, Uri.parse('/splash?from=%2Forders%2F5')),
      '/orders/5',
    );
    expect(resolveAuthRedirect(yes, Uri.parse('/splash')), '/chat');
    for (final bad in ['//evil.com', 'https://evil.com', '/x:y', 'orders']) {
      expect(
        resolveAuthRedirect(
          yes,
          Uri(path: '/splash', queryParameters: {'from': bad}),
        ),
        '/chat',
        reason: bad,
      );
    }
    expect(
      resolveAuthRedirect(yes, Uri.parse('/splash?from=%2Flogin')),
      '/chat',
    );
    expect(resolveAuthRedirect(yes, Uri.parse('/login')), '/chat');
    expect(resolveAuthRedirect(yes, Uri.parse('/profile')), isNull);
  });

  test('resuelto sin sesion o con error va a login', () {
    expect(
      resolveAuthRedirect(no, Uri.parse('/splash?from=%2Fchat')),
      '/login',
    );
    expect(resolveAuthRedirect(no, Uri.parse('/login')), isNull);
    expect(
      resolveAuthRedirect(
        AsyncError<bool>('x', StackTrace.empty),
        Uri.parse('/chat'),
      ),
      '/login',
    );
  });
}
