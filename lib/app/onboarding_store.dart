import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// "İlk açılışı gördü mü" — TEK bit, kendi seam'i.
///
/// **Neden yeni bir paket değil:** `shared_preferences` bu iş için bir
/// bağımlılık daha getirirdi; `path_provider` zaten burada (poz modelini
/// yazan yol onu kullanıyor, `pose_model.dart`). Bu depo bir BİÇİM değil bir
/// İŞARET tutar — dosyanın VARLIĞI cevaptır, içeriği değil. İçerik taşımayan
/// bir işaretin şeması da olamaz, dolayısıyla bayatlayamaz.
///
/// **Neden arayüz:** widget testinde `path_provider` platform kanalı yok. Bir
/// singleton okusaydık onboarding testi ya gerçek dosya sistemine yazardı ya
/// da hiç koşamazdı. [InMemoryOnboardingStore] testin bu biti İSTEDİĞİ gibi
/// kurmasını sağlar — "ilk açılış" ve "ikinci açılış" iki AYRI ölçülebilir
/// durum olur.
abstract interface class OnboardingStore {
  Future<bool> isComplete();
  Future<void> markComplete();
}

final class FileOnboardingStore implements OnboardingStore {
  const FileOnboardingStore();

  static const String _fileName = 'onboarding-v1.done';

  Future<File> _marker() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Okuma HATASI "görülmedi" sayılır — açılamayan bir işaret, olmayan bir
  /// işaretle aynı bilgiyi taşır. Yanlış tarafa düşerse maliyeti karşılamayı
  /// bir kez daha görmektir; diğer taraf (hata → "görüldü" say) kullanıcıyı
  /// izin gerekçesini hiç görmeden kameranın önüne çıkarırdı.
  @override
  Future<bool> isComplete() async {
    try {
      return await (await _marker()).exists();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> markComplete() async {
    try {
      await (await _marker()).writeAsString(
          'Ostinato onboarding v1 seen.\n', flush: true);
    } on Object {
      // Yazamamak akışı DURDURMAZ: kullanıcı karşılamayı gördü, uygulamayı
      // ona kilitlemenin bir gerekçesi yok. Bedeli bir sonraki açılışta onu
      // tekrar görmek — sessiz bir çıkmaz sokaktan iyidir.
    }
  }
}

/// Yalnız test için — üretimde kullanılmaz.
final class InMemoryOnboardingStore implements OnboardingStore {
  InMemoryOnboardingStore({bool complete = false}) : _complete = complete;

  bool _complete;
  int markCalls = 0;

  @override
  Future<bool> isComplete() async => _complete;

  @override
  Future<void> markComplete() async {
    markCalls++;
    _complete = true;
  }
}
