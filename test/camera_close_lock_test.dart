import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/camera_session.dart';

/// Kamera kapanış kilidi — O-076 (Choreia C-195 aktarımı).
///
/// ⚠️ Bu test "N'inci kez" eksenini kuruyor: 152 testin hepsi *"ekran
/// çalışıyor mu"* diye soruyordu ve cevap İLK seferinde evetti. Yarış ancak
/// İKİNCİ açılışta görünür.
void main() {
  test('uçuşta kapanış varsa START onu BEKLER (sıra korunur)', () async {
    final List<String> order = <String>[];

    // Kapanışı simüle et: bitmesi zaman alıyor.
    noteClosing(Future<void>.delayed(const Duration(milliseconds: 60), () {
      order.add('stop-bitti');
    }));

    await awaitPendingClose();
    order.add('start-basladi');

    expect(order, <String>['stop-bitti', 'start-basladi'],
        reason: 'start, uçuştaki stop bitmeden başladı — cihazda tek kamera '
            'var, bu `already-running` demektir');
  });

  test('POZİTİF KONTROL: uçuşta kapanış YOKSA bekleme SIFIR', () async {
    final Stopwatch sw = Stopwatch()..start();
    await awaitPendingClose();
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(20),
        reason: 'N=1 yolunda kilit maliyet eklememeli');
  });
}
