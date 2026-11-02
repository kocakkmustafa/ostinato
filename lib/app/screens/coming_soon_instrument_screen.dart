import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_theme.dart';
import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../ui_copy.dart';
import 'v1_home_copy.dart';

/// The page of an instrument whose course is not open in this release
/// (`ostinatoOpenInstruments`): its name, "Coming soon" and what the course
/// will cover. No lessons open from here.
class ComingSoonInstrumentScreen extends StatelessWidget {
  const ComingSoonInstrumentScreen({super.key, required this.discipline});
  final Discipline discipline;

  static UiCopy? coverage(String instrumentId) => switch (instrumentId) {
    'voice' => V1HomeCopy.comingSoonVoice,
    'piano' => V1HomeCopy.comingSoonPiano,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final hue = palette.instrument(discipline.id);
    final covers = coverage(discipline.id);
    return Scaffold(
      key: Key('coming-soon-page-${discipline.id}'),
      backgroundColor: palette.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(gradient: hue.gradient),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      GlassIconButton(
                        icon: '‹',
                        semanticLabel: localized(
                          context,
                          'Back to library',
                          'Kütüphaneye dön',
                        ),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        catalogName(
                          context,
                          discipline.id,
                          discipline.displayName,
                        ),
                        style: hankenText(
                          size: 30,
                          weight: FontWeight.w600,
                          color: palette.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        uiText(context, V1HomeCopy.comingSoon),
                        key: const Key('coming-soon-line'),
                        style: hankenText(
                          size: 15,
                          weight: FontWeight.w500,
                          color: hue.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (covers != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GlassCard(
                    child: Text(
                      uiText(context, covers),
                      key: const Key('coming-soon-coverage'),
                      style: hankenText(
                        size: 14.5,
                        height: 1.5,
                        color: palette.textBody,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
