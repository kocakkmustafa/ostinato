import '../../ui_copy.dart';

/// FK1 reference ("listen first") copy. Mirrored in `content/ui/reference.json`;
/// see `test/ui_copy_catalog_test.dart`.
abstract final class ReferenceCopy {
  static const UiCopy listenAt = (
    'Listen at ♩={v0}',
    '♩={v0} temposunda dinle',
  );
  static const UiCopy stop = ('Stop listening', 'Dinlemeyi durdur');
  static const UiCopy preparing = (
    'Preparing the line…',
    'Satır hazırlanıyor…',
  );
  static const UiCopy playing = (
    'Playing at ♩={v0}: one count-in bar, then the line.',
    '♩={v0} temposunda çalıyor: bir ölçü giriş, sonra satır.',
  );
  static const UiCopy truncated = (
    'Plays the first {v0} of {v1} bars.',
    '{v1} ölçünün ilk {v0} ölçüsü çalınır.',
  );
  static const UiCopy unavailable = (
    'The reference can’t play right now. Stop other audio and try again.',
    'Referans şu an çalamıyor. Diğer sesleri durdurup yeniden dene.',
  );
  static const UiCopy synthesized = (
    'The app synthesizes the line on your phone; it is not a recording.',
    'Satırı uygulama telefonunda sentezler; bu bir kayıt değildir.',
  );

  static const List<UiCopy> all = [
    listenAt,
    stop,
    preparing,
    playing,
    truncated,
    unavailable,
    synthesized,
  ];
}
