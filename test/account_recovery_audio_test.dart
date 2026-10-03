import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';

import 'support/fake_practice_audio_port.dart';

void main() {
  test(
    'same-user recovery retires audio before a frame and needs a new route',
    () async {
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final recovery = ValueNotifier(false);
      final port = FakePracticeAudioPort();
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        passwordRecovery: recovery,
        lease: PracticeAudioLease(port: port),
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final observer = PracticeAudioRouteObserver(owner);
      final oldRoute = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );
      owner.attachNavigator(observer);
      observer.didPush(oldRoute, null);
      await Future<void>.delayed(Duration.zero);
      final grant = owner.grantFor(oldRoute)!;

      recovery.value = true;
      expect(user.value, 'A');
      expect(phase.value, MotionIdentityPhase.verified);
      expect(owner.grantFor(oldRoute), isNull);
      expect(
        (await owner.acquire(grant, PracticeAudioSide.input)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      recovery.value = false;
      observer.didPush(oldRoute, null);
      expect(owner.grantFor(oldRoute), isNull);

      final newObserver = PracticeAudioRouteObserver(owner);
      final newRoute = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );
      owner.attachNavigator(newObserver);
      newObserver.didPush(newRoute, null);
      await Future<void>.delayed(Duration.zero);
      expect(owner.grantFor(newRoute), isNotNull);
      expect(port.opens, isEmpty);
      owner.dispose();
      await owner.lastFenceForTest;
      user.dispose();
      phase.dispose();
      recovery.dispose();
    },
  );

  test('cold recovery denies audio even with a verified identity', () async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final recovery = ValueNotifier(true);
    final port = FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      passwordRecovery: recovery,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await Future<void>.delayed(Duration.zero);
    expect(owner.grantFor(route), isNull);
    expect(port.opens, isEmpty);
    owner.dispose();
    await owner.lastFenceForTest;
    user.dispose();
    phase.dispose();
    recovery.dispose();
  });

  test(
    'a native open finishing after recovery is closed and cannot attach',
    () async {
      final opening = Completer<void>();
      final closing = Completer<void>();
      final port = FakePracticeAudioPort();
      port.start = (_) => opening.future;
      port.stop = () => closing.future;
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final recovery = ValueNotifier(false);
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        passwordRecovery: recovery,
        lease: PracticeAudioLease(port: port),
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final observer = PracticeAudioRouteObserver(owner);
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(observer);
      observer.didPush(route, null);
      await Future<void>.delayed(Duration.zero);
      final starting = owner.acquire(
        owner.grantFor(route)!,
        PracticeAudioSide.input,
      );
      await Future<void>.delayed(Duration.zero);
      expect(port.opens, [PracticeAudioSide.input]);

      recovery.value = true;
      opening.complete();
      await Future<void>.delayed(Duration.zero);
      expect(port.closeCalls, 1);
      closing.complete();
      expect((await starting).status, AudioRouteAcquireStatus.staleGrant);
      expect(owner.grantFor(route), isNull);
      owner.dispose();
      await owner.lastFenceForTest;
      user.dispose();
      phase.dispose();
      recovery.dispose();
    },
  );
}
