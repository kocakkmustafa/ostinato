import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_theme_preferences.dart';

final class _MemoryPreferences implements AppThemePreferences {
  AppThemePreference saved = AppThemePreference.system;
  Object? readError;
  Completer<AppThemePreference>? delayedRead;
  final List<Completer<void>> delayedWrites = [];
  final List<AppThemePreference> dispatched = [];
  int readCount = 0;

  @override
  Future<AppThemePreference> read() async {
    ++readCount;
    if (readError != null) throw readError!;
    if (delayedRead != null) return delayedRead!.future;
    return saved;
  }

  @override
  Future<void> write(AppThemePreference value) async {
    final index = dispatched.length;
    dispatched.add(value);
    if (index < delayedWrites.length) await delayedWrites[index].future;
    saved = value;
  }
}

void main() {
  test(
    'separate file round trips system, light and dark without touching other preferences',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ostinato-theme-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final locale = File('${directory.path}/ostinato.locale.v1.json');
      final progress = File('${directory.path}/guitar-progress.v1.json');
      await locale.writeAsString('locale sentinel');
      await progress.writeAsString('progress sentinel');
      final preferences = FileAppThemePreferences(directory: directory);
      expect(await preferences.read(), AppThemePreference.system);
      for (final mode in AppThemePreference.values) {
        await preferences.write(mode);
        expect(await preferences.read(), mode);
      }
      expect(await locale.readAsString(), 'locale sentinel');
      expect(await progress.readAsString(), 'progress sentinel');
    },
  );

  for (final raw in [
    'broken {',
    '{"schemaVersion":2,"mode":"light"}',
    '{"schemaVersion":1,"mode":"night"}',
  ]) {
    test('invalid saved preference preserves raw bytes: $raw', () async {
      final directory = await Directory.systemTemp.createTemp(
        'ostinato-theme-bad-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ostinato.theme.v1.json');
      await file.writeAsString(raw);
      final controller = AppThemeController(
        preferences: FileAppThemePreferences(directory: directory),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.readFailed, isTrue);
      expect(controller.loading, isFalse);
      expect(controller.preference, AppThemePreference.system);
      expect(await file.readAsString(), raw);
    });
  }

  test(
    'slow read times out to system without accepting a late value',
    () async {
      final preferences = _MemoryPreferences()
        ..delayedRead = Completer<AppThemePreference>();
      final controller = AppThemeController(
        preferences: preferences,
        readDeadline: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.loading, isFalse);
      expect(controller.readFailed, isTrue);
      preferences.delayedRead!.complete(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);
      expect(controller.preference, AppThemePreference.system);
      expect(preferences.dispatched, isEmpty);
    },
  );

  test(
    'selection made before load is not overwritten and dispatches only its own write',
    () async {
      final preferences = _MemoryPreferences()
        ..saved = AppThemePreference.light;
      final controller = AppThemeController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.select(AppThemePreference.dark);
      await controller.load();
      expect(preferences.readCount, 0);
      expect(controller.preference, AppThemePreference.dark);
      expect(preferences.saved, AppThemePreference.dark);
    },
  );

  test('late initial read cannot replace an explicit selection', () async {
    final preferences = _MemoryPreferences()
      ..delayedRead = Completer<AppThemePreference>();
    final controller = AppThemeController(preferences: preferences);
    addTearDown(controller.dispose);
    final loading = controller.load();
    await controller.select(AppThemePreference.dark);
    preferences.delayedRead!.complete(AppThemePreference.light);
    await loading;
    expect(controller.preference, AppThemePreference.dark);
  });

  test(
    'reentrant listener preserves disk order and each caller completion',
    () async {
      final preferences = _MemoryPreferences();
      final firstWrite = Completer<void>();
      final secondWrite = Completer<void>();
      preferences.delayedWrites.addAll([firstWrite, secondWrite]);
      final controller = AppThemeController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      Future<void>? second;
      controller.addListener(() {
        if (controller.preference == AppThemePreference.light) {
          second = controller.select(AppThemePreference.dark);
        }
      });
      var firstComplete = false;
      var secondComplete = false;
      final first = controller.select(AppThemePreference.light)
        ..then((_) => firstComplete = true);
      await Future<void>.delayed(Duration.zero);
      second!.then((_) => secondComplete = true);
      expect(preferences.dispatched, [AppThemePreference.light]);
      firstWrite.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(firstComplete, isTrue);
      expect(secondComplete, isFalse);
      expect(preferences.dispatched, [
        AppThemePreference.light,
        AppThemePreference.dark,
      ]);
      secondWrite.complete();
      await second;
      expect(preferences.saved, AppThemePreference.dark);
      expect(controller.preference, AppThemePreference.dark);
    },
  );

  test(
    'failed old write cannot publish failure over newer selection and queue recovers',
    () async {
      final preferences = _MemoryPreferences();
      final firstWrite = Completer<void>();
      final secondWrite = Completer<void>();
      preferences.delayedWrites.addAll([firstWrite, secondWrite]);
      final controller = AppThemeController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.select(AppThemePreference.light);
      final second = controller.select(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);
      firstWrite.completeError(StateError('synthetic disk failure'));
      await first;
      expect(controller.writeFailed, isFalse);
      expect(controller.saving, isTrue);
      secondWrite.complete();
      await second;
      expect(controller.writeFailed, isFalse);
      expect(controller.saving, isFalse);
      expect(preferences.saved, AppThemePreference.dark);
    },
  );

  test(
    'current write failure is visible and explicit retry may persist',
    () async {
      final preferences = _MemoryPreferences();
      final write = Completer<void>();
      preferences.delayedWrites.add(write);
      final controller = AppThemeController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.hasSavedSelection, isFalse);
      final selecting = controller.select(AppThemePreference.dark);
      await Future<void>.delayed(Duration.zero);
      write.completeError(StateError('synthetic disk failure'));
      await selecting;
      expect(controller.writeFailed, isTrue);
      expect(controller.hasSavedSelection, isFalse);
      expect(controller.preference, AppThemePreference.dark);
      await controller.select(AppThemePreference.dark);
      expect(controller.writeFailed, isFalse);
      expect(controller.hasSavedSelection, isTrue);
      expect(preferences.saved, AppThemePreference.dark);
    },
  );

  testWidgets('preloaded dark preference is used on the first app frame', (
    tester,
  ) async {
    final preferences = _MemoryPreferences()..saved = AppThemePreference.dark;
    final controller = AppThemeController(preferences: preferences);
    await controller.load();
    await tester.pumpWidget(
      AppThemeHost(
        controller: controller,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: OstinatoThemes.light,
            darkTheme: OstinatoThemes.dark,
            themeMode: AppThemeScope.modeOf(context),
            themeAnimationDuration: Duration.zero,
            home: Builder(
              builder: (context) => Text(Theme.of(context).brightness.name),
            ),
          ),
        ),
      ),
    );
    expect(find.text('dark'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'system reacts to OS brightness while explicit override stays stable',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      dispatcher.platformBrightnessTestValue = Brightness.light;
      final controller = AppThemeController(preferences: _MemoryPreferences());
      await controller.load();
      await tester.pumpWidget(
        AppThemeHost(
          controller: controller,
          child: Builder(
            builder: (context) => MaterialApp(
              theme: OstinatoThemes.light,
              darkTheme: OstinatoThemes.dark,
              themeMode: AppThemeScope.modeOf(context),
              themeAnimationDuration: Duration.zero,
              home: Builder(
                builder: (context) => Text(Theme.of(context).brightness.name),
              ),
            ),
          ),
        ),
      );
      expect(find.text('light'), findsOneWidget);
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      expect(find.text('dark'), findsOneWidget);
      await controller.select(AppThemePreference.light);
      await tester.pump();
      expect(find.text('light'), findsOneWidget);
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      expect(find.text('light'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
