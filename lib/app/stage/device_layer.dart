import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../design/ostinato_theme.dart';
import '../practice/setup/setup_audio_controller.dart';
import '../practice/setup/setup_profile_store.dart';
import '../ui_copy.dart';
import 'stage_copy.dart';

/// OST-UX-05f: the "Setup" handle's layer. Four read-only facts and the exits
/// to the existing full screens; no new measuring engine. The microphone line
/// is the permission status; the room line reads the stored setup profile and
/// says "not measured" when there is none. Scrolls inside the layer; every
/// row is at least 48 dp.
class DeviceLayer extends StatefulWidget {
  const DeviceLayer({
    super.key,
    required this.micStatus,
    required this.profile,
    required this.openAppSettings,
    required this.openLatency,
    required this.openSettings,
    this.openAccount,
    this.openMembership,
  });

  /// The microphone permission now (read only, never asks).
  final Future<PermissionStatus> Function() micStatus;

  /// The stored setup profile (read only).
  final Future<SetupProfile> Function() profile;

  /// The system Settings page of this app (shown while the microphone is not
  /// allowed).
  final Future<void> Function() openAppSettings;

  /// The existing setup wizard (latency step stays as it is).
  final Future<void> Function() openLatency;
  final Future<void> Function() openSettings;
  final Future<void> Function()? openAccount;
  final Future<void> Function()? openMembership;

  @override
  State<DeviceLayer> createState() => _DeviceLayerState();
}

class _DeviceLayerState extends State<DeviceLayer> with WidgetsBindingObserver {
  PermissionStatus? _mic;
  RoomNoise? _noise;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _read() async {
    PermissionStatus? mic;
    RoomNoise? noise;
    try {
      mic = await widget.micStatus();
    } on Object {
      mic = null;
    }
    try {
      final room = (await widget.profile()).room;
      if (room != null) noise = roomNoiseFor(room.floorDb);
    } on Object {
      noise = null;
    }
    if (!mounted) return;
    setState(() {
      _mic = mic;
      _noise = noise;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mic = _mic;
    final micText = switch (mic) {
      null => uiText(context, StageCopy.microphone),
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => uiText(context, StageCopy.micAllowed),
      PermissionStatus.permanentlyDenied => uiText(
        context,
        StageCopy.micBlocked,
      ),
      PermissionStatus.restricted => uiText(context, StageCopy.micRestricted),
      PermissionStatus.denied => uiText(context, StageCopy.micDenied),
    };
    final noiseText = uiText(context, switch (_noise) {
      null => StageCopy.noiseUnknown,
      RoomNoise.quiet => StageCopy.noiseQuiet,
      RoomNoise.some => StageCopy.noiseSome,
      RoomNoise.loud => StageCopy.noiseLoud,
    });
    return SingleChildScrollView(
      key: const Key('stage-device-layer'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            uiText(context, StageCopy.deviceTitle),
            style: hankenText(size: 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (mic == null ||
              mic == PermissionStatus.granted ||
              mic == PermissionStatus.limited ||
              mic == PermissionStatus.provisional)
            _info('stage-device-mic', micText)
          else
            _row(
              'stage-device-mic',
              micText,
              widget.openAppSettings,
              icon: Icons.mic_off_outlined,
              hint: uiText(context, StageCopy.goToSettings),
            ),
          _info('stage-device-noise', noiseText),
          _row(
            'stage-device-latency',
            uiText(context, StageCopy.latencyCalibration),
            widget.openLatency,
            icon: Icons.timer_outlined,
          ),
          _row(
            'stage-device-settings',
            uiText(context, StageCopy.settings),
            widget.openSettings,
            icon: Icons.settings_outlined,
          ),
          if (widget.openAccount != null)
            _row(
              'stage-device-account',
              uiText(context, StageCopy.account),
              widget.openAccount!,
              icon: Icons.person_outline,
            ),
          if (widget.openMembership != null)
            _row(
              'stage-device-membership',
              uiText(context, StageCopy.membership),
              widget.openMembership!,
              icon: Icons.workspace_premium_outlined,
            ),
        ],
      ),
    );
  }

  Widget _info(String key, String text) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        key: Key(key),
        style: hankenText(size: 15, weight: FontWeight.w500),
      ),
    ),
  );

  Widget _row(
    String key,
    String label,
    Future<void> Function() onTap, {
    required IconData icon,
    String? hint,
  }) => Semantics(
    container: true,
    button: true,
    label: hint == null ? label : '$label, $hint',
    onTap: () => _go(onTap),
    excludeSemantics: true,
    child: InkWell(
      key: Key(key),
      onTap: () => _go(onTap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: hankenText(size: 15, weight: FontWeight.w500),
              ),
            ),
            if (hint != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(hint, style: hankenText(size: 13)),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  /// An exit returned (a full screen was closed): read the facts again.
  Future<void> _go(Future<void> Function() exit) async {
    try {
      await exit();
    } finally {
      if (mounted) unawaited(_read());
    }
  }
}
