import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/camera_session.dart';

/// Kamera kapanış kilidi — O-076 (Choreia C-195 aktarımı).
///
/// ⚠️ Bu test "N'inci kez" eksenini kuruyor: 152 testin hepsi *"ekran
/// çalışıyor mu"* diye soruyordu ve cevap İLK seferinde evetti. Yarış ancak
/// İKİNCİ açılışta görünür.
void main() {
  setUp(resetCameraSessionForTesting);
  tearDown(resetCameraSessionForTesting);
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

  test('older close completion cannot erase a newer pending close barrier', () async {
    final Completer<void> first = Completer<void>();
    final Completer<void> newer = Completer<void>();
    final List<Future<void>> waiters = <Future<void>>[];
    try {
      noteClosing(first.future);
      var admitted = false;
      final Future<void> waiting = awaitPendingClose().then((_) { admitted = true; });
      waiters.add(waiting);
      noteClosing(newer.future);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(admitted, isFalse, reason: 'successor must await every recorded closure');
      var secondAdmitted = false;
      final Future<void> second = awaitPendingClose().then((_) { secondAdmitted = true; });
      waiters.add(second);
      await Future<void>.delayed(Duration.zero);
      expect(secondAdmitted, isFalse, reason: 'old completion erased the newer barrier');
      newer.complete();
      await waiting;
      await second;
      expect(admitted && secondAdmitted, isTrue);
    } finally {
      if (!first.isCompleted) first.complete();
      if (!newer.isCompleted) newer.complete();
      await Future.wait(waiters);
    }
  });
}
