import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/session_store.dart';

/// F2 takip görevi (D14, O-153): `H-21` sınıfının üç biçimini (+ code
/// review sırasında ortaya çıkan iki komşu biçimi) SABOTAJLA kanıtlar —
/// "kod savunmalı yazıldı" iddiası yeterli değil, gerçek bozuk girdiyle
/// açılışın ÇÖKMEDİĞİ ve en son OKUNABİLEN kayda düştüğü ölçülmeli.
void main() {
  final Map<String, Object?> validJson = <String, Object?>{
    'v': 1,
    'disciplineId': 'guitar',
    'lessonId': 'g-01',
    'completedAt': '2026-08-16T10:00:00.000Z',
    'elapsedSeconds': 120,
    'sampleCount': 40,
    'outCount': 3,
  };
  String encode(Map<String, Object?> m) => jsonEncode(m);

  group('PersistedSession.tryParse — H-21 sınıfları (izole)', () {
    test('geçerli satır doğru ayrıştırılır (pozitif kontrol)', () {
      final PersistedSession? s = PersistedSession.tryParse(encode(validJson));
      expect(s, isNotNull);
      expect(s!.disciplineId, 'guitar');
      expect(s.elapsedSeconds, 120);
    });

    test('sınıf 1 — bozuk JSON (ayrıştırılamaz) → null, fırlatmaz', () {
      expect(PersistedSession.tryParse('{"v": 1, "disciplineId": '), isNull);
      expect(PersistedSession.tryParse('not json at all'), isNull);
      expect(PersistedSession.tryParse(''), isNull);
    });

    test('sınıf 1b — geçerli JSON ama Map değil → null, fırlatmaz', () {
      expect(PersistedSession.tryParse('[1, 2, 3]'), isNull);
      expect(PersistedSession.tryParse('"just a string"'), isNull);
      expect(PersistedSession.tryParse('42'), isNull);
    });

    test('sınıf 2 — geçerli JSON + yanlış tip (TypeError) → null, fırlatmaz',
        () {
      final Map<String, Object?> wrongType = <String, Object?>{
        ...validJson,
        'elapsedSeconds': 'yüz yirmi', // int beklenir, String geldi
      };
      expect(PersistedSession.tryParse(encode(wrongType)), isNull);
    });

    test('sınıf 2b — "v" alanı yanlış tipte (int değil) → null, fırlatmaz',
        () {
      final Map<String, Object?> wrongVersionType = <String, Object?>{
        ...validJson,
        'v': '1', // int beklenir, String geldi — `as int` TypeError fırlatır
      };
      expect(PersistedSession.tryParse(encode(wrongVersionType)), isNull);
    });

    test('sınıf 3 — bilinmeyen şema sürümü (doğru tip, yanlış değer) → null',
        () {
      final Map<String, Object?> futureVersion = <String, Object?>{
        ...validJson,
        'v': 999,
      };
      expect(PersistedSession.tryParse(encode(futureVersion)), isNull);
    });

    test(
        'sınıf 4 — bozuk tarih dizesi (ikinci FormatException yakalama noktası) → null',
        () {
      final Map<String, Object?> badDate = <String, Object?>{
        ...validJson,
        'completedAt': 'öğleden sonra bir ara',
      };
      expect(PersistedSession.tryParse(encode(badDate)), isNull);
    });
  });

  group('SessionStore — sabotajlı dosya (uygulanmış + indiği kanıtlı)', () {
    late Directory tempDir;
    late SessionStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ostinato_session_store');
      store = SessionStore(directoryProvider: () async => tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('dosya hiç yoksa null döner, fırlatmaz', () async {
      expect(await store.lastSession(), isNull);
    });

    test('kaydet → oku round-trip (mutlu yol kontrolü)', () async {
      final PersistedSession original = PersistedSession(
        schemaVersion: PersistedSession.currentSchemaVersion,
        disciplineId: 'voice',
        lessonId: 'v-03',
        completedAt: DateTime.utc(2026, 8, 16, 9, 30),
        elapsedSeconds: 200,
        sampleCount: 80,
        outCount: 5,
      );
      await store.save(original);
      final PersistedSession? read = await store.lastSession();
      expect(read, isNotNull);
      expect(read!.disciplineId, 'voice');
      expect(read.lessonId, 'v-03');
      expect(read.elapsedSeconds, 200);
      expect(read.outCount, 5);
    });

    test(
        'SABOTAJ — son 3 satır üç ayrı biçimde bozuk, en eski GEÇERLİ satıra düşer',
        () async {
      final File f = File('${tempDir.path}/sessions.jsonl');
      final Map<String, Object?> older = <String, Object?>{
        ...validJson,
        'lessonId': 'g-oldest-good',
      };
      await f.writeAsString(
        <String>[
          encode(older), // en eski — TEK okunabilir kayıt
          '{"v": 1, broken json here', // sınıf 1
          encode(<String, Object?>{...validJson, 'v': 999}), // sınıf 3
          encode(<String, Object?>{
            ...validJson,
            'sampleCount': 'kırk', // sınıf 2
          }),
        ].map((String l) => '$l\n').join(),
      );

      final PersistedSession? recovered = await store.lastSession();
      expect(recovered, isNotNull);
      expect(recovered!.lessonId, 'g-oldest-good');
    });

    test('SABOTAJ — dosyadaki HER satır bozuk → null döner, fırlatmaz',
        () async {
      final File f = File('${tempDir.path}/sessions.jsonl');
      await f.writeAsString(<String>[
        'garbage',
        encode(<String, Object?>{...validJson, 'v': 7}),
        encode(<String, Object?>{...validJson, 'outCount': 'sıfır'}),
      ].map((String l) => '$l\n').join());

      expect(await store.lastSession(), isNull);
    });

    test('boş satırlar (trailing newline vb.) sessizce atlanır', () async {
      final File f = File('${tempDir.path}/sessions.jsonl');
      await f.writeAsString('${encode(validJson)}\n\n   \n');
      final PersistedSession? read = await store.lastSession();
      expect(read, isNotNull);
      expect(read!.disciplineId, 'guitar');
    });
  });
}
