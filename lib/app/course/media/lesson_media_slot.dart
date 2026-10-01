import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart';

import '../../account_connection.dart';
import 'lesson_media_catalog.dart';
import 'lesson_media_playback.dart';

/// Source and byte inspection stays invisible. Accepted media still needs a
/// signed release root, playback/audio arbitration and real device acceptance.
class LessonMediaSlot extends StatefulWidget {
  const LessonMediaSlot({
    required this.catalog,
    required this.bundle,
    required this.lessonId,
    required this.sceneId,
    required this.variantStem,
    required this.locale,
    this.durationProbe,
    @visibleForTesting this.onInspectionChanged,
    super.key,
  }) : testingPlayback = null,
       testingVideoFactory = null,
       testingGate = null;

  LessonMediaSlot.empty({
    required this.lessonId,
    required this.locale,
    super.key,
  }) : catalog = const LessonMediaCatalog.empty(),
       bundle = rootBundle,
       sceneId = null,
       variantStem = null,
       durationProbe = null,
       onInspectionChanged = null,
       testingPlayback = null,
       testingVideoFactory = null,
       testingGate = null;

  /// Debug-only silent fake. The shipping route never constructs this path.
  @visibleForTesting
  const LessonMediaSlot.testingPlayback({
    required this.lessonId,
    required this.locale,
    required this.bundle,
    required LessonMediaPlaybackFixture fixture,
    required SilentLessonVideoFactory videoFactory,
    required DebugSilentVideoGate gate,
    super.key,
  }) : catalog = const LessonMediaCatalog.empty(),
       sceneId = null,
       variantStem = null,
       durationProbe = null,
       onInspectionChanged = null,
       testingPlayback = fixture,
       testingVideoFactory = videoFactory,
       testingGate = gate;

  final LessonMediaCatalog catalog;
  final AssetBundle bundle;
  final String lessonId, locale;
  final String? sceneId, variantStem;
  final MediaDurationProbe? durationProbe;
  final ValueChanged<InspectedLessonMedia?>? onInspectionChanged;
  final LessonMediaPlaybackFixture? testingPlayback;
  final SilentLessonVideoFactory? testingVideoFactory;
  final DebugSilentVideoGate? testingGate;

  @override
  State<LessonMediaSlot> createState() => _LessonMediaSlotState();
}

class _LessonMediaSlotState extends State<LessonMediaSlot>
    with WidgetsBindingObserver {
  int _epoch = 0;
  bool _closed = false;
  bool _accountInitialized = false;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inspect();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = AccountScope.maybeOf(context)?.currentUserId;
    if (_accountInitialized && current != _accountId) _close();
    _accountInitialized = true;
    _accountId = current;
    if (widget.testingPlayback != null &&
        ModalRoute.isCurrentOf(context) != true) {
      _close();
    }
  }

  @override
  void didUpdateWidget(covariant LessonMediaSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId ||
        oldWidget.locale != widget.locale ||
        oldWidget.catalog != widget.catalog ||
        oldWidget.bundle != widget.bundle ||
        oldWidget.sceneId != widget.sceneId ||
        oldWidget.variantStem != widget.variantStem ||
        oldWidget.durationProbe != widget.durationProbe ||
        oldWidget.testingPlayback != widget.testingPlayback ||
        oldWidget.testingVideoFactory != widget.testingVideoFactory ||
        oldWidget.testingGate != widget.testingGate) {
      _close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _close(rebuild: true);
  }

  void _close({bool rebuild = false}) {
    if (_closed) return;
    _closed = true;
    _epoch++;
    widget.onInspectionChanged?.call(null);
    if (rebuild && mounted) setState(() {});
  }

  Future<void> _inspect() async {
    if (widget.catalog.isEmpty ||
        widget.sceneId == null ||
        widget.variantStem == null ||
        widget.durationProbe == null) {
      return;
    }
    final epoch = ++_epoch;
    final result = await widget.catalog.inspect(
      bundle: widget.bundle,
      lessonId: widget.lessonId,
      sceneId: widget.sceneId!,
      variantStem: widget.variantStem!,
      locale: widget.locale,
      durationProbe: widget.durationProbe,
    );
    if (mounted && !_closed && epoch == _epoch) {
      widget.onInspectionChanged?.call(result);
    }
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixture = widget.testingPlayback;
    final factory = widget.testingVideoFactory;
    final gate = widget.testingGate;
    if (!kReleaseMode &&
        !_closed &&
        fixture != null &&
        factory != null &&
        gate != null &&
        fixture.lessonId == widget.lessonId &&
        fixture.captionAssetPaths.containsKey(widget.locale) &&
        ModalRoute.isCurrentOf(context) == true) {
      return DebugSilentLessonPlayback(
        fixture: fixture,
        bundle: widget.bundle,
        locale: widget.locale,
        videoFactory: factory,
        gate: gate,
      );
    }
    return const SizedBox.shrink();
  }
}
