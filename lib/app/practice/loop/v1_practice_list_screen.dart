import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../curriculum/v1_lesson.dart';
import '../../account_connection.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../setup/latency_calibration.dart';
import '../setup/setup_profile_store.dart';
import '../setup/setup_wizard_screen.dart';
import 'practice_loop_screen.dart';
import 'practice_outcome.dart';
import 'practice_progress_store.dart';
import 'v1_practice_catalog.dart';

/// F2.5 entry: measured-practice lessons in course order. The first is open;
/// each next one opens after a measured pass of the one before.
class V1PracticeListScreen extends StatefulWidget {
  const V1PracticeListScreen({
    super.key,
    this.catalog,
    this.progressFactory,
    this.practiceScreenBuilder,
    this.onSessionFinished,
    this.setupStore,
    this.openSetup,
    this.startNext = false,
  });

  /// Opens the first open lesson not yet passed as soon as the list loads
  /// ("Start next lesson"); the list stays underneath for the way back.
  final bool startNext;

  /// F4.2 setup results; defaults to the device store.
  final SetupProfileStore? setupStore;

  /// Opens the setup wizard; tests replace it.
  final Future<void> Function(BuildContext context)? openSetup;

  /// Forwarded to every practice screen (retention wiring, PR #12).
  final void Function(PracticeSessionFinished event)? onSessionFinished;

  /// Tests pass a catalog; production loads the bundled lessons.
  final Future<V1PracticeCatalog>? catalog;
  final V1PracticeProgress Function(String? accountId)? progressFactory;
  final Widget Function(
    V1Lesson lesson,
    V1PracticeProgress progress,
    bool hasNext,
  )?
  practiceScreenBuilder;

  @override
  State<V1PracticeListScreen> createState() => _V1PracticeListScreenState();
}

class _V1PracticeListScreenState extends State<V1PracticeListScreen> {
  late Future<V1PracticeCatalog> _catalog =
      widget.catalog ?? V1PracticeCatalog.load();
  V1PracticeProgress? _progress;
  String? _accountId;
  Future<Map<String, V1PracticeRecord>>? _records;
  late final SetupProfileStore _setup =
      widget.setupStore ?? FileSetupProfileStore.device;
  late Future<SetupProfile> _profile = _loadProfile();

  Future<SetupProfile> _loadProfile() =>
      _setup.load().catchError((Object _) => SetupProfile.empty);

