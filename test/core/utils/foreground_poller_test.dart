import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/chat_poll_policy.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setInterval reprograma sin esperar al tick viejo', () {
    fakeAsync((fa) {
      var ticks = 0;
      final p = ForegroundPoller(
        interval: chatThreadPollEvery(healthy: true),
        onTick: () => ticks++,
      )..start();
      fa.elapse(const Duration(seconds: 50));
      expect(ticks, 0);
      p.setInterval(chatThreadPollEvery(healthy: false)); // cae el socket
      fa.elapse(const Duration(seconds: 10));
      expect(ticks, 1);
      fa.elapse(const Duration(seconds: 10));
      expect(ticks, 2);
      p.setInterval(chatThreadPollEvery(healthy: true));
      fa.elapse(const Duration(seconds: 59));
      expect(ticks, 2);
      fa.elapse(const Duration(seconds: 1));
      expect(ticks, 3);
      p.dispose();
    });
  });
}
