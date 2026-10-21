import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'account_data_directory.dart';
import 'account_data_operations.dart';

import 'screens/review_screen.dart' show SessionSummary;

/// D14 (2026-08-16, O-153, kurucu kararı — `validate_persistence.py`
/// bu kararı VERMEDİ, görünür tuttu; karar bu dosyanın kendisi).
///
/// KULLANICI ÜRETİMİ — tek yazma yeri. Her pratik oturumunun SONUCU
/// (`SessionSummary`nin özeti; ham açı-örnekleri = `history` DEĞİL, bkz.
/// [PersistedSession.fromSummary]) `sessions.jsonl`e satır olarak eklenir.
/// Şema `v` alanı taşır — ileride değişirse eski satırlar hâlâ okunabilir
/// kalmalı ya da adıyla reddedilmeli, sessizce çökmemeli (`H-21` dersi).
///
/// GİZLİLİK BAĞI (M-F-650): Apple'ın anlamında "collect" = cihazdan DIŞARI
/// aktarmak. Bu dosya asla ağa çıkmaz — `test/flutter_test_config.dart`ın
/// repo-geneli sıfır-ağ kapısı (D1) bu dosyayı da kapsar: bir gün bu modül
/// (ya da onu çağıran herhangi bir kod) ağa çıkmaya çalışırsa o kapı öter.
/// **O kapı öterse bu satırı ve `PrivacyInfo.xcprivacy`nin
/// `NSPrivacyCollectedDataTypes` beyanını YENİDEN DEĞERLENDİR** — boş
/// kalışı bu varsayıma dayanıyor, varsayım tripwire'e bağlı, belgeye değil.
class PersistedSession {
  const PersistedSession({
    required this.schemaVersion,
    required this.disciplineId,
    required this.lessonId,
    required this.completedAt,
    required this.elapsedSeconds,
    required this.sampleCount,
    required this.outCount,
  });

  /// Bugünkü şema. Sayı ARTARSA eski okuyucu yeni satırı reddetmeli
  /// (bilinmeyen şema ≠ bozuk dosya — H-21'in üçüncü sınıfı).
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String disciplineId;
  final String lessonId;
  final DateTime completedAt;
  final int elapsedSeconds;
  final int sampleCount;
  final int outCount;

  /// `history` (ham açı-örnekleri) BİLEREK taşınmaz — saklanan şey
  /// oturumun ÖZETİ, kare-kare hareketi değil. Bu bir eksiklik değil bir
  /// kapsam kararı (D14'ün kendisi): "basit geçmiş listesi yeter."
  factory PersistedSession.fromSummary({
    required String disciplineId,
    required String lessonId,
    required SessionSummary summary,
    required DateTime completedAt,
  }) => PersistedSession(
    schemaVersion: currentSchemaVersion,
    disciplineId: disciplineId,
    lessonId: lessonId,
    completedAt: completedAt,
    elapsedSeconds: summary.elapsedSeconds,
    sampleCount: summary.sampleCount,
    outCount: summary.outCount,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'v': schemaVersion,
    'disciplineId': disciplineId,
    'lessonId': lessonId,
    'completedAt': completedAt.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'sampleCount': sampleCount,
    'outCount': outCount,
  };

  /// `null` döner (fırlatmaz) satır okunamazsa — ÜÇ ayrı biçimde:
  /// bozuk JSON, geçerli JSON + yanlış tip, bilinmeyen şema sürümü.
  /// `H-21`in dersi: `FormatException` yakalamak YETMEZ — `as int`/`as
  /// String` cast'leri `TypeError` fırlatır, JSON GEÇERLİ olduğu için
  /// ayrıştırma hatası sayılmaz. Üçü de burada yakalanır, hiçbiri
  /// açılışı çökertmez.
  static PersistedSession? tryParse(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    try {
      final int version = decoded['v'] as int;
      if (version != currentSchemaVersion) return null;
      return PersistedSession(
        schemaVersion: version,
        disciplineId: decoded['disciplineId'] as String,
        lessonId: decoded['lessonId'] as String,
        completedAt: DateTime.parse(decoded['completedAt'] as String),
        elapsedSeconds: decoded['elapsedSeconds'] as int,
        sampleCount: decoded['sampleCount'] as int,
        outCount: decoded['outCount'] as int,
      );
    } on TypeError {
      return null;
    } on FormatException {
      // DateTime.parse de FormatException fırlatabilir (bozuk tarih).
      return null;
    }
  }
}

