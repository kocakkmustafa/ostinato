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
        await f.writeAsString(
          '${jsonEncode(session.toJson())}\n',
          mode: FileMode.append,
          flush: true,
        );
      }, writing: true);

  /// En son kaydı döner — bugünkü kullanım "basit geçmiş listesi" için
  /// yeterli (D14 kapsamı). Bozuk/tanınmayan satırlar SESSİZCE atlanır
  /// (adıyla değil — çünkü bu bir kullanıcı YÜZEYİ değil, kendi
  /// dosyamızın kendi geçmiş yazmalarından biri bozulmuş olabilir; bir
  /// önceki turun kaydı okunamıyorsa en son OKUNABİLEN gösterilir).
  Future<PersistedSession?> lastSession() => _operations.run((directory) async {
    final f = File('${directory.path}/sessions.jsonl');
    if (!f.existsSync()) return null;
    final List<String> lines = await f.readAsLines();
    for (final String line in lines.reversed) {
      if (line.trim().isEmpty) continue;
      final PersistedSession? parsed = PersistedSession.tryParse(line);
      if (parsed != null) return parsed;
    }
    return null;
  });
}
