import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app_message_ids.dart';

const supportedLanguageTags = <String>[
  'tr', 'en', 'es-419', 'pt-BR', 'de', 'fr', 'ja', 'ar',
  'it', 'ko', 'id', 'pl', 'hi', 'zh-Hans',
];

const ostinatoSupportedLocales = <Locale>[
  Locale('tr'),
  Locale('en'),
  Locale('es', '419'),
  Locale('pt', 'BR'),
  Locale('de'),
  Locale('fr'),
  Locale('ja'),
  Locale('ar'),
  Locale('it'),
  Locale('ko'),
  Locale('id'),
  Locale('pl'),
  Locale('hi'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
];

Locale localeForLanguageTag(String tag) {
  if (!supportedLanguageTags.contains(tag)) {
    throw ArgumentError.value(tag, 'tag', 'Unsupported app language');
  }
  if (tag == 'zh-Hans') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
  final parts = tag.split('-');
  return Locale(parts.first, parts.length == 2 ? parts.last : null);
}

String canonicalLanguageTag(Locale? locale) {
  final language = locale?.languageCode;
  if (language == 'es') return 'es-419';
  if (language == 'pt') return 'pt-BR';
  if (language == 'zh') return _supportsChinese(locale!) ? 'zh-Hans' : 'en';
  return supportedLanguageTags.contains(language) ? language! : 'en';
}

bool _supportsChinese(Locale locale) =>
    locale.scriptCode == 'Hans' ||
    (locale.scriptCode != 'Hant' &&
      !const {'TW', 'HK', 'MO'}.contains(locale.countryCode));

bool _supportsAppLocale(Locale locale) =>
    (locale.languageCode != 'zh' || _supportsChinese(locale)) &&
    ostinatoSupportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );

/// Intl 0.20.3 has Chinese number/plural data under zh, not zh_Hans.
String intlLocaleName(Locale locale) {
  final tag = canonicalLanguageTag(locale);
  return tag == 'zh-Hans' ? 'zh' : tag.replaceAll('-', '_');
}

Locale resolveAppLocales(List<Locale>? preferred, Iterable<Locale> _) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (_supportsAppLocale(locale)) {
      return localeForLanguageTag(canonicalLanguageTag(locale));
    }
  }
  return const Locale('en');
}

/// A measurement with explicit display precision. Store-provided prices are
/// already localized and must never pass through this formatter.
final class AppDecimal {
  const AppDecimal(this.value, this.fractionDigits)
    : assert(fractionDigits >= 0 && fractionDigits <= 20);
  final num value;
  final int fractionDigits;
}

final _messagePlaceholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

