import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/main.dart';
import 'support/fake_practice_audio_port.dart';

typedef _Port = FakePracticeAudioPort;

Route<dynamic> _route(String name) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => const SizedBox(),
);

Future<void> _settleFence() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'A → null → A synchronously retires the old Navigator and grant',
    () async {
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final port = _Port();
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        lease: PracticeAudioLease(port: port),
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final oldObserver = PracticeAudioRouteObserver(owner);
      final oldRoute = _route('old');
      owner.attachNavigator(oldObserver);
      oldObserver.didPush(oldRoute, null);
      await _settleFence();
      final oldGrant = owner.grantFor(oldRoute)!;

      user.value = null;
      expect(owner.grantFor(oldRoute), isNull); // no pump or native await
      user.value = 'A';
      expect(owner.grantFor(oldRoute), isNull);
      expect(
        (await owner.acquire(oldGrant, PracticeAudioSide.input)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      oldObserver.didPush(_route('late-old'), oldRoute);
      expect(owner.grantFor(oldRoute), isNull);

      final freshObserver = PracticeAudioRouteObserver(owner);
      final freshRoute = _route('fresh');
      owner.attachNavigator(freshObserver);
      freshObserver.didPush(freshRoute, null);
      await _settleFence();
      expect(owner.grantFor(freshRoute), isNotNull);
      expect(port.opens, isEmpty);
      owner.dispose();
      await owner.lastFenceForTest;
      expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
      user.dispose();
      phase.dispose();
    },
  );

  test(
    'A → B and verified → verifying/unavailable fence before pump',
    () async {
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final port = _Port();
      final lease = PracticeAudioLease(port: port);
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        lease: lease,
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final observer = PracticeAudioRouteObserver(owner);
      final route = _route('A');
      owner.attachNavigator(observer);
      observer.didPush(route, null);
      await _settleFence();
      final grant = owner.grantFor(route)!;

      user.value = 'B';
      expect(owner.grantFor(route), isNull);
      expect(
        lease.lastInvalidationReason,
        PracticeAudioInvalidationReason.accountChange,
      );
      expect(
        (await owner.acquire(grant, PracticeAudioSide.output)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      final observerB = PracticeAudioRouteObserver(owner);
      final routeB = _route('B');
      owner.attachNavigator(observerB);
      observerB.didPush(routeB, null);
      await _settleFence();
      final grantB = owner.grantFor(routeB)!;

      phase.value = MotionIdentityPhase.verifying;
      expect(owner.grantFor(routeB), isNull);
      expect(
        (await owner.acquire(grantB, PracticeAudioSide.output)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      phase.value = MotionIdentityPhase.unavailable;
      expect(owner.grantFor(routeB), isNull);
      expect(port.opens, isEmpty);
      owner.dispose();
      await owner.lastFenceForTest;
      expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
      user.dispose();
      phase.dispose();
    },
  );

  test('push and pop invalidate the previous visible route grant', () async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      lease: PracticeAudioLease(port: _Port()),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final home = _route('home');
    final lesson = _route('lesson');
    owner.attachNavigator(observer);
    observer.didPush(home, null);
    await _settleFence();
    final homeGrant = owner.grantFor(home)!;

    observer.didPush(lesson, home);
    expect(owner.grantFor(home), isNull);
    expect(
      (await owner.acquire(homeGrant, PracticeAudioSide.input)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    await _settleFence();
    final lessonGrant = owner.grantFor(lesson)!;
    observer.didPop(lesson, home);
    expect(owner.grantFor(lesson), isNull);
    expect(
      (await owner.acquire(lessonGrant, PracticeAudioSide.output)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    await _settleFence();
    final freshHomeGrant = owner.grantFor(home)!; // a new explicit action only
    final replacement = _route('replacement');
    observer.didReplace(newRoute: replacement, oldRoute: home);
    expect(owner.grantFor(home), isNull);
    expect(
      (await owner.acquire(freshHomeGrant, PracticeAudioSide.input)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    await _settleFence();
    final replacementGrant = owner.grantFor(replacement)!;
    observer.didRemove(replacement, null);
    expect(owner.grantFor(replacement), isNull);
    expect(
      (await owner.acquire(replacementGrant, PracticeAudioSide.input)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    owner.dispose();
    await owner.lastFenceForTest;
    expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
    user.dispose();
    phase.dispose();
  });

  test('late native open cannot attach audio to a removed account', () async {
    final opened = Completer<void>();
    final closed = Completer<void>();
    final port = _Port()
      ..start = ((_) => opened.future)
      ..stop = (() => closed.future);
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = _route('A');
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await _settleFence();
    final grant = owner.grantFor(route)!;
    final starting = owner.acquire(
      grant,
      PracticeAudioSide.output,
      assetId: 'test-output',
    );
    await _settleFence();
    expect(port.opens, [PracticeAudioSide.output]);

    user.value = null;
    expect(owner.grantFor(route), isNull);
    opened.complete();
    await _settleFence();
    expect(port.closeCalls, 1);
    closed.complete();
    expect((await starting).status, AudioRouteAcquireStatus.staleGrant);
    expect(port.closeCalls, 1);
    await owner.lastFenceForTest;
    // The reserve reply raced the new native context. Even after hardware
    // closes, only an explicit all-clear recovery may remove that doubt.
    expect(owner.blocked, isTrue);
    expect(await owner.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    owner.dispose();
    await owner.lastFenceForTest;
    expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
    user.dispose();
    phase.dispose();
  });

  test(
    'inactive blocks new action; pause fences; resume never opens',
    () async {
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final port = _Port();
      final lease = PracticeAudioLease(port: port);
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        lease: lease,
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final observer = PracticeAudioRouteObserver(owner);
      final route = _route('lesson');
      owner.attachNavigator(observer);
      observer.didPush(route, null);
      await _settleFence();
      final beforeInactive = owner.grantFor(route)!;

      owner.lifecycleChanged(AppLifecycleState.inactive);
      expect(owner.grantFor(route), isNull);
      expect(
        lease.lastInvalidationReason,
        PracticeAudioInvalidationReason.routeChange,
      );
      owner.lifecycleChanged(AppLifecycleState.resumed);
      expect(
        (await owner.acquire(beforeInactive, PracticeAudioSide.input)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      expect(owner.grantFor(route), isNotNull);
      owner.lifecycleChanged(AppLifecycleState.paused);
      expect(owner.grantFor(route), isNull);
      expect(
        lease.lastInvalidationReason,
        PracticeAudioInvalidationReason.background,
      );
      owner.lifecycleChanged(AppLifecycleState.resumed);
      await _settleFence();
      expect(port.opens, isEmpty);
      expect(owner.grantFor(route), isNotNull);
      owner.dispose();
      await owner.lastFenceForTest;
      expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
      user.dispose();
      phase.dispose();
    },
  );

  test('old action cannot refresh across account, route, or resume', () async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final port = _Port();
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observerA = PracticeAudioRouteObserver(owner);
    final routeA = _route('A');
    owner.attachNavigator(observerA);
    observerA.didPush(routeA, null);
    await _settleFence();
    final oldAction = owner.grantFor(routeA)!;
    Future<AudioRouteAcquireStatus> staleCallback() async =>
        (await oldAction.acquire(PracticeAudioSide.input)).status;

    user.value = 'B';
    final observerB = PracticeAudioRouteObserver(owner);
    final routeB = _route('B');
    owner.attachNavigator(observerB);
    observerB.didPush(routeB, null);
    await _settleFence();
    expect(owner.grantFor(routeB), isNotNull);
    expect(await staleCallback(), AudioRouteAcquireStatus.staleGrant);

    final routeC = _route('C');
    observerB.didPush(routeC, routeB);
    await _settleFence();
    expect(owner.grantFor(routeC), isNotNull);
    expect(await staleCallback(), AudioRouteAcquireStatus.staleGrant);

    owner.lifecycleChanged(AppLifecycleState.paused);
    owner.lifecycleChanged(AppLifecycleState.resumed);
    await _settleFence();
    expect(owner.grantFor(routeC), isNotNull);
    expect(await staleCallback(), AudioRouteAcquireStatus.staleGrant);
    expect(port.opens, isEmpty);
    owner.dispose();
    await owner.lastFenceForTest;
    expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
    user.dispose();
    phase.dispose();
  });

  test('one route action cannot open both audio sides', () async {
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final port = _Port();
    final owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = _route('lesson');
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await _settleFence();
    final action = owner.grantFor(route)!;
    expect(
      (await action.acquire(
        PracticeAudioSide.output,
        assetId: 'test-output',
      )).status,
      AudioRouteAcquireStatus.acquired,
    );
    expect(
      (await action.acquire(PracticeAudioSide.input)).status,
      AudioRouteAcquireStatus.staleGrant,
    );
    expect(port.opens, [PracticeAudioSide.output]);
    owner.dispose();
    await owner.lastFenceForTest;
    expect(owner.leasePhase, PracticeAudioLeasePhase.idle);
    user.dispose();
    phase.dispose();
  });

  testWidgets('paused at root mount denies action until resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final user = ValueNotifier<String?>('A');
    final phase = ValueNotifier(MotionIdentityPhase.verified);
    final port = _Port();
    late PracticeAudioRootOwner owner;
    await tester.pumpWidget(
      OstinatoAudioRoot(
        userId: user,
        phase: phase,
        testLease: PracticeAudioLease(port: port),
        allowTestAcquisition: true,
        onTestOwnerCreated: (created) => owner = created,
        builder: (host) => host.wrap(
          builder: (observer) => MaterialApp(
            navigatorObservers: [observer],
            home: const Scaffold(body: Text('lesson')),
          ),
        ),
      ),
    );
    // The framework suppresses ordinary frames while paused. A forced test
    // frame mounts the root under the actual paused lifecycle value.
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    final route = owner.topRoute;
    expect(route, isNotNull);
    expect(owner.grantFor(route!), isNull);
    expect(port.opens, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.runAsync(_settleFence);
    expect(owner.grantFor(route), isNotNull);
    expect(port.opens, isEmpty);
    await tester.pumpWidget(const SizedBox());
    user.dispose();
    phase.dispose();
  });

  testWidgets(
    'real OstinatoApp account key receives a new observed Navigator',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final port = _Port();
      late PracticeAudioRootOwner owner;
      await tester.pumpWidget(
        OstinatoAudioRoot(
          userId: user,
          phase: phase,
          testLease: PracticeAudioLease(port: port),
          allowTestAcquisition: true,
          onTestOwnerCreated: (created) => owner = created,
          builder: (host) => OstinatoApp(
            audioNavigatorHost: host,
            store: InMemoryOnboardingStore(complete: true),
            accountConnection: AccountConnection(
              userId: user,
              pageBuilder: (_) => const Scaffold(body: Text('account')),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.byType(OstinatoHome), findsOneWidget);
      final oldRoute = owner.topRoute!;
      final oldGrant = owner.grantFor(oldRoute)!;
      final app = tester
          .element(find.byType(OstinatoHome))
          .findAncestorWidgetOfExactType<MaterialApp>()!;
      final spoofedRoute = _route('spoofed');
      app.navigatorObservers!.single.didPush(spoofedRoute, oldRoute);
      expect(owner.topRoute, same(oldRoute));
      expect(owner.grantFor(spoofedRoute), isNull);

      user.value = 'B';
      expect(owner.grantFor(oldRoute), isNull);
      expect(
        (await owner.acquire(oldGrant, PracticeAudioSide.output)).status,
        AudioRouteAcquireStatus.staleGrant,
      );
      await tester.pumpAndSettle();
      expect(owner.topRoute, isNot(same(oldRoute)));
      expect(owner.grantFor(owner.topRoute!), isNotNull);
      expect(port.opens, isEmpty);
      await tester.pumpWidget(const SizedBox());
      user.dispose();
      phase.dispose();
    },
  );

  testWidgets(
    'blocked recovery remains visible after identity child is removed',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final port = _Port()..clear = () async => false;
      final lease = PracticeAudioLease(
        port: port,
        operationTimeout: const Duration(milliseconds: 20),
      );
      late PracticeAudioRootOwner owner;
      Widget gateChild(PracticeAudioNavigatorHost host) =>
          ValueListenableBuilder<MotionIdentityPhase>(
            valueListenable: phase,
            builder: (context, value, _) {
              if (value != MotionIdentityPhase.verified) {
                return const MaterialApp(
                  home: Scaffold(body: Text('gate closed')),
                );
              }
              return host.wrap(
                builder: (observer) => MaterialApp(
                  navigatorObservers: [observer],
                  home: const Scaffold(body: Text('lesson')),
                ),
              );
            },
          );
      await tester.pumpWidget(
        OstinatoAudioRoot(
          userId: user,
          phase: phase,
          testLease: lease,
          allowTestAcquisition: true,
          onTestOwnerCreated: (created) => owner = created,
          builder: gateChild,
        ),
      );
      await tester.pump();
      // Idle native fencing now detects an uncleared legacy device before
      // a lesson can receive any acquisition grant.
      await tester.runAsync(_settleFence);
      await tester.pump();
      expect(owner.blocked, isTrue);
      expect(owner.blocked, isTrue);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ostinato-audio-root-recover')),
        findsOneWidget,
      );
      tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.pumpAndSettle();
      expect(
        find.text('Ses kaynağının kapandığı doğrulanamadı.'),
        findsOneWidget,
      );
      expect(find.text('Kapanmayı yeniden dene'), findsOneWidget);
      tester.binding.platformDispatcher.clearLocalesTestValue();
      await tester.pumpAndSettle();
      expect(find.text('Retry shutdown'), findsOneWidget);

      phase.value = MotionIdentityPhase.verifying;
      await tester.pump();
      expect(
        find.byKey(const Key('ostinato-audio-root-recover')),
        findsOneWidget,
      );
      expect(find.text('gate closed'), findsNothing);

      final pending = Completer<void>();
      port.stop = () => pending.future;
      await tester.tap(find.byKey(const Key('ostinato-audio-root-recover')));
      await tester.pump(const Duration(milliseconds: 25));
      await tester.pump();
      expect(port.closeCalls, 1);
      await tester.tap(find.byKey(const Key('ostinato-audio-root-recover')));
      await tester.pumpAndSettle();
      expect(owner.nativeReplyPending, isTrue);
      expect(find.textContaining('previous device reply'), findsOneWidget);
      expect(port.opens, isEmpty);

      pending.complete();
      port.stop = () async {};
      port.clear = () async => true;
      await tester.pump();
      await tester.tap(find.byKey(const Key('ostinato-audio-root-recover')));
      await tester.pump();
      await tester.pump();
      expect(find.text('gate closed'), findsOneWidget);
      expect(port.opens, isEmpty); // recovery did not start either side
      await tester.pumpWidget(const SizedBox());
      user.dispose();
      phase.dispose();
    },
  );
}
