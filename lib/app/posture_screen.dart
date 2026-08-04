import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import 'content.dart';
import 'cue_text.dart';

/// Canlı postür yüzeyi — bant + gözlem işareti.
///
/// Ekranın taşıdığı TEK iddia şu: "ölçtüğümüz N eğitmen şu aralıkta duruyor,
/// sen şuradasın." Puan yok, yıldız yok, yüzde yok (K8/M-F-04).
///
/// Bant çizimi bilerek böyle: doğru duruş bir NOKTA değil BANT. 3° eğik olan
/// bir kullanıcı bunu "hata" sanıp düzeltmeye çalışırsa, ölçtüğümüz
/// eğitmenlerin yarısından uzaklaşır — bandı göstermek o yanlış anlamayı
/// baştan keser.
class PostureScreen extends StatefulWidget {
  const PostureScreen({
    super.key,
    required this.discipline,
    required this.contract,
    required this.cueText,
    required this.source,
    required this.sourceLabel,
  });

  final Discipline discipline;
  final PostureContract contract;
  final CueTextResolver cueText;
  final PoseSource source;

  /// Kaynağın NE OLDUĞU ekranda yazılı durur. Sahte kaynakla akan bir yüzeyi
  /// "kamera çalışıyor" diye göstermek, bu turun tam olarak kaçındığı şey.
  final String sourceLabel;

  @override
  State<PostureScreen> createState() => _PostureScreenState();
}

class _PostureScreenState extends State<PostureScreen> {
  late final PostureEvaluator _evaluator =
      PostureEvaluator(contract: widget.contract);
  SurfaceState _state = const Starting();

  /// İşaretin YÜKÜ tutulur, METNİ değil — ve her karede yeniden çözülür.
  ///
  /// İlk sürüm çözülmüş METNİ saklıyordu ve sim ekranında kusur şöyle
  /// göründü: başlıkta "You: 18.0°" yazarken işaret "You are at 20° right
  /// now" diyordu. İşaret bir kare önceki ölçümde donmuştu; ekranda
  /// birbiriyle ÇELİŞEN iki sayı vardı. Cümlenin gücü, referansı ve ANLIK
  /// ölçümü yan yana koymasından geliyor — biri bayatlarsa cümle kendi
  /// iddiasını çürütür (vitrin sınıfı, O-029'un canlı hâli).
  ObservationCue? _cue;

