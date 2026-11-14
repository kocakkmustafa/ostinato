import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// OST-P0-08B — encrypted on-device store for an explicitly kept take.
///
/// BUILT BUT NOT WIRED: nothing in the app calls this, and
/// `RecordingRetentionPolicy` still denies `persistentArchive`. No network;
/// raw audio is never written to disk unencrypted.
///
/// File layout (`<id>.take`): `[version:1][nonce:12][mac:16][ciphertext]`,
/// AES-256-GCM, fresh random 96-bit nonce per write, the take id bound as
/// additional authenticated data (a renamed file does not decrypt).

enum TakeStoreError {
  invalidId,
  notFound,
  keyMissing,
  corrupt,
  unsupported,
  targetExists,
}

final class TakeStoreException implements Exception {
  const TakeStoreException(this.kind, this.message);
  final TakeStoreError kind;
  final String message;
  @override
  String toString() => 'TakeStoreException(${kind.name}): $message';
}

/// Holds the 256-bit data key (Keychain/Keystore in production).
abstract interface class KeyStore {
  Future<Uint8List?> read();
  Future<Uint8List> create();
  Future<void> delete();
}

/// Fresh random 256-bit key from the platform CSPRNG.
Uint8List generateKeyBytes() {
  final rnd = SecureRandom.defaultRandom;
  return Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
}

final class EncryptedTakeStore {
  EncryptedTakeStore({required this.directory, required this.keys});

  final Directory directory;
  final KeyStore keys;

  static const int _version = 1;
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _headerLen = 1 + _nonceLen + _macLen;
  static const String _ext = '.take';
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');
  static final AesGcm _cipher = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  /// Every operation runs one at a time (key creation, temp files and
  /// deleteAll cannot interleave). In-process only.
  Future<void> _tail = Future<void>.value();
  Future<T> _serial<T>(Future<T> Function() op) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await op());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  String _tmpSuffix() =>
      '.${List<String>.generate(8, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}.tmp';

  String _checked(String id) {
    if (!_idPattern.hasMatch(id)) {
      throw const TakeStoreException(
        TakeStoreError.invalidId,
        'take id must match [A-Za-z0-9][A-Za-z0-9_-]{0,63}',
      );
    }
    return id;
  }

  File _file(String id) => File('${directory.path}/${_checked(id)}$_ext');

  List<int> _aad(String id) => utf8.encode('ostinato.take.v$_version:$id');

  /// Encrypts [wav] and stores it as [id] (replaces an existing take).
  Future<void> put(String id, Uint8List wav) => _serial(() => _put(id, wav));

  Future<void> _put(String id, Uint8List wav) async {
    final target = _file(id);
    final key = await keys.read() ?? await keys.create();
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      wav,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: _aad(id),
    );
    final out = BytesBuilder(copy: false)
      ..addByte(_version)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    await directory.create(recursive: true);
    // Only ciphertext ever touches disk, including the temp file.
    final tmp = File('${target.path}${_tmpSuffix()}');
    try {
      await tmp.writeAsBytes(out.takeBytes(), flush: true);
      await tmp.rename(target.path);
    } catch (_) {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
  }

  /// Decrypts and returns the WAV. Throws [TakeStoreException] on any
  /// missing, foreign, truncated or tampered data; never returns bad bytes.
  Future<Uint8List> read(String id) => _serial(() => _read(id));

  Future<Uint8List> _read(String id) async {
    final file = _file(id);
    if (!file.existsSync()) {
      throw TakeStoreException(TakeStoreError.notFound, 'no take "$id"');
    }
    final key = await keys.read();
    if (key == null) {
      throw const TakeStoreException(
        TakeStoreError.keyMissing,
        'encryption key is gone; stored takes cannot be read',
      );
    }
    final raw = await file.readAsBytes();
    if (raw.length < _headerLen) {
      throw TakeStoreException(TakeStoreError.corrupt, 'take "$id" truncated');
    }
    if (raw[0] != _version) {
      throw TakeStoreException(
        TakeStoreError.corrupt,
        'take "$id" has an unknown format version',
      );
    }
    final box = SecretBox(
      Uint8List.sublistView(raw, _headerLen),
      nonce: Uint8List.sublistView(raw, 1, 1 + _nonceLen),
      mac: Mac(Uint8List.sublistView(raw, 1 + _nonceLen, _headerLen)),
    );
    try {
      final plain = await _cipher.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: _aad(id),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw TakeStoreException(
        TakeStoreError.corrupt,
        'take "$id" failed authentication (tampered, wrong key or wrong id)',
      );
    }
  }

  Future<bool> delete(String id) => _serial(() async {
    final file = _file(id);
    final prefix = '$id$_ext.';
    if (directory.existsSync()) {
      for (final e in directory.listSync()) {
        final name = e.uri.pathSegments.last;
        if (e is File && name.startsWith(prefix) && name.endsWith('.tmp')) {
          await e.delete();
        }
      }
    }
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  });

  Future<List<String>> ids() async {
    if (!directory.existsSync()) return const <String>[];
    final names = <String>[
      for (final e in directory.listSync())
        if (e is File && e.path.endsWith(_ext))
          e.uri.pathSegments.last.substring(
            0,
            e.uri.pathSegments.last.length - _ext.length,
          ),
    ]..sort();
    return names;
  }

  /// Deletes the key FIRST (so even a failed file delete leaves nothing
  /// decryptable), then every take and stray temp file.
  Future<void> deleteAll() => _serial(_deleteAll);

  Future<void> _deleteAll() async {
    await keys.delete();
    if (!directory.existsSync()) return;
    for (final e in directory.listSync()) {
      if (e is File && (e.path.endsWith(_ext) || e.path.endsWith('.tmp'))) {
        await e.delete();
      }
    }
  }

  /// Explicit user export: writes the DECRYPTED WAV to [target]. Decryption
  /// completes first; the bytes go to a temp file beside the target and are
  /// renamed into place, and the temp file is removed on any failure. An
  /// existing [target] is never silently replaced: it throws
  /// [TakeStoreError.targetExists] unless [overwrite] is true.
  Future<File> exportTo(String id, File target, {bool overwrite = false}) =>
      _serial(() async {
        final wav = await _read(id);
        if (!overwrite &&
            FileSystemEntity.typeSync(target.path) !=
                FileSystemEntityType.notFound) {
          throw TakeStoreException(
            TakeStoreError.targetExists,
            'export target already exists: ${target.path}',
          );
        }
        await target.parent.create(recursive: true);
        final tmp = File('${target.path}${_tmpSuffix()}');
        try {
          await tmp.writeAsBytes(wav, flush: true);
          await tmp.rename(target.path);
        } catch (_) {
          if (tmp.existsSync()) await tmp.delete();
          rethrow;
        }
        return target;
      });
}