/// `sessions.jsonl` — `getApplicationSupportDirectory()` altında, aile
/// deseniyle aynı (Lissom `attempt_values.jsonl`, `M-F-650`).
class SessionStore {
  SessionStore({this.directoryProvider, this.accountUserId})
    : _operations = AccountDataOperations(() async {
        final root =
            await (directoryProvider ?? getApplicationSupportDirectory)();
        return accountDataDirectory(root, accountUserId);
      });

  /// Testler GERÇEK `getApplicationSupportDirectory()`e (platform kanalı
  /// ister, `flutter test`te YOK) ihtiyaç duymadan geçici bir dizin
  /// enjekte edebilsin diye — üretimde `null`, gerçek path_provider'a
  /// düşer. Sahte bir platform kurmak yerine (eski `flutter_test_config`
  /// deseni) doğrudan bağımlılık enjeksiyonu: daha az hareketli parça.
  final Future<Directory> Function()? directoryProvider;

  /// Null retains the pre-account local journal. Signed-in accounts never
  /// read or append to that journal or to another account's journal.
  final String? accountUserId;
  final AccountDataOperations _operations;

  Future<void> save(PersistedSession session) =>
      _operations.run((directory) async {
        final f = File('${directory.path}/sessions.jsonl');
        await f.parent.create(recursive: true);
        var separator = '';
        if (await f.exists()) {
          final input = await f.open();
          try {
            final length = await input.length();
            if (length > 0) {
              await input.setPosition(length - 1);
              if (await input.readByte() != 0x0a) separator = '\n';
            }
          } finally {
            await input.close();
          }
        }
        await f.writeAsString(
          '$separator${jsonEncode(session.toJson())}\n',
          mode: FileMode.append,
          flush: true,
        );
      }, writing: true);

  /// En son kaydı döner — bugünkü kullanım "basit geçmiş listesi" için
  /// yeterli (D14 kapsamı). Bozuk/tanınmayan satırlar SESSİZCE atlanır
  /// (adıyla değil — çünkü bu bir kullanıcı YÜZEYİ değil, kendi
  /// dosyamızın kendi geçmiş yazmalarından biri bozulmuş olabilir; bir
  /// önceki turun kaydı okunamıyorsa en son OKUNABİLEN gösterilir).
  ///
  /// Satırlar BAYT düzeyinde 0x0a'dan bölünür ve her biri ayrı çözülür: yarım
  /// kalmış çok baytlı bir UTF-8 kuyruğu (ör. "ü"nün yalnız 0xC3'ü) bütün
  /// dosyayı okunamaz kılmamalı. 0x0a hiçbir çok baytlı dizinin parçası
  /// olamaz, bu yüzden bölme geçerli satırları bozmaz. Bozuk baytlar dosyada
  /// KALIR — okuma onarım yazmaz, yalnız o satırı atlar.
  Future<PersistedSession?> lastSession() => _operations.run((directory) async {
    final f = File('${directory.path}/sessions.jsonl');
    if (!f.existsSync()) return null;
    final List<int> bytes = await f.readAsBytes();
    var end = bytes.length;
    while (end > 0) {
      var start = end - 1;
      while (start >= 0 && bytes[start] != 0x0a) {
        start--;
      }
      final PersistedSession? parsed = _parseLine(bytes, start + 1, end);
      if (parsed != null) return parsed;
      end = start < 0 ? 0 : start;
    }
    return null;
  });

  static PersistedSession? _parseLine(List<int> bytes, int start, int end) {
    if (start >= end) return null;
    final String line;
    try {
      line = utf8.decode(bytes.sublist(start, end));
    } on FormatException {
      return null;
    }
    if (line.trim().isEmpty) return null;
    return PersistedSession.tryParse(line);
  }
}

/// D14 (2026-08-16, O-153): ÖNCE önceki kaydı OKU, SONRA bugünküyü YAZ —
/// sıra kasıtlı, aksi hâlde "önceki oturum" bugünküyle YARIŞIR. Yazma
/// kasıtlı unawaited; dönen Future yazmayı beklemez.
///
/// Okuma başarısız olsa bile bugünkü kayıt YAZILIR: önceki kartın
/// gösterilememesi, bu oturumun geçmişe eklenmemesinin sebebi olamaz. Okuma
/// hatası yazma başlatıldıktan sonra yeniden fırlatılır; Review'un
/// `FutureBuilder`ı yalnız geçmiş kartını çizmez.
Future<PersistedSession?> readPreviousThenSave(
  SessionStore store,
  PersistedSession current,
) async {
  final PersistedSession? previous;
  try {
    previous = await store.lastSession();
  } catch (_) {
    store.save(current).ignore();
    rethrow;
  }
  store.save(current).ignore();
  return previous;
}
