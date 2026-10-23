import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';

import 'support/fake_practice_audio_port.dart';
import 'support/localized_widget_ready.dart';

void main() {
  setUpAll(prepareRootTranslations);
  test('retirement epoch invalidates audio without an identity value change', (
  ) async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final boundary = ValueNotifier<int>(0);
    final port = FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      identityBoundary: boundary,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    addTearDown(() async {
      owner.dispose();
      await owner.lastFenceForTest;
      boundary.dispose();
      phase.dispose();
      user.dispose();
    });
    final observer = PracticeAudioRouteObserver(owner);
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await owner.lastFenceForTest;
    final grant = owner.grantFor(route)!;
    ++boundary.value;
    expect(user.value, 'A');
    expect(phase.value, MotionIdentityPhase.verified);
    expect(owner.grantFor(route), isNull);
    expect(
      (await owner.acquire(grant, PracticeAudioSide.input)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    expect(port.opens, isEmpty);
  });

  test('late audio open cannot attach after retirement-only boundary', () async {
    final opening = Completer<void>();
    final closing = Completer<void>();
    final port = FakePracticeAudioPort();
    port.start = (_) => opening.future;
    port.stop = () => closing.future;
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final boundary = ValueNotifier<int>(0);
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      identityBoundary: boundary,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await owner.lastFenceForTest;
    final starting = owner.acquire(
      owner.grantFor(route)!,
      PracticeAudioSide.input,
    );
    await Future<void>.delayed(Duration.zero);
    expect(port.opens, [PracticeAudioSide.input]);
    try {
      ++boundary.value;
      opening.complete();
      await Future<void>.delayed(Duration.zero);
      expect(port.closeCalls, 1);
      closing.complete();
      expect((await starting).status, AudioRouteAcquireStatus.staleGrant);
      expect(owner.grantFor(route), isNull);
    } finally {
      if (!opening.isCompleted) opening.complete();
      if (!closing.isCompleted) closing.complete();
      await starting;
      owner.dispose();
      await owner.lastFenceForTest;
      boundary.dispose();
      phase.dispose();
      user.dispose();
    }
  });

  testWidgets('root removes the shared boundary before disposing its binding', (
    tester,
  ) async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final boundary = _TrackedBoundary();
    final lease = PracticeAudioLease(port: FakePracticeAudioPort());
    late PracticeAudioRootOwner owner;
    var disposals = 0;
    Widget root() => OstinatoAudioRoot(
      userId: user,
      phase: phase,
      identityBoundary: boundary,
      resourceAdmission: boundary,
      testLease: lease,
      onTestOwnerCreated: (value) => owner = value,
      disposeAccountBinding: () {
        expect(boundary.listeners, 0);
        ++disposals;
      },
      child: const SizedBox(),
    );
    await tester.pumpWidget(root());
    expect(boundary.listeners, 1);
    await tester.pumpWidget(root());
    expect(boundary.listeners, 1);
    expect(disposals, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => await owner.lastFenceForTest);
    expect(disposals, 1);
    await tester.pumpWidget(const SizedBox());
    expect(disposals, 1);
    boundary.dispose();
    phase.dispose();
    user.dispose();
  });
}

final class _TrackedBoundary extends ValueNotifier<bool> {
  _TrackedBoundary() : super(true);

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    ++listeners;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    --listeners;
    super.removeListener(listener);
  }
}