  Future<void> _openSetup() async {
    final open = widget.openSetup;
    if (open != null) {
      await open(context);
    } else {
      await openSetupWizard(context, store: _setup);
    }
    if (!mounted) return;
    final next = _loadProfile();
    setState(() {
      _profile = next;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_progress == null || id != _accountId) {
      _accountId = id;
      _progress =
          widget.progressFactory?.call(id) ??
          V1PracticeProgressStore(accountUserId: id);
      _records = _progress!.load();
      if (widget.startNext && !_startedNext) {
        _startedNext = true;
        unawaited(_openNext());
      }
    }
  }

  bool _startedNext = false;

  Future<void> _openNext() async {
    final V1PracticeCatalog catalog;
    final Map<String, V1PracticeRecord> records;
    try {
      catalog = await _catalog;
      records = await _records!;
    } on Object {
      return; // The list shows the error and a retry.
    }
    if (!mounted) return;
    final open = unlockedLessons(catalog.orderedIds, records);
    for (final l in catalog.lessons) {
      if (open.contains(l.id) && !(records[l.id]?.passed ?? false)) {
        await _open(catalog, l);
        return;
      }
    }
  }

  void _reload() {
    final next = _progress!.load();
    setState(() {
      _records = next;
    });
  }

  Future<void> _open(V1PracticeCatalog catalog, V1Lesson lesson) async {
    // "Choose a lesson → setup → play": the wizard comes first until it has
    // been gone through once (every step done or skipped).
    final visited = (await _profile).visited;
    if (!mounted) return;
    if (!visited) {
      await _openSetup();
      if (!mounted) return;
    }
    final progress = _progress!;
    final next = catalog.nextAfter(lesson.id);
    final exit = await Navigator.of(context).push<PracticeExit>(
      MaterialPageRoute(
        builder: (_) =>
            widget.practiceScreenBuilder?.call(
              lesson,
              progress,
              next != null,
            ) ??
            PracticeLoopScreen(
              lesson: lesson,
              progress: progress,
              hasNextLesson: next != null,
              onSessionFinished: widget.onSessionFinished,
              setupStore: _setup,
            ),
      ),
    );
    if (!mounted) return;
    _reload();
    final profile = _loadProfile();
    setState(() {
      _profile = profile;
    });
    if (exit == PracticeExit.openNextLesson && next != null) {
      final records = await _records!;
      if (!mounted) return;
      if (unlockedLessons(catalog.orderedIds, records).contains(next.id)) {
        unawaited(_open(catalog, next));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: FutureBuilder<V1PracticeCatalog>(
          future: _catalog,
          builder: (context, catalogSnap) {
            if (catalogSnap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localized(
                        context,
                        'Lessons could not be loaded.',
                        'Dersler yüklenemedi.',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        final next = V1PracticeCatalog.load();
                        setState(() {
                          _catalog = next;
                        });
                      },
                      child: Text(localized(context, 'Retry', 'Yeniden dene')),
                    ),
                  ],
                ),
              );
            }
            if (!catalogSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final catalog = catalogSnap.data!;
            return FutureBuilder<Map<String, V1PracticeRecord>>(
              future: _records,
              builder: (context, recordSnap) {
                if (recordSnap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = recordSnap.data ?? const {};
                final open = unlockedLessons(catalog.orderedIds, records);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          icon: '‹',
                          semanticLabel: localized(context, 'Back', 'Geri'),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            localized(
                              context,
                              'Measured practice',
                              'Ölçülü pratik',
                            ),
                            style: hankenText(
                              size: 20,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localized(
                        context,
                        'Play with the click and the moving TAB. Each note gets one of three marks: correct, different note or couldn’t hear. Passing the gate opens the next lesson.',
                        'Klik ve akan tab ile çal. Her nota üç işaretten birini alır: doğru, farklı nota ya da duyamadım. Geçiş kapısını geçmek sıradaki dersi açar.',
                      ),
                      style: hankenText(size: 13, height: 1.45),
                    ),
                    if (recordSnap.hasError)
                      Text(
                        localized(
                          context,
                          'Progress unknown',
                          'İlerleme bilinmiyor',
                        ),
                        style: monoText(color: palette.warnInk),
                      ),
                    const SizedBox(height: 12),
                    _setupCard(context),
                    const SizedBox(height: 8),
                    if (catalog.lessons.isEmpty)
                      Text(
                        localized(
                          context,
                          'No measured lessons in this build.',
                          'Bu sürümde ölçülü ders yok.',
                        ),
                      ),
                    for (final lesson in catalog.lessons)
                      _tile(
                        context,
                        catalog,
                        lesson,
                        records[lesson.id],
                        open.contains(lesson.id),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _setupCard(BuildContext context) => FutureBuilder<SetupProfile>(
    future: _profile,
    builder: (context, snap) {
      final p = snap.data;
      final latency = p?.latencyFor(p.lastRoute);
      final line = p == null || !p.visited
          ? localized(
              context,
              'Placement, room, latency and tuning — about two minutes.',
              'Yerleşim, oda, gecikme ve akort — yaklaşık iki dakika.',
            )
          : latency == null
          ? localized(
              context,
              'Latency not measured on this output: timing stays hidden.',
              'Bu çıkışta gecikme ölçülmedi: zamanlama gizli kalır.',
            )
          : localized(
              context,
              'Latency {v0} ms ({v1}); timing is shown.',
              'Gecikme {v0} ms ({v1}); zamanlama gösterilir.',
              values: {
                'v0': (latency.roundTripUs / 1000).round(),
                'v1': switch (p.lastRoute!) {
                  CalibrationRoute.speaker => localized(
                    context,
                    'speaker',
                    'hoparlör',
                  ),
                  CalibrationRoute.wiredHeadset => localized(
                    context,
                    'wired headphones',
                    'kablolu kulaklık',
                  ),
                  CalibrationRoute.bluetooth => localized(
                    context,
                    'Bluetooth',
                    'Bluetooth',
                  ),
                },
              },
            );
      return GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('v1-practice-setup'),
          leading: const Icon(Icons.tune),
          title: Text(localized(context, 'Setup', 'Kurulum')),
          subtitle: Text(line, key: const Key('v1-practice-setup-status')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_openSetup()),
        ),
      );
    },
  );

  Widget _tile(
    BuildContext context,
    V1PracticeCatalog catalog,
    V1Lesson lesson,
    V1PracticeRecord? record,
    bool open,
  ) {
    final target = lesson.practice.tempo?.target;
    final status = record?.completed ?? false
        ? localized(
            context,
            'COMPLETED · ♩={v0}',
            'TAMAMLANDI · ♩={v0}',
            values: {'v0': record!.completedBpm ?? 0},
          )
        : record?.passed ?? false
        ? target == null
              ? localized(
                  context,
                  'PASSED · ♩={v0}',
                  'GEÇİLDİ · ♩={v0}',
                  values: {'v0': record!.passedBpm ?? 0},
                )
              : localized(
                  context,
                  'PASSED · ♩={v0} · completes at ♩={v1}',
                  'GEÇİLDİ · ♩={v0} · ♩={v1} ile tamamlanır',
                  values: {'v0': record!.passedBpm ?? 0, 'v1': target},
                )
        : !open
        ? localized(
            context,
            'LOCKED · pass the lesson before',
            'KİLİTLİ · önceki dersi geç',
          )
        : (record?.runs ?? 0) > 0
        ? localized(
            context,
            'PLAYED ×{v0}',
            'ÇALINDI ×{v0}',
            values: {'v0': record!.runs},
          )
        : localized(context, 'OPEN', 'AÇIK');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: Key('v1-practice-${lesson.id}'),
          enabled: open,
          leading: Icon(
            record?.completed ?? false
                ? Icons.check_circle
                : record?.passed ?? false
                ? Icons.check_circle_outline
                : open
                ? Icons.play_circle_outline
                : Icons.lock_outline,
          ),
          title: Text(lesson.title.of(context)),
          subtitle: Text(status, style: monoText()),
          onTap: open ? () => unawaited(_open(catalog, lesson)) : null,
        ),
      ),
    );
  }
}
