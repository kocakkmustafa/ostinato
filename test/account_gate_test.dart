import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/lesson_scored_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/setup_check_screen.dart';
import 'package:ostinato/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  late ContentRepository repo;
  late CueTextResolver cueText;

  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  testWidgets('guest can browse; account switch resets the shell', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(null);
    addTearDown(userId.dispose);
    await tester.pumpWidget(
      OstinatoApp(
        store: InMemoryOnboardingStore(complete: true),
        accountConnection: AccountConnection(
          userId: userId,
          pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_PAGE_TEST')),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT_PAGE_TEST'), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);

    userId.value = first;
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
      const ValueKey<String>('ostinato-account-$first'),
    );
    await tester.tap(find.text('⚙'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT_PAGE_TEST'), findsOneWidget);

    userId.value = second;
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).key,
      const ValueKey<String>('ostinato-account-$second'),
    );

    userId.value = null;
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT_PAGE_TEST'), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  });

  testWidgets('paid access denied keeps setup check closed', (tester) async {
    final guitar = repo.disciplines.firstWhere((d) => d.id == 'guitar');
    final lesson = guitar.courses.first.lessons.firstWhere(
      (l) => l.kind == LessonKind.scored,
    );
    final userId = ValueNotifier<String?>(null);
    addTearDown(userId.dispose);
    int guardCalls = 0;
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: AccountScope(
          connection: AccountConnection(
            userId: userId,
            pageBuilder: (_) => const SizedBox.shrink(),
            requirePaidAccess: (_) async {
              guardCalls++;
              return false;
            },
          ),
          currentUserId: null,
          child: MaterialApp(
            home: LessonScoredScreenRoute(
              discipline: guitar,
              lesson: lesson,
              hue: InstrumentHues.guitar,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = find.text('Begin the setup check');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(guardCalls, 1);
    expect(find.byType(SetupCheckScreenRoute), findsNothing);
    expect(find.byType(LessonScoredScreenRoute), findsOneWidget);
  });
}
