import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ostinato/main.dart' as production;
import 'package:ostinato/app/screens/onboarding_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('production main guest boot reaches usable ostinato screen', (tester) async {
    await production.main();
    bool ready() => find.byType(OnboardingScreen).evaluate().isNotEmpty ||
        find.byType(LibraryScreen).evaluate().isNotEmpty;
    for (var i = 0; i < 600 && !ready(); i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(production.OstinatoApp), findsOneWidget);
    expect(ready(), isTrue,
        reason: 'Production main must reach interactive onboarding or content');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    debugPrint('MOTION_MAIN_BOOT_READY_ostinato');
    await Future<void>.delayed(const Duration(seconds: 3));
  });
}
