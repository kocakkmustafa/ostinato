/// OST-P1-01 — ortak doğrulama raporu (saf Dart). Kodlar sabit, test bunlara bakar.
final class ValidationIssue {
  const ValidationIssue(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

final class ValidationReport {
  const ValidationReport({
    required this.issues,
    this.durationSeconds,
    this.noteCount = 0,
    this.minNote,
    this.maxNote,
  });

  final List<ValidationIssue> issues;

  /// Tempo haritasından hesaplanan toplam süre (yalnız yapı çözülebildiyse).
  final double? durationSeconds;
  final int noteCount;
  final int? minNote, maxNote;

  bool get isValid => issues.isEmpty;

  bool hasCode(String code) => issues.any((i) => i.code == code);

  @override
  String toString() => isValid ? 'geçerli' : issues.join('\n');
}
