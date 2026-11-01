import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';

/// Practice-loop widget host. Source EN/TR copy only (no catalog asset IO):
/// the practice strings are not in the 14-locale table yet, so the source
/// pair is exactly what every locale shows today.
Widget practiceHost(Widget home, {String locale = 'en'}) => MaterialApp(
  theme: ostinatoTheme(),
  locale: Locale(locale),
  supportedLocales: const [Locale('en'), Locale('tr')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);
