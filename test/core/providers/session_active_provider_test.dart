import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';

void main() {
  test(
    'invalidate con la misma sesión no reconstruye; cambiar sesión sí',
    () async {
      var session = true;
      final c = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return session;
          }),
        ],
      );
      addTearDown(c.dispose);
      var builds = 0;
      final probe = Provider<bool>((ref) {
        builds++;
        return ref.watch(sessionActiveProvider);
      });
      c.listen(probe, (_, _) {});
      await c.read(authStateProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(probe), isTrue);
      final base = builds;

      c.invalidate(authStateProvider);
      await c.read(authStateProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(builds, base, reason: 'misma sesión: sin rebuild');

      session = false;
      c.invalidate(authStateProvider);
      await c.read(authStateProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(probe), isFalse);
      expect(builds, base + 1);
    },
  );
}