  @override
  void initState() {
    super.initState();
    widget.source.frames.listen((PoseFrame f) {
      final SurfaceState s = _evaluator.evaluate(f);
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s is Measuring) {
          if (s.cue != null) {
            _cue = s.cue; // yeni işaret
          } else if (s.inBand) {
            _cue = null; // banda dönüldü → işaret SUSAR (şart 6)
          }
        } else {
          _cue = null; // ölçüm yok → hakkında konuşulacak bir şey de yok
        }
      });
    });
    widget.source.start();
  }

  @override
  void dispose() {
    widget.source.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.discipline.displayName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SourceBanner(label: widget.sourceLabel),
            const SizedBox(height: 16),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    // Her hâl AYRI ekran. `switch` üzerinde exhaustiveness var: yeni bir hâl
    // eklenirse derleyici burayı kırar — sessizce "bir şeyler ters gitti"ye
    // düşen bir yüzey doğamaz.
    return switch (_state) {
      Starting() => const _Notice(
          key: Key('state-starting'),
          title: 'Getting the camera ready',
          body: 'This takes a moment. Nothing is being recorded.'),
      PermissionDenied() => const _Notice(
          key: Key('state-permission-denied'),
          title: 'Camera access is off',
          body: 'Ostinato needs the camera to see how you sit. Video never '
              'leaves your phone. You can turn access on in Settings.'),
      CameraUnavailable(:final String reason) => _Notice(
          key: const Key('state-camera-unavailable'),
          title: 'The camera did not open',
          body: 'We could not start a camera session ($reason). Nothing was '
              'measured, so nothing is shown.'),
      NoPersonVisible() => const _Notice(
          key: Key('state-no-person'),
          title: 'We cannot see you yet',
          body: 'Step back until your head and hips are both in frame. '
              'This is not an error — we simply have nothing to measure.'),
      Measuring(:final double trunkTiltDeg, :final bool inBand) => _measuring(
          trunkTiltDeg, inBand),
    };
  }

  Widget _measuring(double tilt, bool inBand) {
    final double? pos = _evaluator.positionInTeacherBand(tilt);
    return Column(
      key: const Key('state-measuring'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('How ${widget.contract.teacherCount} '
            '${widget.contract.sourceClass} sit',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${widget.contract.bandLowDeg}° to ${widget.contract.bandHighDeg}° '
          'from upright — measured, not chosen. Correct posture is a band, '
          'not a point.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _BandStrip(
          low: widget.contract.bandLowDeg,
          high: widget.contract.bandHighDeg,
          tolerance: widget.contract.scoringToleranceDeg,
          you: tilt.abs(),
          positionInBand: pos,
        ),
        const SizedBox(height: 16),
        Text('You: ${tilt.abs().toStringAsFixed(1)}° from upright',
            key: const Key('you-value'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        // NOT A SCORE. Bant içinde/dışında bir DURUM ifadesi.
        Text(inBand ? 'Within the range we measure against'
                    : 'Outside the range we measure against',
            key: const Key('band-state')),
        if (_cue != null) ...<Widget>[
          const SizedBox(height: 20),
          Container(
            key: const Key('observation-cue'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            // Yük saklanır, metin HER karede güncel ölçümle yeniden
            // çözülür: cümledeki sayı başlıktaki sayıyla aynı olmak zorunda.
            child: Text(widget.cueText.resolve(ObservationCue(
              templateId: _cue!.templateId,
              teacherCount: _cue!.teacherCount,
              sourceClass: _cue!.sourceClass,
              thresholdDeg: _cue!.thresholdDeg,
              measuredDeg: tilt.abs(),
            ))),
          ),
        ],
      ],
    );
  }
}

/// Kaynağın adı — sahte mi gerçek mi, ekranda yazılı.
class _SourceBanner extends StatelessWidget {
  const _SourceBanner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('source-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      );
}

/// Eğitmen bandı + skorlama toleransı + kullanıcının yeri.
/// Sayı YOK: konum çizilir, puanlanmaz.
class _BandStrip extends StatelessWidget {
  const _BandStrip({
    required this.low,
    required this.high,
    required this.tolerance,
    required this.you,
    required this.positionInBand,
  });

  final double low;
  final double high;
  final double tolerance;
  final double you;
  final double? positionInBand;

  @override
  Widget build(BuildContext context) {
    const double maxDeg = 20; // çizim ölçeği; hüküm değil
    final ColorScheme cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints c) {
      double x(double deg) => (deg.clamp(0, maxDeg) / maxDeg) * c.maxWidth;
      return SizedBox(
        height: 44,
        child: Stack(children: <Widget>[
          Positioned(left: 0, right: 0, top: 18,
              child: Container(height: 8, color: cs.surfaceContainerHighest)),
          // Skorlama toleransı (0..8°)
          Positioned(left: 0, top: 18,
              child: Container(width: x(tolerance), height: 8,
                  color: cs.secondaryContainer)),
          // Eğitmenlerin GERÇEK aralığı
          Positioned(left: x(low), top: 14,
              child: Container(width: (x(high) - x(low)).clamp(2, double.infinity),
                  height: 16, color: cs.primary)),
          // Sen
          Positioned(left: (x(you) - 1).clamp(0, c.maxWidth - 2), top: 6,
              child: Container(key: const Key('you-marker'),
                  width: 2, height: 32, color: cs.error)),
        ]),
      );
    });
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ],
      );
}
