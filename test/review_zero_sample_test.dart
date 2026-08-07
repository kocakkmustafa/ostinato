import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/screens/review_screen.dart';

/// Sıfır-ölçüm hâli — O-070 (render probu turu, koordinatör kova ①).
void main() {
  test('oran YOK, sıfır DEĞİL — "bilinmiyor ↔ sıfır" ayrımı', () {
    const SessionSummary none = SessionSummary(
        elapsedSeconds: 30, sampleCount: 0, outCount: 0, history: <double>[]);
    expect(none.insideShare, isNull,
        reason: 'sıfır ölçümün oranı 0 da değil 1 de değil — YOK');
    expect(none.nothingReadable, isTrue);
  });

  test('okunabilir kare VARSA oran gerçekten hesaplanıyor (pozitif ikiz)', () {
    const SessionSummary some = SessionSummary(
        elapsedSeconds: 30, sampleCount: 100, outCount: 10,
        history: <double>[3, 3, 3]);
    expect(some.insideShare, closeTo(0.9, 1e-9));
    expect(some.verdict, 'Steady.');
    expect(some.nothingReadable, isFalse);
  });

  test('HİÇ ölçüm okunamamışken hüküm verilmemeli', () {
    const SessionSummary none = SessionSummary(
        elapsedSeconds: 30, sampleCount: 0, outCount: 0, history: <double>[]);
    expect(none.verdict, isNot('Steady.'),
        reason: 'sıfır ölçümle OLUMLU hüküm — kamera hiç okunamamışken '
            '"Steady." demek, ölçmediğimiz şeye not vermektir');
  });
}