Map<String, int> _placeholderCounts(String source) {
  final counts = <String, int>{};
  for (final match in _messagePlaceholder.allMatches(source)) {
    counts.update(match.group(1)!, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// Presentation-only translations. Canonical course bytes, content revisions
/// and learner-progress keys are independent of the chosen language.
final class AppTranslations {
  const AppTranslations(this.locale, this.messages);

  final Locale locale;
  final Map<String, Object> messages;

  factory AppTranslations.fromJson(Locale locale, Object? value) {
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        value['locale'] != canonicalLanguageTag(locale) ||
        value['messages'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid app translation catalog');
    }
    final messages = <String, Object>{};
    for (final entry in (value['messages'] as Map<String, dynamic>).entries) {
      final message = entry.value;
      if (message is String && message.trim().isNotEmpty &&
          !appMessagePluralSources.containsKey(entry.key)) {
        messages[entry.key] = message;
      } else if (message is Map<String, dynamic> &&
          message['other'] is String &&
          message.values.every((v) => v is String && v.trim().isNotEmpty) &&
          message.keys.every(
            const {'zero', 'one', 'two', 'few', 'many', 'other'}.contains,
          )) {
        messages[entry.key] = Map<String, String>.unmodifiable(
          message.cast<String, String>(),
        );
      } else {
        throw const FormatException('Invalid translated message');
      }
      final expected = appMessagePlaceholders[entry.key] ?? const <String, int>{};
      final templates = message is String
          ? [message]
          : (message as Map<String, dynamic>).values.cast<String>();
      if (templates.any((text) => !mapEquals(_placeholderCounts(text), expected))) {
        throw const FormatException('Translated placeholder contract changed');
      }
    }
    return AppTranslations(locale, Map.unmodifiable(messages));
  }

  static AppTranslations? maybeOf(BuildContext context) =>
      Localizations.of<AppTranslations>(context, AppTranslations);

  String text(
    String english,
    String turkish, {
    Map<String, Object?> values = const {},
    num? pluralCount,
  }) {
    final tag = canonicalLanguageTag(locale);
    final id = appMessageIds[(english, turkish)];
    final translated = id == null ? null : messages[id];
    var template = tag == 'tr' ? turkish : english;
    if (pluralCount == 1 && id != null) {
      template = appMessagePluralSources[id]?[tag == 'tr' ? 'trOne' : 'enOne']
          ?? template;
    }
    if (translated is String) {
      template = translated;
    } else if (translated is Map<String, String> && pluralCount != null) {
      template = Intl.pluralLogic(
        pluralCount,
        locale: intlLocaleName(locale),
        zero: translated['zero'],
        one: translated['one'],
        two: translated['two'],
        few: translated['few'],
        many: translated['many'],
        other: translated['other']!,
      );
    }
    // A damaged catalog cannot remove or invent the caller's placeholders.
    // Literal braces in course notation are not formatting instructions.
    final expected = values.keys.toSet();
    if (expected.isNotEmpty &&
        !setEquals(_placeholderCounts(template).keys.toSet(), expected)) {
      template = tag == 'tr' ? turkish : english;
    }
    return template.replaceAllMapped(_messagePlaceholder, (match) {
      final key = match.group(1)!;
      if (!values.containsKey(key)) return match.group(0)!;
      final value = values[key];
      final numberFormat = NumberFormat.decimalPattern(intlLocaleName(locale));
      String rendered;
      if (value is AppDecimal) {
        numberFormat.minimumFractionDigits = value.fractionDigits;
        numberFormat.maximumFractionDigits = value.fractionDigits;
        rendered = numberFormat.format(value.value);
      } else if (value is num) {
        rendered = numberFormat.format(value);
      } else {
        rendered = value?.toString() ?? '—';
      }
      if (tag == 'ar') {
        // Isolate embedded values (email, notation, numbers or user draft)
        // from the surrounding sentence without changing their contents.
        rendered = '\u2068$rendered\u2069';
      }
      return rendered;
    });
  }
}

final class AppTranslationsDelegate
    extends LocalizationsDelegate<AppTranslations> {
  const AppTranslationsDelegate({this.bundle});

  final AssetBundle? bundle;

  @override
  bool isSupported(Locale locale) => _supportsAppLocale(locale);

  // Cache identities follow the bundle, so fixtures and replacement bundles
  // cannot inherit another bundle's translations or source fallback.
  static final _ready = Expando<Map<String, AppTranslations>>();
  static final _pending = Expando<Map<String, Future<AppTranslations>>>();

  @override
  Future<AppTranslations> load(Locale locale) {
    final canonical = localeForLanguageTag(canonicalLanguageTag(locale));
    final tag = canonicalLanguageTag(canonical);
    final assets = bundle ?? rootBundle;
    final ready = _ready[assets] ??= <String, AppTranslations>{};
    final cached = ready[tag];
    if (cached != null) return SynchronousFuture<AppTranslations>(cached);
    final pending = _pending[assets] ??= <String, Future<AppTranslations>>{};
    return pending.putIfAbsent(tag, () => _readCatalog(assets, canonical).then((value) {
      ready[tag] = value;
      pending.remove(tag);
      return value;
    }));
  }

  Future<AppTranslations> _readCatalog(AssetBundle assets, Locale locale) async {
    try {
      final raw = await assets.loadString(
        'assets/l10n/${canonicalLanguageTag(locale)}.json',
      ).timeout(const Duration(seconds: 3));
      return AppTranslations.fromJson(locale, jsonDecode(raw));
    } on Object {
      // A missing/invalid asset is cached as an exact source fallback too.
      // Once prepared, nested Localizations load it synchronously.
      return AppTranslations(locale, const {});
    }
  }

  @override
  bool shouldReload(AppTranslationsDelegate old) =>
      !identical(old.bundle ?? rootBundle, bundle ?? rootBundle);
}
