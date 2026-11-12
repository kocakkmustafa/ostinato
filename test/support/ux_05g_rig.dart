// OST-UX-05g test rig: the 05f stage rig plus the ghost flag and store.
import 'package:flutter/material.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';

import 'practice_host.dart';
import 'ux_05f_rig.dart';

export 'ux_05f_rig.dart';

Widget stage05g(
  Rig05f rig,
  V1CourseCatalog catalog, {
  bool ghost = true,
  GhostStore? ghostStore,
  String locale = 'tr',
  double textScale = 1.0,
}) => practiceHost(
  locale: locale,
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: StageHomeScreen(
        catalog: catalog,
        progressFactory: (_) => Mem05f(),
        checksFactory: (_) => Checks05f(),
        controllerFactory: rig.factory,
        seed: 1,
        ghostOpen: ghost,
        ghostStore: ghostStore,
        tunerOpener: (_) async {},
        earScreenBuilder: (_) => const Scaffold(body: Text('ear-screen')),
      ),
    ),
  ),
);
