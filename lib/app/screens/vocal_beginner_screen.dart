import 'package:flutter/material.dart';

import '../app_locale.dart';
import 'feedback_availability.dart';
import '../vocal_beginner.dart';
import 'vocal_diagrams.dart';

/// Written practice only. No sensor, entitlement, progress or audio acquisition.
class VocalBeginnerScreen extends StatefulWidget {
  const VocalBeginnerScreen({super.key, this.bundle});
  final AssetBundle? bundle;
  @override
  State<VocalBeginnerScreen> createState() => _VocalBeginnerScreenState();
}

class _VocalBeginnerScreenState extends State<VocalBeginnerScreen> {
  late Future<VocalCourse?> _course;
  Future<VocalCourse?> _load() async {
    try {
      return await VocalCourse.load(bundle: widget.bundle);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _course = _load();
  }

  @override
  void didUpdateWidget(covariant VocalBeginnerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle != widget.bundle) {
      _course = _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        localized(
          context,
          'Vocal beginner foundation',
          'Vokal başlangıç temeli',
        ),
      ),
    ),
    body: FutureBuilder<VocalCourse?>(
      future: _course,
      builder: (context, snapshot) {
        // FutureBuilder may retain old data during a replacement load.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localized(
                    context,
                    'Written course unavailable.',
                    'Yazılı kurs açılamadı.',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _course = _load();
                  }),
                  child: Text(localized(context, 'Retry', 'Yeniden dene')),
                ),
              ],
            ),
          );
        }
        final course = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              course.title.of(context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const FeedbackAvailability(instrumentId: 'voice'),
            Text(course.entry.of(context)),
            const SizedBox(height: 16),
            Text(course.exit.of(context)),
            const SizedBox(height: 16),
            Text(
              localized(
                context,
                'Written guidance and self-observation only. No measured voice, pitch, score or mastery approval.',
                'Yalnız yazılı rehberlik ve öz gözlem. Ölçülen ses, perde, puan veya ustalık onayı yok.',
              ),
            ),
            for (var i = 0; i < course.lessons.length; i++)
              ListTile(
                key: Key(course.lessons[i].id),
                title: Text('${i + 1}. ${course.lessons[i].title.of(context)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _VocalLessonScreen(course: course, index: i),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _VocalLessonScreen extends StatelessWidget {
  const _VocalLessonScreen({required this.course, required this.index});
  final VocalCourse course;
  final int index;
  @override
  Widget build(BuildContext context) {
    final lesson = course.lessons[index];
    final headings = [
      localized(context, 'Learn', 'Öğren'),
      localized(context, 'Practise', 'Çalış'),
      localized(context, 'Self-check', 'Özdeğerlendirme'),
      localized(context, 'Recover', 'Toparlan'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title.of(context))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (var i = 0; i < 4; i++) ...[
            Semantics(
              header: true,
              child: Text(
                headings[i],
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(lesson.sections[i].of(context)),
            if (i == 1) VocalDiagrams(course: course, lesson: lesson),
            const SizedBox(height: 24),
          ],
          Text(
            localized(
              context,
              'Repeat or return to an earlier task whenever needed. Reading a page does not complete a skill.',
              'Gerekirse tekrarla veya önceki göreve dön. Sayfayı okumak beceriyi tamamlamaz.',
            ),
          ),
          if (index > 0)
            TextButton(
              key: const Key('vocal-previous-lesson'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _VocalLessonScreen(course: course, index: index - 1),
                ),
              ),
              child: Text(localized(context, 'Previous lesson', 'Önceki ders')),
            ),
          if (index + 1 < course.lessons.length)
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _VocalLessonScreen(course: course, index: index + 1),
                ),
              ),
              child: Text(localized(context, 'Next lesson', 'Sonraki ders')),
            ),
        ],
      ),
    );
  }
}
