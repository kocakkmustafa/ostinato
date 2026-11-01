import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../account_data_operations.dart';
import 'latency_calibration.dart';

/// F4.2 — results of the setup wizard, kept on this device only
/// (`setup_profile.v1.json` in application support; no audio, no network,
/// nothing written to Motion Core).
///
/// The values describe the phone and its audio route, not the person, so the
/// file is per device. Latency is stored **per route** (speaker, wired,
/// Bluetooth); a route without its own value is uncalibrated.
enum SetupStepState { done, skipped }

final class SetupStepRecord {
  const SetupStepRecord(this.state, this.at);
  final SetupStepState state;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'state': state.name,
    'at': at.toUtc().toIso8601String(),
  };

  static SetupStepRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final state = SetupStepState.values.asNameMap()[raw['state']];
    final at = DateTime.tryParse('${raw['at']}');
    return state == null || at == null ? null : SetupStepRecord(state, at);
  }
}

/// Room and level step: median room level over the quiet window and whether
/// a played string rose clearly above it.
final class RoomCheck {
  const RoomCheck({
    required this.floorDb,
    required this.heard,
    required this.at,
    this.peakDb,
  });

  final double floorDb;
  final double? peakDb;
  final bool heard;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'floorDb': floorDb,
    'peakDb': peakDb,
    'heard': heard,
    'at': at.toUtc().toIso8601String(),
  };

  static RoomCheck? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final floor = (raw['floorDb'] as num?)?.toDouble();
    final at = DateTime.tryParse('${raw['at']}');
    if (floor == null || at == null || raw['heard'] is! bool) return null;
    return RoomCheck(
      floorDb: floor,
      peakDb: (raw['peakDb'] as num?)?.toDouble(),
      heard: raw['heard'] as bool,
      at: at,
    );
  }
}

@immutable
final class SetupProfile {
  const SetupProfile({
    this.placement,
    this.room,
    this.roomStep,
    this.latencyStep,
    this.tuningStep,
    this.latency = const {},
    this.lastRoute,
  });

  static const empty = SetupProfile();

  final SetupStepRecord? placement;
  final RoomCheck? room;
  final SetupStepRecord? roomStep, latencyStep, tuningStep;
  final Map<CalibrationRoute, RouteLatency> latency;

  /// Route of the latest measured capture (calibration or practice), so the
  /// practice screen can say before starting whether timing will be shown.
  final CalibrationRoute? lastRoute;

  /// The wizard was opened and every step was either done or skipped.
  bool get visited =>
      placement != null &&
      roomStep != null &&
      latencyStep != null &&
      tuningStep != null;

  RouteLatency? latencyFor(CalibrationRoute? route) =>
      route == null ? null : latency[route];

  SetupProfile copyWith({
    SetupStepRecord? placement,
    RoomCheck? room,
    SetupStepRecord? roomStep,
    SetupStepRecord? latencyStep,
    SetupStepRecord? tuningStep,
    Map<CalibrationRoute, RouteLatency>? latency,
    CalibrationRoute? lastRoute,
  }) => SetupProfile(
    placement: placement ?? this.placement,
    room: room ?? this.room,
    roomStep: roomStep ?? this.roomStep,
    latencyStep: latencyStep ?? this.latencyStep,
    tuningStep: tuningStep ?? this.tuningStep,
    latency: latency ?? this.latency,
    lastRoute: lastRoute ?? this.lastRoute,
  );

  SetupProfile withLatency(CalibrationRoute route, RouteLatency value) =>
      copyWith(latency: {...latency, route: value}, lastRoute: route);

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'placement': placement?.toJson(),
    'room': room?.toJson(),
    'roomStep': roomStep?.toJson(),
    'latencyStep': latencyStep?.toJson(),
    'tuningStep': tuningStep?.toJson(),
    'latency': {for (final e in latency.entries) e.key.name: e.value.toJson()},
    'lastRoute': lastRoute?.name,
  };

  factory SetupProfile.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported setup profile schema');
    }
    final routes = CalibrationRoute.values.asNameMap();
    final latency = <CalibrationRoute, RouteLatency>{};
    final raw = json['latency'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final route = routes[e.key];
        if (route != null && e.value is Map) {
          latency[route] = RouteLatency.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          );
        }
      }
    }
    return SetupProfile(
      placement: SetupStepRecord.fromJson(json['placement']),
      room: RoomCheck.fromJson(json['room']),
      roomStep: SetupStepRecord.fromJson(json['roomStep']),
      latencyStep: SetupStepRecord.fromJson(json['latencyStep']),
      tuningStep: SetupStepRecord.fromJson(json['tuningStep']),
      latency: latency,
      lastRoute: routes[json['lastRoute']],
    );
  }
}

/// Read/update interface; tests use [MemorySetupProfileStore].
abstract interface class SetupProfileStore {
  Future<SetupProfile> load();
  Future<SetupProfile> update(SetupProfile Function(SetupProfile) change);
}

final class MemorySetupProfileStore implements SetupProfileStore {
  MemorySetupProfileStore([this.profile = SetupProfile.empty]);
  SetupProfile profile;

  @override
  Future<SetupProfile> load() async => profile;

  @override
  Future<SetupProfile> update(
    SetupProfile Function(SetupProfile) change,
  ) async => profile = change(profile);
}

final class FileSetupProfileStore implements SetupProfileStore {
  FileSetupProfileStore({Future<Directory> Function()? directoryProvider})
    : _operations = AccountDataOperations(
        directoryProvider ?? getApplicationSupportDirectory,
      );

  static const fileName = 'setup_profile.v1.json';
  final AccountDataOperations _operations;

  /// One store per process: the wizard and the practice screen read the
  /// same values.
  static final FileSetupProfileStore device = FileSetupProfileStore();

  @override
  Future<SetupProfile> load() =>
      _operations.run((dir) => _load(File('${dir.path}/$fileName')));

  Future<SetupProfile> _load(File file) async {
    if (!await file.exists()) return SetupProfile.empty;
    try {
      return SetupProfile.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on FormatException {
      // A damaged file is a missing calibration, never a wrong one.
      return SetupProfile.empty;
    } on TypeError {
      return SetupProfile.empty;
    }
  }

  @override
  Future<SetupProfile> update(SetupProfile Function(SetupProfile) change) =>
      _operations.run((dir) async {
        final file = File('${dir.path}/$fileName');
        final next = change(await _load(file));
        await file.parent.create(recursive: true);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString('${jsonEncode(next.toJson())}\n', flush: true);
        await temp.rename(file.path);
        return next;
      }, writing: true);
}
