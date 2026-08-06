import 'package:motion_core/motion_core.dart' as core;
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:test/test.dart';

/// 33 landmarkın tamamını görünmez doldurur, sonra istenenleri ezer —
/// trunk_tilt yalnız gövdeye (omuz+kalça) bakar, geri kalanı testi
/// etkilemez ama `core.PoseFrame` ctor'u tam 33 ister.
core.PoseFrame _frame(Map<int, core.PoseLandmark> overrides, {int tUs = 0}) {
  final List<core.PoseLandmark> lm = List<core.PoseLandmark>.generate(
    core.Lm.count,
    (int i) => overrides[i] ?? const core.PoseLandmark.invisible(),
  );
  return core.PoseFrame(tUs: tUs, landmarks: lm, modelVersion: 'test');
}

const core.FrameSize _size = core.FrameSize(1920, 1080); // gerçek kamera 16:9

void main() {
  group('CameraPostureAdapter — trunk_tilt (motion_core StandardJoints)', () {
    test('dik gövde (omuz tam kalçanın üstünde) ~0° döner', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
      });
      final double? deg = a.trunkTiltDeg(f, _size);
      expect(deg, isNotNull);
      expect(deg!.abs(), lessThan(1.0),
          reason: 'omuz-orta-nokta kalça-orta-noktanın tam üstünde — eğim '
              'sıfıra yakın olmalı, ölçüldü: $deg°');
    });

    test('öne eğik gövde (omuz kalçadan yatay kayık) belirgin ve dikten '
        'BÜYÜK bir açı döner', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame upright = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
      });
      final core.PoseFrame tilted = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.65, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
      });
      final double uprightDeg = a.trunkTiltDeg(upright, _size)!.abs();
      final double tiltedDeg = a.trunkTiltDeg(tilted, _size)!.abs();
      expect(tiltedDeg, greaterThan(uprightDeg + 5),
          reason: 'omuz-orta-noktası kalçadan yatay kaydırıldı ama ölçülen '
              'eğim dikten belirgin şekilde büyümedi (dik: $uprightDeg°, '
              'eğik: $tiltedDeg°)');
    });

    test('gövde landmarkları düşük-güvende: NULL döner (uydurma sayı YOK)',
        () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        // Sağ kalça görünmüyor (vis 0.1 < torsoThreshold 0.6).
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.1),
      });
      expect(a.trunkTiltDeg(f, _size), isNull,
          reason: 'güven kapısı sağ kalçayı reddetmeliydi — reddetmedi, '
              'düşük-güvenli landmarktan sayı üretiliyor');
    });

    test('kol/bacak landmarkları görünmese de gövde-yalnız ölçüm etkilenmez',
        () {
      // trunk_tilt yalnız LmRegion.torso'ya bakar (M-F-30 kapsam kararı) —
      // Ostinato kol/bacak hiç ölçmüyor, güven kapısı onları ZORUNLU saymaz.
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
        // Kollar/bacaklar tamamen görünmez (varsayılan .invisible()).
      });
      expect(a.trunkTiltDeg(f, _size), isNotNull,
          reason: 'kol/bacak görünmezliği gövde-yalnız ölçümü YANLIŞLIKLA '
              'reddetti — kapsam M-F-30 ile tutarsız');
    });

    test('reset() ölçek EMA\'sını sıfırlar — yeni oturum eskisinin '
        'kalıntısını taşımaz', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
      });
      a.trunkTiltDeg(f, _size); // ölçeği bir kez ısıtır
      a.reset();
      // reset sonrası ilk kare yine judgeable olmalı (istisna atmamalı).
      expect(a.trunkTiltDeg(f, _size), isNotNull);
    });
  });

  group('frameQuality — Kurulum Kontrolü kadraj/ışık ayrımı', () {
    test('kalça kadraj dışına çıkınca outOfFrame döner', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        // Kalça x=1.3 — izotropik genişlik (aspect≈1.78) içinde ama
        // frameMargin (.02) dışında değil; asıl dışarı taşımak için y kullan.
        core.Lm.leftHip: const core.PoseLandmark(0.45, 1.3, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 1.3, 0, 0.9),
      });
      final core.FrameQuality q = a.frameQuality(f, _size);
      expect(q.judgeable, isFalse);
      expect(q.issue, core.QualityIssue.outOfFrame,
          reason: 'Kurulum Kontrolü bunu "kadraj hatası" diye göstermeli');
    });

    test('gövde düşük güvende (karanlık) iken torsoUnreliable döner', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.35),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.35),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.35),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.35),
      });
      final core.FrameQuality q = a.frameQuality(f, _size);
      expect(q.judgeable, isFalse);
      expect(q.issue, core.QualityIssue.torsoUnreliable,
          reason: 'Kurulum Kontrolü bunu "ışık yetersiz" diye göstermeli');
    });

    test('kadraj+ışık iyiyken judgeable=true (kapı geçer)', () {
      final CameraPostureAdapter a = CameraPostureAdapter();
      final core.PoseFrame f = _frame(<int, core.PoseLandmark>{
        core.Lm.leftShoulder: const core.PoseLandmark(0.45, 0.3, 0, 0.9),
        core.Lm.rightShoulder: const core.PoseLandmark(0.55, 0.3, 0, 0.9),
        core.Lm.leftHip: const core.PoseLandmark(0.45, 0.6, 0, 0.9),
        core.Lm.rightHip: const core.PoseLandmark(0.55, 0.6, 0, 0.9),
      });
      expect(a.frameQuality(f, _size).judgeable, isTrue);
    });
  });
}
