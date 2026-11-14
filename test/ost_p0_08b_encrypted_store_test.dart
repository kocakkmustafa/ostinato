// OST-P0-08B — encrypted on-device take store. The component exists but is
// NOT wired to any UI or flow; retention policy still denies persistence.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/own_recording/encrypted_take_store.dart';
import 'package:ostinato/app/practice/own_recording/recording_retention_policy.dart';
import 'package:ostinato/app/practice/own_recording/secure_key_store.dart';

/// In-memory stand-in for the Keychain/Keystore bridge.
final class MemoryKeyStore implements KeyStore {
  Uint8List? _key;
  int deletes = 0;

  @override
  Future<Uint8List?> read() async =>
      _key == null ? null : Uint8List.fromList(_key!);

  @override
  Future<Uint8List> create() async {
    _key = generateKeyBytes();
    return Uint8List.fromList(_key!);
  }

  @override
  Future<void> delete() async {
    deletes++;
    _key = null;
  }
}

/// Fake secure storage: only read/write/delete are used by SecureKeyStore.
final class _FakeSecure implements FlutterSecureStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data.remove(key);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

Uint8List _wav([int samples = 4000]) {
  final data = Uint8List(44 + samples * 2);
  final b = ByteData.sublistView(data);
  data.setAll(0, 'RIFF'.codeUnits);
  b.setUint32(4, data.length - 8, Endian.little);
  data.setAll(8, 'WAVEfmt '.codeUnits);
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 16000, Endian.little);
  b.setUint32(28, 32000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  data.setAll(36, 'data'.codeUnits);
  b.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    b.setInt16(44 + i * 2, (i * 37) % 20000 - 10000, Endian.little);
  }
  return data;
}

