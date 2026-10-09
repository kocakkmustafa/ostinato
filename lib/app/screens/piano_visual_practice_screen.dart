import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../guitar_journey.dart' show GuitarText;
import 'piano_notation.dart';
import 'visual_practice_loop.dart';

enum _Hands { right, left, both }

/// One original study bar. Illustrations do not show actual hands or sound.
class PianoVisualPracticeScreen extends StatefulWidget {
  const PianoVisualPracticeScreen({super.key});
  @override
  State<PianoVisualPracticeScreen> createState() =>
      _PianoVisualPracticeScreenState();
}

class _PianoVisualPracticeScreenState extends State<PianoVisualPracticeScreen> {
  _Hands _hands = _Hands.both;

  String _pitch(BuildContext context, String pitch) {
    final name = switch (pitch[0]) {
      'C' => 'Do',
      'D' => 'Re',
      'E' => 'Mi',
      'F' => 'Fa',
      'G' => 'Sol',
      _ => pitch[0],
    };
    return localized(context, pitch, '$name${pitch.substring(1)}');
  }

  String _handLabel(BuildContext context, _Hands hands) => switch (hands) {
    _Hands.right => localized(context, 'Right hand only', 'Yalnız sağ el'),
    _Hands.left => localized(context, 'Left hand only', 'Yalnız sol el'),
    _Hands.both => localized(context, 'Both hands', 'İki el'),
  };

  List<VisualPracticeStep> _steps() {
    // The original first bar: RH C4 D4 E4 G4 quarters; LH C3 whole.
    final right = pianoStudyRight.first;
    final left = pianoStudyLeft.first.single;
    if (right.length != 4 ||
        right.any((note) => note.beats != 1 || note.pitch == null) ||
        left.beats != 4 ||
        left.pitch == null) {
      throw const FormatException('Unsupported original piano practice bar');
    }
    return List<VisualPracticeStep>.unmodifiable([
      for (var i = 0; i < 4; i++)
        VisualPracticeStep(
          label: GuitarText(
            'Bar 1 · count ${i + 1}',
            'Ölçü 1 · sayım ${i + 1}',
          ),
          instruction: GuitarText(
            '${i == 0 && _hands == _Hands.both ? 'Start left C3 and right C4 together on count 1. ' : ''}${_hands != _Hands.left ? (i == 0 ? 'Right: start ${right[i].pitch}, for one beat. ' : 'Right: release ${right[i - 1].pitch} and start ${right[i].pitch}, for one beat. ') : 'Right: stay at rest. '}'
                '${_hands != _Hands.right ? (i == 0 ? 'Left: start ${left.pitch} and keep it through all four beats.' : 'Left: continue holding ${left.pitch}; do not strike again.') : 'Left: stay at rest.'}',
            '${i == 0 && _hands == _Hands.both ? 'Sayım 1’de sol Do3 ve sağ Do4’ü birlikte başlat. ' : ''}${_hands != _Hands.left ? (i == 0 ? 'Sağ: ${_trPitch(right[i].pitch!)} başlat, bir vuruş sürdür. ' : 'Sağ: ${_trPitch(right[i - 1].pitch!)} bırak ve ${_trPitch(right[i].pitch!)} başlat, bir vuruş sürdür. ') : 'Sağ: çalma; dinlen. '}'
                '${_hands != _Hands.right ? (i == 0 ? 'Sol: ${_trPitch(left.pitch!)} başlat ve dört vuruş boyunca sürdür.' : 'Sol: ${_trPitch(left.pitch!)} tutmayı sürdür; yeniden basma.') : 'Sol: çalma; dinlen.'}',
          ),
        ),
      VisualPracticeStep(
        label: const GuitarText(
          'After count 4 · release',
          'Sayım 4’ten sonra · bırak',
        ),
        instruction: const GuitarText(
          'After the fourth beat has ended, release the sounding keys. This ends the bar; it is not an extra fifth beat. No pedal. Pause before a new silent count-in.',
          'Dördüncü vuruş bittikten sonra çalan tuşları bırak. Bu ölçüyü bitirir; ek beşinci vuruş değildir. Pedal yok. Yeni sessiz giriş sayımından önce durakla.',
        ),
      ),
    ]);
  }

