import '../../ui_copy.dart';

/// Copy for rhythm-only lines (A3 onset timing) on the practice and result
/// screens. Mirrored in `content/ui/practice-rhythm.json`; see
/// `test/ui_copy_catalog_test.dart`. A beat off the window is "early or
/// late", never "wrong".
abstract final class RhythmCopy {
  static const UiCopy earlyOrLate = ('Early or late', 'Erken ya da geç');
  static const UiCopy onTime = ('On time', 'Zamanında');
  static const UiCopy gateOnTime = (
    'On time ≥ %{v0} (within ±{v1} ms)',
    'Zamanında ≥ %{v0} (±{v1} ms içinde)',
  );
  static const UiCopy onTimeNote = (
    'On time counts only the beats I could hear; "couldn\'t hear" is reported apart.',
    'Zamanında oranı yalnız duyabildiğim vuruşları sayar; "duyamadım" ayrı raporlanır.',
  );
  static const UiCopy timingRelative = (
    '{v0} ms · relative',
    '{v0} ms · göreli',
  );
  static const UiCopy relativeNote = (
    'Latency is not calibrated on this output, so timing was measured against your own steady offset. Calibrate it to compare with the click exactly.',
    'Bu çıkışta gecikme kalibre edilmedi; zamanlama senin sabit kaymana göre ölçüldü. Klikle tam karşılaştırmak için kalibrasyon yap.',
  );
  static const UiCopy earlyLate = (
    'Early: {v0} · Late: {v1}',
    'Erken: {v0} · Geç: {v1}',
  );

  static const List<UiCopy> all = [
    earlyOrLate,
    onTime,
    gateOnTime,
    onTimeNote,
    timingRelative,
    relativeNote,
    earlyLate,
  ];
}
