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
    required this.openLatency,
    required this.openSettings,
    this.openAccount,
    this.openMembership,
  });

  /// The microphone permission now (read only, never asks).
  final Future<PermissionStatus> Function() micStatus;

  /// The stored setup profile (read only).
  final Future<SetupProfile> Function() profile;

  /// The existing setup wizard (latency step stays as it is).
  final VoidCallback openLatency;
  final VoidCallback openSettings;
  final VoidCallback? openAccount;
  final VoidCallback? openMembership;

  @override
  State<DeviceLayer> createState() => _DeviceLayerState();
}

class _DeviceLayerState extends State<DeviceLayer> {
  PermissionStatus? _mic;
  RoomNoise? _noise;

  @override
  void initState() {
    super.initState();
    _read();
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
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => uiText(context, StageCopy.micBlocked),
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
          _info('stage-device-mic', micText),
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
    VoidCallback onTap, {
    required IconData icon,
  }) => Semantics(
    button: true,
    child: InkWell(
      key: Key(key),
      onTap: onTap,
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
