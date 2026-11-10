import 'package:flutter/material.dart';

import '../practice/loop/v1_course_catalog.dart';
import '../ui_copy.dart';
import 'ux_prototype_copy.dart';
import 'ux_prototype_screen.dart';

/// The ONLY entry to the OST-UX-04 prototype: one button in Settings, built
/// only while `ostinatoUxPrototypeOpen` is true (the Settings screen checks
/// the flag; this widget does not look at it).
class UxPrototypeEntryButton extends StatelessWidget {
  const UxPrototypeEntryButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('ux-prototype-entry'),
    onPressed: () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            UxPrototypeScreen(catalog: V1CourseCatalog.load(course: 'gtr')),
      ),
    ),
    icon: const Icon(Icons.science_outlined),
    label: Text(uiText(context, UxPrototypeCopy.entryLabel)),
  );
}
