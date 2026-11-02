import '../../ui_copy.dart';

/// FK6 tempo ladder copy. Mirrored in `content/ui/tempo-ladder.json`; see
/// `test/ui_copy_catalog_test.dart`.
abstract final class TempoLadderCopy {
  static const UiCopy switchOn = ('Tempo ladder: On', 'Tempo merdiveni: Açık');
  static const UiCopy switchOff = (
    'Tempo ladder: Off',
    'Tempo merdiveni: Kapalı',
  );
  static const UiCopy switchHint = (
    'After a full run that meets the checks, the next run is {v0} BPM faster, up to the target ♩={v1}.',
    'Ölçütleri karşılayan tam bir turdan sonra sonraki tur {v0} BPM hızlanır; en fazla hedef ♩={v1} temposuna kadar.',
  );
  static const UiCopy resultTitle = ('Tempo ladder', 'Tempo merdiveni');
  static const UiCopy nextRun = ('Next run at ♩={v0}', 'Sonraki tur ♩={v0}');
  static const UiCopy nextRunTarget = (
    'Next run at the target ♩={v0} — that run counts for the gate',
    'Sonraki tur hedef tempoda (♩={v0}) — o tur geçiş için sayılır',
  );
  static const UiCopy held = (
    'Next run stays at ♩={v0} — the ladder moves up after a full run that meets the checks',
    'Sonraki tur ♩={v0} temposunda kalır — merdiven, ölçütleri karşılayan tam bir turdan sonra yükselir',
  );
  static const UiCopy targetReached = (
    'Target reached — this run counts for the gate',
    'Hedefe ulaşıldı — bu tur geçiş için sayılır',
  );
  static const UiCopy targetReachedNeedsFullRun = (
    'Target reached — a full run here counts for the gate',
    'Hedefe ulaşıldı — bu tempoda tam bir tur geçiş için sayılır',
  );
  static const UiCopy onlyTargetCompletes = (
    'Only a run at the target ♩={v0} completes the lesson.',
    'Dersi yalnız hedef tempodaki (♩={v0}) bir tur tamamlar.',
  );
  static const UiCopy playAt = ('Play at ♩={v0}', '♩={v0} temposunda çal');

  static const List<UiCopy> all = [
    switchOn,
    switchOff,
    switchHint,
    resultTitle,
    nextRun,
    nextRunTarget,
    held,
    targetReached,
    targetReachedNeedsFullRun,
    onlyTargetCompletes,
    playAt,
  ];
}