bool _hasAscii(Uint8List bytes, String s) {
  final n = s.codeUnits;
  for (var i = 0; i + n.length <= bytes.length; i++) {
    var ok = true;
    for (var j = 0; j < n.length; j++) {
      if (bytes[i + j] != n[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

Matcher _failsWith(TakeStoreError kind) =>
    throwsA(isA<TakeStoreException>().having((e) => e.kind, 'kind', kind));

void main() {
  late Directory root;
  late MemoryKeyStore keys;
  late EncryptedTakeStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ost08b_');
    keys = MemoryKeyStore();
    store = EncryptedTakeStore(directory: root, keys: keys);
  });
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  File fileOf(String id) => File('${root.path}/$id.take');

  test('round trip returns the exact WAV bytes', () async {
    final wav = _wav();
    await store.put('take-1', wav);
    expect(await store.read('take-1'), orderedEquals(wav));
    expect(await store.ids(), ['take-1']);
  });

  test('stored file is not plain WAV and holds no plaintext marker', () async {
    final wav = _wav();
    await store.put('take-1', wav);
    final raw = await fileOf('take-1').readAsBytes();
    expect(String.fromCharCodes(raw.sublist(0, 4)), isNot('RIFF'));
    expect(_hasAscii(raw, 'RIFF'), isFalse);
    expect(_hasAscii(raw, 'WAVEfmt '), isFalse);
    // header: 1 version + 12 nonce + 16 mac, then ciphertext of equal length.
    expect(raw.length, 1 + 12 + 16 + wav.length);
    // nothing else (no temp or plain sibling) is left in the directory.
    expect(root.listSync().map((e) => e.path.split('/').last), ['take-1.take']);
  });

  test('same data twice gives different bytes (fresh nonce)', () async {
    final wav = _wav();
    await store.put('a', wav);
    await store.put('b', wav);
    final a = await fileOf('a').readAsBytes();
    final b = await fileOf('b').readAsBytes();
    expect(a.sublist(1, 13), isNot(orderedEquals(b.sublist(1, 13))));
    expect(a, isNot(orderedEquals(b)));
  });

  for (final entry in {
    'version': 0,
    'nonce': 5,
    'mac': 20,
    'ciphertext': 100,
    'last byte': -1,
  }.entries) {
    test('one changed byte in ${entry.key} fails to decrypt', () async {
      await store.put('t', _wav());
      final f = fileOf('t');
      final raw = await f.readAsBytes();
      final i = entry.value < 0 ? raw.length - 1 : entry.value;
      raw[i] ^= 0x01;
      await f.writeAsBytes(raw);
      await expectLater(store.read('t'), throwsA(isA<TakeStoreException>()));
    });
  }

  test('truncated file is a clear corrupt error', () async {
    await store.put('t', _wav());
    await fileOf('t').writeAsBytes(Uint8List(10));
    await expectLater(store.read('t'), _failsWith(TakeStoreError.corrupt));
  });

  test('a file renamed to another id does not decrypt (id is bound)', () async {
    await store.put('one', _wav());
    await fileOf('one').rename(fileOf('two').path);
    await expectLater(store.read('two'), _failsWith(TakeStoreError.corrupt));
  });

  test('wrong key fails to decrypt', () async {
    await store.put('t', _wav());
    final otherKeys = MemoryKeyStore();
    await otherKeys.create();
    final other = EncryptedTakeStore(directory: root, keys: otherKeys);
    await expectLater(other.read('t'), _failsWith(TakeStoreError.corrupt));
  });

  test('missing key is reported as keyMissing, not as data', () async {
    await store.put('t', _wav());
    await keys.delete();
    await expectLater(store.read('t'), _failsWith(TakeStoreError.keyMissing));
  });

  test('delete removes the file; reading it afterwards is notFound', () async {
    await store.put('t', _wav());
    expect(fileOf('t').existsSync(), isTrue);
    expect(await store.delete('t'), isTrue);
    expect(fileOf('t').existsSync(), isFalse);
    expect(await store.delete('t'), isFalse);
    await expectLater(store.read('t'), _failsWith(TakeStoreError.notFound));
  });

  test('deleteAll destroys the key: old bytes can no longer be read', () async {
    await store.put('a', _wav());
    await store.put('b', _wav(100));
    final saved = await fileOf('a').readAsBytes();
    await store.deleteAll();
    expect(keys.deletes, 1);
    expect(await keys.read(), isNull);
    expect(root.listSync().where((e) => e.path.endsWith('.take')), isEmpty);
    // Restore a copy of the old ciphertext (e.g. from a backup): still dead.
    await fileOf('a').writeAsBytes(saved);
    await expectLater(store.read('a'), _failsWith(TakeStoreError.keyMissing));
    // The store keeps working with a brand-new key afterwards.
    await store.put('c', _wav(10));
    expect(await store.read('c'), orderedEquals(_wav(10)));
    await expectLater(store.read('a'), _failsWith(TakeStoreError.corrupt));
  });

  test('exportTo writes the decrypted WAV only on explicit call', () async {
    final wav = _wav();
    await store.put('t', wav);
    final target = File('${root.path}/out/my-take.wav');
    expect(target.existsSync(), isFalse);
    final out = await store.exportTo('t', target);
    expect(out.path, target.path);
    final bytes = await out.readAsBytes();
    expect(bytes, orderedEquals(wav));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  });

  test('exportTo of a tampered take throws and leaves no target', () async {
    await store.put('t', _wav());
    final raw = await fileOf('t').readAsBytes();
    raw[50] ^= 0xff;
    await fileOf('t').writeAsBytes(raw);
    final target = File('${root.path}/out.wav');
    await expectLater(
      store.exportTo('t', target),
      throwsA(isA<TakeStoreException>()),
    );
    expect(target.existsSync(), isFalse);
  });

  test('unsafe ids are rejected (no path traversal)', () async {
    for (final bad in ['', '../x', 'a/b', r'a\b', '.hidden', 'x' * 65]) {
      await expectLater(
        store.put(bad, _wav(1)),
        _failsWith(TakeStoreError.invalidId),
        reason: 'id "$bad"',
      );
    }
    expect(root.listSync(), isEmpty);
  });

  test('keys are 256-bit and random per generation', () {
    final a = generateKeyBytes();
    final b = generateKeyBytes();
    expect(a.length, 32);
    expect(a, isNot(orderedEquals(b)));
  });

  test('regression: persistent archive is still denied for everyone', () {
    for (final audience in RetentionAudience.values) {
      for (final consent in [false, true]) {
        expect(
          RecordingRetentionPolicy.decide(
            purpose: RecordingPurpose.persistentArchive,
            audience: audience,
            explicitStorageConsent: consent,
          ),
          RetentionDecision.denied,
          reason: '$audience consent=$consent',
        );
      }
    }
  });

  test(
    'tripwire: the store is referenced in lib/ only by its own two files',
    () {
      // Wiring it up is a separate ticket that must re-measure every
      // "audio is not saved" claim first (Motion decision 2026-11-14); update
      // this allowlist deliberately there.
      const allowed = {
        'lib/app/practice/own_recording/encrypted_take_store.dart',
        'lib/app/practice/own_recording/secure_key_store.dart',
      };
      final ref = RegExp(r'\b(EncryptedTakeStore|SecureKeyStore)\b');
      final hits = <String>{
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              ref.hasMatch(f.readAsStringSync()))
            f.path,
      };
      expect(hits, allowed);
    },
  );

  test('concurrent first puts share ONE key (no lost-key race)', () async {
    await Future.wait([
      for (var n = 0; n < 6; n++) store.put('t$n', _wav(200 + n)),
    ]);
    for (var n = 0; n < 6; n++) {
      expect(await store.read('t$n'), orderedEquals(_wav(200 + n)));
    }
  });

  test('concurrent puts of the same id do not clash on a temp file', () async {
    await Future.wait([
      for (var n = 0; n < 6; n++) store.put('same', _wav(300 + n)),
    ]);
    final back = await store.read('same');
    expect([
      for (var n = 0; n < 6; n++) _wav(300 + n).length,
    ], contains(back.length));
    expect(await store.ids(), ['same']);
    expect(root.listSync().length, 1, reason: 'no stray temp files');
  });

  test('put then deleteAll (concurrent) leaves no orphan take', () async {
    final p = store.put('a', _wav(500));
    final d = store.deleteAll();
    await Future.wait([p, d]);
    expect(await store.ids(), isEmpty);
    expect(await keys.read(), isNull);
  });

  test('deleteAll then put (concurrent) leaves a readable take', () async {
    await store.put('old', _wav(10));
    final d = store.deleteAll();
    final p = store.put('new', _wav(20));
    await Future.wait([d, p]);
    expect(await store.ids(), ['new']);
    expect(await store.read('new'), orderedEquals(_wav(20)));
  });

  test('delete(id) also removes leftover temp files of that id', () async {
    await store.put('t', _wav(10));
    final stray1 = File('${root.path}/t.take.abc123.tmp')
      ..writeAsStringSync('x');
    final stray2 = File('${root.path}/t.take.tmp')..writeAsStringSync('x');
    final other = File('${root.path}/u.take.zzz.tmp')..writeAsStringSync('x');
    expect(await store.delete('t'), isTrue);
    expect(stray1.existsSync(), isFalse);
    expect(stray2.existsSync(), isFalse);
    expect(other.existsSync(), isTrue, reason: 'other ids are untouched');
  });

  test('android backup rules exclude every real flutter_secure_storage file', () {
    // Names verified in flutter_secure_storage 11.2.0 android sources:
    // data FlutterSecureStorage, wrapped key FlutterSecureKeyStorage
    // (FlutterSecureStorageConfig.java), config FlutterSecureStorageConfiguration
    // (NamespacedConfigSource.java).
    const prefs = [
      'FlutterSecureStorage.xml',
      'FlutterSecureKeyStorage.xml',
      'FlutterSecureStorageConfiguration.xml',
    ];
    String read(String f) =>
        File('android/app/src/main/res/xml/$f').readAsStringSync();
    bool excludes(String xml, String domain, String path) => RegExp(
      '<exclude\\s+domain="$domain"\\s+path="${RegExp.escape(path)}"\\s*/>',
    ).hasMatch(xml);

    final full = read('backup_rules.xml');
    final ext = read('data_extraction_rules.xml');
    final cloud = RegExp(
      r'<cloud-backup>([\s\S]*?)</cloud-backup>',
    ).firstMatch(ext)!.group(1)!;
    final transfer = RegExp(
      r'<device-transfer>([\s\S]*?)</device-transfer>',
    ).firstMatch(ext)!.group(1)!;
    for (final p in prefs) {
      expect(
        excludes(full, 'sharedpref', p),
        isTrue,
        reason: 'backup_rules $p',
      );
      expect(excludes(cloud, 'sharedpref', p), isTrue, reason: 'cloud $p');
      expect(
        excludes(transfer, 'sharedpref', p),
        isTrue,
        reason: 'transfer $p',
      );
    }
    for (final x in [full, cloud, transfer]) {
      expect(excludes(x, 'file', 'encrypted_takes/'), isTrue);
    }
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('@xml/backup_rules'));
    expect(manifest, contains('@xml/data_extraction_rules'));
  });

  group('SecureKeyStore', () {
    test('create then read returns the same 32-byte key', () async {
      final fake = _FakeSecure();
      final ks = SecureKeyStore(storage: fake);
      expect(await ks.read(), isNull);
      final k = await ks.create();
      expect(k.length, 32);
      expect(await ks.read(), orderedEquals(k));
      await ks.delete();
      expect(await ks.read(), isNull);
    });

    for (final bad in {
      'wrong length': 'AAAA',
      'not base64': '%%%not-base64%%%',
    }.entries) {
      test(
        'stored value with ${bad.key} throws corrupt and is not replaced',
        () async {
          final fake = _FakeSecure()..data[SecureKeyStore.keyName] = bad.value;
          final ks = SecureKeyStore(storage: fake);
          await expectLater(ks.read(), _failsWith(TakeStoreError.corrupt));
          // put() must NOT silently mint a fresh key over the bad one.
          final st = EncryptedTakeStore(directory: root, keys: ks);
          await expectLater(
            st.put('t', _wav(5)),
            _failsWith(TakeStoreError.corrupt),
          );
          expect(fake.data[SecureKeyStore.keyName], bad.value);
          expect(root.listSync(), isEmpty);
          // read() with a bad key is an error too, never keyMissing/data.
          await expectLater(st.read('t'), throwsA(isA<TakeStoreException>()));
        },
      );
    }
  });

  group('exportTo', () {
    test('refuses to overwrite an existing target by default', () async {
      await store.put('t', _wav(50));
      final target = File('${root.path}/out.wav')..writeAsStringSync('mine');
      await expectLater(
        store.exportTo('t', target),
        _failsWith(TakeStoreError.targetExists),
      );
      expect(target.readAsStringSync(), 'mine');
    });

    test('overwrite: true replaces it atomically with the WAV', () async {
      await store.put('t', _wav(50));
      final target = File('${root.path}/out.wav')..writeAsStringSync('mine');
      await store.exportTo('t', target, overwrite: true);
      expect(await target.readAsBytes(), orderedEquals(_wav(50)));
    });

    test(
      'leaves no temp file next to the target on success or failure',
      () async {
        await store.put('t', _wav(50));
        final dir = Directory('${root.path}/exp')..createSync();
        await store.exportTo('t', File('${dir.path}/a.wav'));
        expect(dir.listSync().map((e) => e.path.split('/').last), ['a.wav']);
        // failure: target path is a directory, so the final rename fails.
        final blocker = Directory('${dir.path}/b.wav')..createSync();
        await expectLater(
          store.exportTo('t', File(blocker.path), overwrite: true),
          throwsA(anything),
        );
        expect(dir.listSync().map((e) => e.path.split('/').last).toSet(), {
          'a.wav',
          'b.wav',
        });
      },
    );
  });
}
