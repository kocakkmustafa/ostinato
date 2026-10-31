import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../curriculum/v1_lesson.dart';
import '../../account_connection.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
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
  });

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
    }
  }

  void _reload() {
    final next = _progress!.load();
    setState(() {
      _records = next;
    });
  }

  Future<void> _open(V1PracticeCatalog catalog, V1Lesson lesson) async {
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
            ),
      ),
    );
    if (!mounted) return;
    _reload();
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
                    if (catalog.lessons.isEmpty)
                      Text(
                        localized(
                          context,
                          'No measured lessons yet.',
                          'Henüz ölçülü ders yok.',
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

  Widget _tile(
    BuildContext context,
    V1PracticeCatalog catalog,
    V1Lesson lesson,
    V1PracticeRecord? record,
    bool open,
  ) {
    final status = record?.passed ?? false
        ? localized(
            context,
            'PASSED · ♩={v0}',
            'GEÇİLDİ · ♩={v0}',
            values: {'v0': record!.passedBpm ?? 0},
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
            record?.passed ?? false
                ? Icons.check_circle
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
