import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/background_closer.dart';
import 'package:partsflow_mobile/core/realtime/chat_poll_policy.dart';

void main() {
  test('cierra tras 45 s en background', () {
    fakeAsync((fa) {
      var closed = 0;
      final c = BackgroundCloser(onClose: () => closed++);
      c.onBackground();
      fa.elapse(const Duration(seconds: 44));
      expect(closed, 0);
      fa.elapse(const Duration(seconds: 1));
      expect(closed, 1);
      expect(c.onForeground(), isTrue);
      expect(c.onForeground(), isFalse);
    });
  });

  test('cancela si vuelve antes', () {
    fakeAsync((fa) {
      var closed = 0;
      final c = BackgroundCloser(onClose: () => closed++);
      c.onBackground();
      fa.elapse(const Duration(seconds: 30));
      expect(c.onForeground(), isFalse);
      fa.elapse(const Duration(minutes: 5));
      expect(closed, 0);
    });
  });

  test('intervalos sano/caído', () {
    expect(chatListPollEvery(healthy: true), const Duration(seconds: 120));
    expect(chatListPollEvery(healthy: false), const Duration(seconds: 20));
    expect(chatThreadPollEvery(healthy: true), const Duration(seconds: 60));
    expect(chatThreadPollEvery(healthy: false), const Duration(seconds: 10));
  });
}
