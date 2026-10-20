import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = '11111111-1111-4111-8111-111111111111';

  setUpAll(() async {
    // Keep cached asset futures outside each widget test's fake-async zone.
    await GuitarJourneyCourse.load();
    await ContentRepository.load();
    await CueTextResolver.load();
  });

  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<String?> userId,
    ValueNotifier<bool> recovery, {
    Listenable? identityBoundary,
  }) async {
    await tester.pumpWidget(
      OstinatoApp(
        store: InMemoryOnboardingStore(complete: true),
        accountConnection: AccountConnection(
          userId: userId,
          passwordRecovery: recovery,
          identityBoundary: identityBoundary,
          pageBuilder: (_) => const Scaffold(body: Text('PASSWORD_RECOVERY')),
        ),
      ),
    );
    // Async MaterialApp localizations may hide both its spinner and Navigator.
    // Wait for the actual root, retaining the same real-IO turn budget.
    final navigator = find.byType(Navigator);
    final expectedRoot = recovery.value
        ? find.text('PASSWORD_RECOVERY', skipOffstage: false)
        : find.byType(LibraryScreen, skipOffstage: false);
    bool ready() =>
        navigator.evaluate().length == 1 &&
        expectedRoot.evaluate().length == 1;
    for (var attempt = 0; attempt < 60 && !ready(); attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump();
    }
    expect(
      ready(),
      isTrue,
      reason: 'Actual recovery root and Navigator must finish boot: '
          'navigator=${navigator.evaluate().length}, '
          'expectedRoot=${expectedRoot.evaluate().length}, '
          'spinner=${find.byType(CircularProgressIndicator).evaluate().length}, '
          'contentError=${find.byKey(const Key('ostinato-content-load-failure')).evaluate().length}',
    );
    await tester.pumpAndSettle();
  }

  Future<NavigatorState> pushOldLesson(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('OLD_LESSON')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OLD_LESSON'), findsOneWidget);
    return navigator;
  }

  testWidgets(
    'same-user recovery replaces the active lesson with a root form',
    (tester) async {
      final userId = ValueNotifier<String?>(user);
      final recovery = ValueNotifier(false);
      await mount(tester, userId, recovery);
      final oldNavigator = await pushOldLesson(tester);

      recovery.value = true;
      await tester.pumpAndSettle();
      expect(userId.value, user);
      expect(find.text('PASSWORD_RECOVERY'), findsOneWidget);
      expect(find.text('OLD_LESSON'), findsNothing);
      expect(oldNavigator.mounted, isFalse);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );

      recovery.value = false;
      await tester.pumpAndSettle();
      expect(find.text('PASSWORD_RECOVERY'), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      userId.dispose();
      recovery.dispose();
    },
  );

  testWidgets('cold-start recovery opens the form before the library', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(user);
    final recovery = ValueNotifier(true);
    await mount(tester, userId, recovery);
    expect(find.text('PASSWORD_RECOVERY'), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    userId.dispose();
    recovery.dispose();
  });

  testWidgets(
    'recovery enter and exit before a frame still removes old routes',
    (tester) async {
      final userId = ValueNotifier<String?>(user);
      final recovery = ValueNotifier(false);
      await mount(tester, userId, recovery);
      final oldNavigator = await pushOldLesson(tester);
      recovery.value = true;
      recovery.value = false;
      await tester.pumpAndSettle();
      expect(find.text('OLD_LESSON'), findsNothing);
      expect(oldNavigator.mounted, isFalse);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      userId.dispose();
      recovery.dispose();
    },
  );

  testWidgets('same user returning before a frame receives a fresh Navigator', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(user);
    final recovery = ValueNotifier(false);
    await mount(tester, userId, recovery);
    final oldNavigator = await pushOldLesson(tester);
    userId.value = null;
    userId.value = user;
    await tester.pumpAndSettle();
    expect(find.text('OLD_LESSON'), findsNothing);
    expect(oldNavigator.mounted, isFalse);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    userId.dispose();
    recovery.dispose();
  });

  testWidgets(
    'verification returning before a frame still removes old routes',
    (tester) async {
      final userId = ValueNotifier<String?>(user);
      final recovery = ValueNotifier(false);
      final phase = ValueNotifier('verified');
      await mount(tester, userId, recovery, identityBoundary: phase);
      final oldNavigator = await pushOldLesson(tester);
      phase.value = 'verifying';
      phase.value = 'verified';
      await tester.pumpAndSettle();
      expect(find.text('OLD_LESSON'), findsNothing);
      expect(oldNavigator.mounted, isFalse);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      userId.dispose();
      recovery.dispose();
      phase.dispose();
    },
  );

  testWidgets('an equivalent connection rebuild preserves the active route', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(user);
    final recovery = ValueNotifier(false);
    await mount(tester, userId, recovery);
    final oldNavigator = await pushOldLesson(tester);
    await mount(tester, userId, recovery);
    expect(find.text('OLD_LESSON'), findsOneWidget);
    expect(oldNavigator.mounted, isTrue);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)),
      same(oldNavigator),
    );
    await tester.pumpWidget(const SizedBox());
    userId.dispose();
    recovery.dispose();
  });
}
