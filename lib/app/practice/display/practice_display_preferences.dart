import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../loop/practice_visual_theme.dart';

/// FK4 (plan F2.7) practice display settings: left-handed strip and the
/// colour-blind-safe palette. Both off by default.
@immutable
final class PracticeDisplaySettings {
  const PracticeDisplaySettings({
    this.leftHanded = false,
    this.colorBlindSafe = false,
  });

  final bool leftHanded;
  final bool colorBlindSafe;

  PracticeDisplaySettings copyWith({bool? leftHanded, bool? colorBlindSafe}) =>
      PracticeDisplaySettings(
        leftHanded: leftHanded ?? this.leftHanded,
        colorBlindSafe: colorBlindSafe ?? this.colorBlindSafe,
      );

  PracticeVisualTheme get theme => PracticeVisualTheme(
    leftHanded: leftHanded,
    colorBlindSafe: colorBlindSafe,
  );

  @override
  bool operator ==(Object other) =>
      other is PracticeDisplaySettings &&
      other.leftHanded == leftHanded &&
      other.colorBlindSafe == colorBlindSafe;

  @override
  int get hashCode => Object.hash(leftHanded, colorBlindSafe);
}

abstract interface class PracticeDisplayPreference {
  Future<PracticeDisplaySettings> read();
  Future<void> write(PracticeDisplaySettings settings);
}

/// One app-level file, `ostinato.practice_display.v1.json`:
/// `{schemaVersion: 1, leftHanded, colorBlindSafe}`. Presentation only: no
/// account, progress, audio or measurement.
final class FilePracticeDisplayPreference implements PracticeDisplayPreference {
  const FilePracticeDisplayPreference({this.directory});
  final Directory? directory;

  static const fileName = 'ostinato.practice_display.v1.json';

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/$fileName');
  }

  /// Missing, unreadable or another schema reads as both off; a flag that is
  /// not exactly `true` reads as off. An invalid read never writes.
  @override
  Future<PracticeDisplaySettings> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const PracticeDisplaySettings();
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['schemaVersion'] != 1) {
        return const PracticeDisplaySettings();
      }
      return PracticeDisplaySettings(
        leftHanded: json['leftHanded'] == true,
        colorBlindSafe: json['colorBlindSafe'] == true,
      );
    } on Object {
      return const PracticeDisplaySettings();
    }
  }

  @override
  Future<void> write(PracticeDisplaySettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'leftHanded': settings.leftHanded,
        'colorBlindSafe': settings.colorBlindSafe,
      }),
      flush: true,
    );
    await pending.rename(file.path);
  }
}

/// Holds the settings for the whole app; practice screens react through
/// [PracticeDisplayHost]. Changes show at once; writes are serialized and a
/// failed write rolls the change back and sets [saveFailed].
final class PracticeDisplayController extends ChangeNotifier {
  PracticeDisplayController({
    PracticeDisplayPreference preference =
        const FilePracticeDisplayPreference(),
    this.readDeadline = const Duration(seconds: 2),
  }) : _preference = preference;

  final PracticeDisplayPreference _preference;
  final Duration readDeadline;
  PracticeDisplaySettings _settings = const PracticeDisplaySettings();
  bool _loaded = false;
  bool _saveFailed = false;
  bool _disposed = false;
  int _revision = 0;
  Future<void>? _load;
  Future<void> _writes = Future<void>.value();

  PracticeDisplaySettings get settings => _settings;
  bool get loaded => _loaded;
  bool get saveFailed => _saveFailed;

  /// Read once at app start (bounded). A change made before the read lands
  /// wins over the stored value.
  Future<void> load() => _load ??= _read();

  Future<void> _read() async {
    PracticeDisplaySettings? value;
    try {
      value = await _preference.read().timeout(readDeadline);
    } on Object {
      value = null;
    }
    if (_disposed) return;
    // Any change made before the read lands is newer than the file.
    if (value != null && _revision == 0) _settings = value;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLeftHanded(bool on) =>
      _apply(_settings.copyWith(leftHanded: on));

  Future<void> setColorBlindSafe(bool on) =>
      _apply(_settings.copyWith(colorBlindSafe: on));

  Future<void> _apply(PracticeDisplaySettings next) {
    if (_disposed) throw StateError('Practice display controller disposed');
    final previous = _settings;
    final revision = ++_revision;
    _settings = next;
    _saveFailed = false;
    final done = _writes
        .then<void>((_) => _preference.write(next))
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (_disposed || revision != _revision) return;
            _settings = previous;
            _saveFailed = true;
            notifyListeners();
          },
        );
    _writes = done;
    notifyListeners();
    return done;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Lets the settings card reach the controller.
final class PracticeDisplayScope
    extends InheritedNotifier<PracticeDisplayController> {
  const PracticeDisplayScope({
    super.key,
    required PracticeDisplayController controller,
    required super.child,
  }) : super(notifier: controller);

  static PracticeDisplayController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PracticeDisplayScope>()
      ?.notifier;
}

/// Mount once above the app's navigator (main.dart). Publishes the controller
/// and the matching [PracticeVisualThemeScope] for every practice route.
final class PracticeDisplayHost extends StatelessWidget {
  const PracticeDisplayHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final PracticeDisplayController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => PracticeDisplayScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) => PracticeVisualThemeScope(
        theme: controller.settings.theme,
        child: child!,
      ),
    ),
  );
}
