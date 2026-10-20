import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_locale_preferences.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_theme_preferences.dart';
import 'package:ostinato/app/app_translation_catalog.dart';

final class _ThemePreferences implements AppThemePreferences {
  AppThemePreference saved = AppThemePreference.system;
  @override
  Future<AppThemePreference> read() async => saved;
  @override
  Future<void> write(AppThemePreference value) async {
    saved = value;
  }
}

final class _LocalePreferences implements AppLocalePreferences {
  @override
  Future<String?> read() async => 'ar';
  @override
  Future<void> write(String? value) async {}
}

final class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final tag = key.split('/').last.replaceAll('.json', '');
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'locale': tag,
          'messages': <String, Object>{},
        }),
      ),
    );
    return ByteData.sublistView(bytes);
  }
}

class _LifetimeProbe extends StatefulWidget {
  const _LifetimeProbe({super.key, required this.child});
  final Widget child;
  static int initializations = 0;
  static int disposals = 0;
  @override
  State<_LifetimeProbe> createState() => _LifetimeProbeState();
}

class _LifetimeProbeState extends State<_LifetimeProbe> {
  @override
  void initState() {
    super.initState();
    ++_LifetimeProbe.initializations;
  }

  @override
  void dispose() {
    ++_LifetimeProbe.disposals;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DraftPage extends StatefulWidget {
  const _DraftPage({super.key});
  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final text = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      controller: scroll,
      children: [
        TextField(
          key: const Key('retained-draft'),
          controller: text,
          focusNode: focus,
        ),
        const SizedBox(height: 1200),
      ],
    ),
  );
}

void main() {
  testWidgets(
    'theme changes retain route, dialog, draft, focus, locale and child lifetime',
    (tester) async {
      _LifetimeProbe.initializations = 0;
      _LifetimeProbe.disposals = 0;
      final preference = _ThemePreferences();
      final controller = AppThemeController(preferences: preference);
      await controller.load();
      final bundle = _CatalogBundle();
      AppLocaleController? localeController;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AppThemeHost(
          controller: controller,
          child: AppLocaleHost(
            preferences: _LocalePreferences(),
            translationBundle: bundle,
            child: _LifetimeProbe(
              child: Builder(
                builder: (context) {
                  localeController = AppLocaleScope.maybeOf(context);
                  return MaterialApp(
                    navigatorKey: navigatorKey,
                    locale: Localizations.localeOf(context),
                    supportedLocales: appSupportedLocales,
                    localeListResolutionCallback: resolveAppLocales,
                    localizationsDelegates: [
                      AppTranslationsDelegate(bundle: bundle),
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    theme: OstinatoThemes.light,
                    darkTheme: OstinatoThemes.dark,
                    themeMode: AppThemeScope.modeOf(context),
                    themeAnimationDuration: Duration.zero,
                    home: const Scaffold(body: Text('root')),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = navigatorKey.currentState!;
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const _DraftPage()),
      );
      await tester.pumpAndSettle();
      final state = tester.state<_DraftPageState>(find.byType(_DraftPage));
      state.text.value = const TextEditingValue(
        text: 'Arabic العربية draft',
        selection: TextSelection(baseOffset: 3, extentOffset: 7),
      );
      state.focus.requestFocus();
      await tester.pump();
      state.scroll.jumpTo(100);
      await tester.pump();
      final originalOffset = state.scroll.offset;
      final originalValue = state.text.value;
      final originalLocale = localeController;
      expect(originalLocale!.languageTag, 'ar');
      expect(Directionality.of(state.context), TextDirection.rtl);
      await controller.select(AppThemePreference.dark);
      await tester.pumpAndSettle();
      expect(navigatorKey.currentState, same(navigator));
      expect(tester.state(find.byType(_DraftPage)), same(state));
      expect(state.text.value, originalValue);
      expect(state.scroll.offset, originalOffset);
      expect(state.focus.hasFocus, isTrue);
      expect(Theme.of(state.context).brightness, Brightness.dark);
      expect(Directionality.of(state.context), TextDirection.rtl);
      expect(localeController, same(originalLocale));
      expect(localeController!.languageTag, 'ar');
      expect(_LifetimeProbe.initializations, 1);
      expect(_LifetimeProbe.disposals, 0);

      showDialog<void>(
        context: state.context,
        builder: (_) => const AlertDialog(content: Text('retained dialog')),
      );
      await tester.pumpAndSettle();
      final dialogRoute = ModalRoute.of(
        tester.element(find.byType(AlertDialog)),
      );
      await controller.select(AppThemePreference.light);
      await tester.pumpAndSettle();
      expect(find.text('retained dialog'), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(AlertDialog))),
        same(dialogRoute),
      );
      expect(
        Theme.of(tester.element(find.byType(AlertDialog))).brightness,
        Brightness.light,
      );
      expect(_LifetimeProbe.initializations, 1);
      expect(_LifetimeProbe.disposals, 0);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(state.text.value, originalValue);
      expect(localeController!.languageTag, 'ar');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(_LifetimeProbe.disposals, 1);
    },
  );
}
