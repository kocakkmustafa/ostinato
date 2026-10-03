import 'package:flutter_test/flutter_test.dart';

import 'support/account_blocked_close_fixture.dart';
import 'support/account_drain_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('thrown typed A close preserves files and propagates cleanupPending after admitted IO',
    () => requireBlockedAccountClose(throwStop: true),
    timeout: drainTestBound,
  );
}
