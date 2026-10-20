import 'package:flutter/material.dart';
import '../app_locale.dart';
import '../vocal_beginner.dart';

/// Original written practice. Relative tones are personal choices, not pitches.
class VocalDiagrams extends StatelessWidget {
  const VocalDiagrams({super.key, required this.course, required this.lesson});
  final VocalCourse course;
  final VocalLesson lesson;

  Widget _cell(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
    ),
  );
  Widget _grid(
    BuildContext context,
    String id,
    List<List<String>> rows, {
    required double width,
    required String description,
  }) => Semantics(
    label: description,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        key: Key(id),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Table(
            // Beat columns and their scroll origin retain musical order.
            // _cell uses the caller's direction for translated cell text.
            textDirection: TextDirection.ltr,
            border: TableBorder.all(color: Theme.of(context).dividerColor),
            children: [
              for (final row in rows)
                TableRow(
                  children: [for (final cell in row) _cell(context, cell)],
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _answer(BuildContext context, String id, String answer) =>
      ExpansionTile(
        key: Key('vocal-$id-answers'),
        title: Text(
          localized(context, 'Separate reading answer', 'Ayrı okuma cevabı'),
        ),
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(answer)),
        ],
      );
  String _eventDescription(BuildContext context, VocalEvent event) =>
      switch (event.kind) {
        'voice' => localized(
          context,
          'start {v0}, {v1}',
          'başla {v0}, {v1}',
          values: {'v0': event.tone, 'v1': event.syllable!.of(context)},
        ),
        'hold' => localized(
          context,
          'continue sound or silence',
          'ses veya sessizlik devam',
        ),
        _ => localized(context, 'release to silence', 'bırak ve sus'),
      };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final id in lesson.diagrams) ...[
        const SizedBox(height: 16),
        if (id == 'rhythm') ...[
          Text(
            localized(
              context,
              'Quarter-beat reading task: V = start, = = continue sound or silence, R = release into counted silence. Never hold your breath. Count 1 2 3 4 in each bar.',
              'Dörtlük vuruş okuma görevi: V = başla, = = sesi veya sessizliği sürdür, R = bırak ve sayarak sus. Nefesini tutma. Her ölçüde 1 2 3 4 say.',
            ),
          ),
          _grid(
            context,
            'vocal-rhythm',
            [
              [for (var beat = 1; beat <= 4; beat++) appInteger(context, beat)],
              ['V', '=', 'R', 'R'],
              ['V', 'V', 'R', 'R'],
            ],
            width: 400,
            description: localized(
              context,
              'Two quarter-beat bars: first V, continuation, rest, rest; second V, V, rest, rest.',
              'İki dörtlük vuruş ölçüsü: ilk V, devam, sus, sus; ikinci V, V, sus, sus.',
            ),
          ),
          _answer(context, 'rhythm', course.rhythmAnswer.of(context)),
        ],
        if (id == 'contour') ...[
          Text(
            localized(
              context,
              'Original quarter-beat contour. M = your comfortable centre; L/H = nearby lower/higher, not quieter/louder. Each letter starts a new sound. R = counted silence. No fixed note or interval.',
              'Özgün dörtlük vuruş çizgisi. M = rahat merkezin; L/H = yakın pes/tiz, daha kısık/yüksek ses değil. Her harf yeni ses başlatır. R = sayılan sessizlik. Sabit nota veya aralık yok.',
            ),
          ),
          _grid(
            context,
            'vocal-contour',
            [
              [for (var beat = 1; beat <= 4; beat++) appInteger(context, beat)],
              ...course.contour,
            ],
            width: 400,
            description: localized(
              context,
              'Bar 1: M H M R. Bar 2: L M M R. Each letter is a new start.',
              'Ölçü 1: M H M R. Ölçü 2: L M M R. Her harf yeni başlangıç.',
            ),
          ),
          _answer(context, 'contour', course.contourAnswer.of(context)),
        ],
        if (id == 'study') ...[
          Text(
            localized(
              context,
              'Eight original 4/4 bars. Each column is one half-beat: 1 & 2 & 3 & 4 &. V starts the printed tone and syllable; = continues the current sound or silence; R releases into silence. H means higher tone only. Breathe whenever needed; shorten a phrase and record that adaptation. Counts are reading suggestions, never breath targets.',
              'Sekiz özgün 4/4 ölçü. Her sütun yarım vuruş: 1 ve 2 ve 3 ve 4 ve. V yazılan perdeyi ve heceyi başlatır; = mevcut sesi veya sessizliği sürdürür; R bırakıp susturur. H yalnız tiz perde. Gerektiğinde nefes al; cümleyi kısalt ve uyarlamayı yaz. Sayılar okuma önerisi, nefes hedefi değil.',
            ),
          ),
          for (var i = 0; i < course.study.length; i++) ...[
            Text(localized(
              context, 'Bar {v0}', 'Ölçü {v0}', values: {'v0': i + 1},
            )),
            _grid(
              context,
              'vocal-study-${i + 1}',
              [
                [
                  for (var j = 0; j < 8; j++)
                    j.isEven
                        ? appInteger(context, j ~/ 2 + 1)
                        : localized(context, '&', 've'),
                ],
                [
                  for (final e in course.study[i].events)
                    switch (e.kind) {
                      'voice' => 'V ${e.tone}\n${e.syllable!.of(context)}',
                      'hold' => '=',
                      _ => 'R',
                    },
                ],
              ],
              width: 800,
              description: localized(
                context,
                'Bar {v0}, half-beat symbols: {v1}',
                'Ölçü {v0}, yarım vuruş sembolleri: {v1}',
                values: {
                  'v0': i + 1,
                  'v1': course.study[i].events
                      .map((event) => _eventDescription(context, event))
                      .join('; '),
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    ],
  );
}
