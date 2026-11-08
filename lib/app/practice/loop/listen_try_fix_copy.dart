import '../../ui_copy.dart';

/// OST-P0-06 copy (listen → try → fix → repeat card on the result screen).
/// Warm and never a verdict: no "wrong", no "mistake", no "error", no
/// "fail"; `test/listen_try_fix_test.dart` scans these for such words.
/// Message ids are in `lib/app/app_message_ids.dart`, the 14 catalogs carry
/// the translations.
abstract final class ListenTryFixCopy {
  static const UiCopy title = (
    'One thing to work on',
    'Üzerinde çalışılacak tek şey',
  );
  static const UiCopy early = (
    'A few beats came a little early (bar {v0}). Try that part again, a bit slower.',
    'Birkaç vuruş biraz erken geldi (ölçü {v0}). O bölümü biraz daha yavaş tekrar dene.',
  );
  static const UiCopy late = (
    'A few beats came a little late (bar {v0}). Try that part again, a bit slower, with the click.',
    'Birkaç vuruş biraz geç geldi (ölçü {v0}). O bölümü klikle birlikte, biraz daha yavaş tekrar dene.',
  );
  static const UiCopy missed = (
    'I did not hear a beat in bar {v0}. Try that part again, a bit slower.',
    'Ölçü {v0} içinde bir vuruş duymadım. O bölümü biraz daha yavaş tekrar dene.',
  );
  static const UiCopy pitch = (
    'Some notes sounded different from the written pitch (bar {v0}). Play that part slowly and let each note ring.',
    'Bazı notalar yazılan perdeden farklı duyuldu (ölçü {v0}). O bölümü yavaş çal ve her notanın tınlamasına izin ver.',
  );
  static const UiCopy clear = (
    'I measured no clear difference this time. Your playing was steady; you can try a little faster.',
    'Bu sefer net bir fark ölçmedim. Düzenli çaldın; biraz daha hızlı deneyebilirsin.',
  );
  static const UiCopy couldNotMeasure = (
    "I couldn't tell this sound apart with confidence; will you try again?",
    'Bu sesi güvenle ayırt edemedim; tekrar dener misin?',
  );
  static const UiCopy stepsLabel = ('Repeat in steps', 'Adımlarla tekrar');
  static const UiCopy tryAt = (
    'Try again at ♩={v0}',
    '♩={v0} temposunda tekrar dene',
  );
  static const UiCopy nextExercise = (
    'Next, a short exercise for this: {v0}',
    'Bunun için sıradaki kısa alıştırma: {v0}',
  );

  static const List<UiCopy> all = [
    title,
    early,
    late,
    missed,
    pitch,
    clear,
    couldNotMeasure,
    stepsLabel,
    tryAt,
    nextExercise,
  ];
}