  String _trPitch(String pitch) =>
      '${switch (pitch[0]) {
        'C' => 'Do',
        'D' => 'Re',
        'E' => 'Mi',
        'G' => 'Sol',
        _ => pitch[0],
      }}${pitch.substring(1)}';

  Widget _choices(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final hands in _Hands.values)
        OutlinedButton(
          key: Key('piano-visual-${hands.name}'),
          onPressed: () => setState(() => _hands = hands),
          child: Text(_handLabel(context, hands)),
        ),
    ],
  );

  String _cellLabel(BuildContext context, int beat) =>
      '${localized(context, 'Count', 'Sayım')} ${beat + 1} · '
      '${localized(context, 'RH', 'Sağ')}: ${_hands == _Hands.left ? localized(context, 'rest', 'dinlenme') : _pitch(context, pianoStudyRight.first[beat].pitch!)} · '
      '${localized(context, 'LH', 'Sol')}: ${_hands == _Hands.right ? localized(context, 'rest', 'dinlenme') : '${_pitch(context, pianoStudyLeft.first.single.pitch!)} ${localized(context, beat == 0 ? 'start' : 'hold, no new attack', beat == 0 ? 'başlat' : 'sürdür, yeni başlangıç yok')}'}';

  Widget _grid(BuildContext context, int step) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        localized(
          context,
          'Original bar 1 · 4/4 · no pedal',
          'Özgün ölçü 1 · 4/4 · pedal yok',
        ),
      ),
      for (var beat = 0; beat < 4; beat++)
        Semantics(
          key: Key('piano-visual-count-${beat + 1}'),
          label: _cellLabel(context, beat),
          excludeSemantics: true,
          selected: step == beat,
          child: Card(
            color: step == beat
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_cellLabel(context, beat)),
            ),
          ),
        ),
      Text(
        localized(
          context,
          'Four equal count cells, not a recording or captured fingering. Use the grand staff in the lesson for notation; changing colour does not measure your keys.',
          'Dört eşit sayım hücresi, kayıt veya yakalanmış parmak hareketi değil. Nota için dersteki iki dizeği kullan; renk değişimi tuşlarını ölçmez.',
        ),
      ),
    ],
  );

  String get _taskIdentity =>
      'piano.original-study.bar1.v2|${_hands.name}|'
      '${pianoStudyRight.first.map((n) => '${n.pitch}:${n.beats}').join(',')}|'
      '${pianoStudyLeft.first.map((n) => '${n.pitch}:${n.beats}').join(',')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        localized(
          context,
          'Piano: one-bar practice',
          'Piyano: tek ölçü çalışması',
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _choices(context),
        Text(
          _handLabel(context, _hands),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        VisualPracticeLoop(
          key: ValueKey(_taskIdentity),
          taskIdentity: _taskIdentity,
          steps: _steps(),
          target: const GuitarText(
            'Find C3 for the left hand and C4–G4 for the right using the lesson’s keyboard map. In this original study bar the melody changes every beat while the bass stays for four. Inspect separate hands, then both only when comfortable. These cells explain the timing relationship, not physical touch.',
            'Dersteki tuş haritasıyla sol Do3 ve sağ Do4–Sol4 bul. Bu özgün etüt ölçüsünde melodi her vuruş değişir, bas dört vuruş kalır. Önce elleri ayrı incele, sonra yalnız rahatsa birlikte dene. Hücreler zaman ilişkisini açıklar, fiziksel tuşeyi değil.',
          ),
          recovery: const GuitarText(
            'If the bass releases with the melody, use lesson 11’s smaller task: hold left C3 through four counts while speaking the right-hand rhythm; do not strike the bass again. Then, only if comfortable, return to both hands and add C4 D4 E4 G4 in that same bar. Remember your chosen comparison count before changing hands; keep the same chosen tempo when comparing the original two-hand task. If uncertain, inspect one count; if you stopped, rest first.',
            'Bas melodiyle bırakılıyorsa ders 11’in küçük görevini kullan: sağın ritmini söylerken sol Do3’ü dört sayım tut; basa yeniden basma. Sonra yalnız rahatsa iki ele dönüp aynı ölçüde Do4 Re4 Mi4 Sol4 ekle. El değiştirmeden seçtiğin karşılaştırma sayımını aklında tut; özgün iki el görevini karşılaştırırken aynı seçilen tempoyu koru. Emin değilsen tek sayımı incele; durduysan önce dinlen.',
          ),
          observationPrompt: const GuitarText(
            'At which count, if any, did the left-hand held note end early or restart while the melody moved? Note one location; uncertainty is valid. For a separate-hand attempt, describe that hand only.',
            'Varsa hangi sayımda melodi ilerlerken solun tutulan notası erken bitti veya yeniden başladı? Tek konum belirt; belirsizlik geçerlidir. Tek el denemesinde yalnız o eli anlat.',
          ),
          diagram: _grid,
          retryChoices: _choices(context),
        ),
      ],
    ),
  );
}
