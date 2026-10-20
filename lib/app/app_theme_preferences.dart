import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_theme.dart';

enum AppThemePreference { system, light, dark }

abstract interface class AppThemePreferences {
  Future<AppThemePreference> read();
  Future<void> write(AppThemePreference preference);
}

/// One app-level appearance file. This is neither user data nor an account,
/// course-progress or locale key. An invalid read never writes a replacement.
final class FileAppThemePreferences implements AppThemePreferences {
  const FileAppThemePreferences({this.directory});
  final Directory? directory;

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/ostinato.theme.v1.json');
  }

  @override
  Future<AppThemePreference> read() async {
    final file = await _file();
    if (!await file.exists()) return AppThemePreference.system;
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic> || json['schemaVersion'] != 1) {
      throw const FormatException('Invalid theme preference');
    }
    final name = json['mode'];
    for (final mode in AppThemePreference.values) {
      if (mode.name == name) return mode;
    }
    throw const FormatException('Unsupported saved theme');
  }

  @override
  Future<void> write(AppThemePreference preference) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'mode': preference.name}),
      flush: true,
    );
    await pending.rename(file.path);
  }
}

final class AppThemeController extends ChangeNotifier {
  AppThemeController({
    AppThemePreferences preferences = const FileAppThemePreferences(),
    this.readDeadline = const Duration(seconds: 2),
  }) : _preferences = preferences;

  final AppThemePreferences _preferences;
  final Duration readDeadline;
  AppThemePreference _preference = AppThemePreference.system;
  bool _loading = true;
  bool _readFailed = false;
  bool _writeFailed = false;
  bool _saving = false;
  bool _hasSavedSelection = false;
  bool _disposed = false;
  int _selectionRevision = 0;
  Future<void>? _load;
  Future<void> _writeQueue = Future<void>.value();

  AppThemePreference get preference => _preference;
  ThemeMode get themeMode => switch (_preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
  bool get loading => _loading;
  bool get readFailed => _readFailed;
  bool get writeFailed => _writeFailed;
  bool get saving => _saving;
  bool get hasSavedSelection => _hasSavedSelection;

  /// Await before the first MaterialApp is mounted. The maximum read wait is
  /// bounded; late read completion has no state mutation after timeout.
  Future<void> load() => _load ??= _selectionRevision == 0
      ? _read()
      : Future<void>.value();

  Future<void> _read() async {
    final revision = _selectionRevision;
    try {
      final value = await _preferences.read().timeout(readDeadline);
      if (_disposed || revision != _selectionRevision) return;
      _preference = value;
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

  /// Selection changes presentation immediately. Disk writes remain serialized
  /// through their actual completion; a timeout must not let an old rename race
  /// a newer write. Callers need not block navigation on this Future.
  Future<void> select(AppThemePreference value) {
    if (_disposed) throw StateError('Theme controller disposed');
    final revision = ++_selectionRevision;
    _preference = value;
    _loading = false;
    _readFailed = false;
    _writeFailed = false;
    _saving = true;
    _hasSavedSelection = false;
    final operation = _writeQueue.then<void>((_) => _preferences.write(value));
    final completion = operation.then<void>(
      (_) {
        if (_disposed || revision != _selectionRevision) return;
        _saving = false;
        _hasSavedSelection = true;
        _writeFailed = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed || revision != _selectionRevision) return;
        _saving = false;
        _writeFailed = true;
        notifyListeners();
      },
    );
    // A synchronous listener may select again. Reserve this write's queue slot
    // before notifying, and return this operation's own completion Future.
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

final class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppThemeScope>()
      ?.notifier;

  static ThemeMode modeOf(BuildContext context) =>
      maybeOf(context)?.themeMode ?? ThemeMode.system;
}

/// Create and load once during main's existing bootstrap, before runApp, then
/// keep this host above AppLocaleHost, AudioRoot and MotionIdentityGate.
/// No key or resource-admission epoch may depend on appearance or language.
final class AppThemeHost extends StatefulWidget {
  AppThemeHost({
    super.key,
    required this.controller,
    required this.child,
    this.disposeController = true,
  }) {
    if (controller.loading) {
      throw StateError('Load theme preference before mounting AppThemeHost');
    }
  }

  final AppThemeController controller;
  final Widget child;
  final bool disposeController;

  @override
  State<AppThemeHost> createState() => _AppThemeHostState();
}

final class _AppThemeHostState extends State<AppThemeHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    if (widget.controller.preference == AppThemePreference.system) setState(() {});
  }

  @override
  void didUpdateWidget(AppThemeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      throw StateError('Theme controller identity must remain stable');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.disposeController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    child: widget.child,
    builder: (context, child) {
      final brightness = switch (widget.controller.preference) {
        AppThemePreference.light => Brightness.light,
        AppThemePreference.dark => Brightness.dark,
        AppThemePreference.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };
      return AppThemeScope(
        controller: widget.controller,
        child: Theme(data: OstinatoThemes.forBrightness(brightness), child: child!),
      );
    },
  );
}
