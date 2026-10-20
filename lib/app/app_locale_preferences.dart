import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'app_translation_catalog.dart';

/// App presentation preference, independent of account/progress ownership.
abstract interface class AppLocalePreferences {
  Future<String?> read();
  Future<void> write(String? languageTag);
}

final class FileAppLocalePreferences implements AppLocalePreferences {
  const FileAppLocalePreferences({this.directory});

  final Directory? directory;

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/ostinato.locale.v1.json');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        !value.containsKey('languageTag')) {
      throw const FormatException('Invalid language preference');
    }
    final tag = value['languageTag'];
    if (tag != null &&
        (tag is! String || !supportedLanguageTags.contains(tag))) {
      throw const FormatException('Unsupported saved language');
    }
    return tag as String?;
  }

  @override
  Future<void> write(String? languageTag) async {
    if (languageTag != null && !supportedLanguageTags.contains(languageTag)) {
      throw ArgumentError.value(languageTag, 'languageTag');
    }
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'languageTag': languageTag}),
      flush: true,
    );
    await pending.rename(file.path);
  }
}

/// A failed read never writes a default over the existing bytes. Explicit
/// selection takes effect immediately, then serializes its own disk write.
final class AppLocaleController extends ChangeNotifier {
  AppLocaleController({
    AppLocalePreferences preferences = const FileAppLocalePreferences(),
    Duration readTimeout = const Duration(seconds: 3),
  }) : assert(readTimeout > Duration.zero),
       _preferences = preferences,
       _readTimeout = readTimeout;

  final AppLocalePreferences _preferences;
  final Duration _readTimeout;
  String? _languageTag;
  bool _loading = true;
  bool _readFailed = false;
  bool _writeFailed = false;
  bool _disposed = false;
  int _selectionRevision = 0;
  Future<void>? _load;
  Future<void> _writeQueue = Future<void>.value();

  String? get languageTag => _languageTag;
  Locale? get locale =>
      _languageTag == null ? null : localeForLanguageTag(_languageTag!);
  bool get loading => _loading;
  bool get readFailed => _readFailed;
  bool get writeFailed => _writeFailed;

  Future<void> load() =>
      _load ??= _selectionRevision == 0 ? _read() : Future<void>.value();

  Future<void> _read() async {
    final revision = _selectionRevision;
    try {
      final tag = await _preferences.read().timeout(_readTimeout);
      if (_disposed || revision != _selectionRevision) return;
      if (tag != null && !supportedLanguageTags.contains(tag)) {
        throw const FormatException('Unsupported saved language');
      }
      _languageTag = tag;
      _readFailed = false;
    } on Object {
      if (_disposed || revision != _selectionRevision) return;
      _readFailed = true;
    } finally {
      if (!_disposed && revision == _selectionRevision) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(String? tag) {
    if (_disposed) throw StateError('Language controller disposed');
    if (tag != null && !supportedLanguageTags.contains(tag)) {
      throw ArgumentError.value(tag, 'tag');
    }
    final revision = ++_selectionRevision;
    _languageTag = tag;
    _loading = false;
    _readFailed = false;
    _writeFailed = false;
    final operation = _writeQueue.then<void>((_) => _preferences.write(tag));
    // Recover the queue after a failed write so a later explicit choice can
    // still persist. Only the current choice may publish persistence status.
    final completion = operation.then<void>(
      (_) {
        if (_disposed || revision != _selectionRevision) return;
        _writeFailed = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed || revision != _selectionRevision) return;
        _writeFailed = true;
        notifyListeners();
      },
    );
    // Publish the queue before callbacks can synchronously select again.
    _writeQueue = completion;
    notifyListeners();
    return completion;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.notifier;
}

final class AppLocaleHost extends StatefulWidget {
  const AppLocaleHost({
    super.key,
    required this.child,
    this.preferences = const FileAppLocalePreferences(),
    this.translationBundle,
  });

  final Widget child;
  final AppLocalePreferences preferences;
  final AssetBundle? translationBundle;

  @override
  State<AppLocaleHost> createState() => _AppLocaleHostState();
}

final class _AppLocaleHostState extends State<AppLocaleHost>
    with WidgetsBindingObserver {
  late final AppLocaleController _controller;
  Locale? _publishedLocale;
  AssetBundle? _publishedBundle;
  (AssetBundle, String)? _requested;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AppLocaleController(preferences: widget.preferences);
    _controller.addListener(_prepareSelection);
    WidgetsBinding.instance.addObserver(this);
    // load catches preference IO/parse failures; publication waits until it
    // finishes, preventing a temporary system locale from owning the child.
    unawaited(_controller.load());
  }

  void _prepareSelection() {
    if (!mounted || _controller.loading) return;
    final locale =
        _controller.locale ??
        resolveAppLocales(
          WidgetsBinding.instance.platformDispatcher.locales,
          ostinatoSupportedLocales,
        );
    final assets = widget.translationBundle ?? rootBundle;
    final request = (assets, canonicalLanguageTag(locale));
    if (_requested?.$2 == request.$2 && identical(_requested?.$1, assets)) {
      return;
    }
    _requested = request;
    final generation = ++_generation;
    unawaited(_prepareAndPublish(generation, locale, assets));
  }

  Future<void> _prepareAndPublish(
    int generation,
    Locale locale,
    AssetBundle assets,
  ) async {
    try {
      // Never pass a not-yet-prepared locale into Flutter's Localizations:
      // its async completion does not reject an older locale request.
      await AppTranslationsDelegate(bundle: assets).load(locale);
    } on Object {
      // Delegate asset/parse failures normally resolve to cached source copy.
      // An unexpected preparation error still must not escape this detached
      // operation or replace the last successfully published subtree.
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _publishedLocale = locale;
      _publishedBundle = assets;
    });
  }

  @override
  void didUpdateWidget(covariant AppLocaleHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.translationBundle ?? rootBundle,
      widget.translationBundle ?? rootBundle,
    )) {
      _requested = null;
      _prepareSelection();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_controller.languageTag == null) _prepareSelection();
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_prepareSelection);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppLocaleScope(
    controller: _controller,
    child: _publishedLocale == null
        ? const SizedBox.shrink()
        : Localizations(
            locale: _publishedLocale!,
            delegates: [
              AppTranslationsDelegate(bundle: _publishedBundle),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Locale and catalog changes do not introduce a widget key or
            // replace the caller's child, Navigator, route or form state.
            child: widget.child,
          ),
  );
}
