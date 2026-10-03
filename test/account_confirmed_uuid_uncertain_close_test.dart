import 'package:flutter_test/flutter_test.dart';

import 'support/account_blocked_close_fixture.dart';
import 'support/account_drain_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('settled uncertain A close retains failed proof without automatic native retry',
    () => requireBlockedAccountClose(throwStop: false),
    timeout: drainTestBound,
  );
}
