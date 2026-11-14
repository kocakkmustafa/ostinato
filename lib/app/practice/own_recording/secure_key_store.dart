import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encrypted_take_store.dart';

/// Production [KeyStore]: the data key lives in the iOS Keychain / Android
/// Keystore-backed secure storage (flutter_secure_storage), never next to the
/// encrypted files. Not wired to any flow (OST-P0-08B).
final class SecureKeyStore implements KeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String keyName = 'ostinato.take_store.key.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> read() async {
    final v = await _storage.read(key: keyName);
    if (v == null) return null;
    // A present-but-unusable key is an error, never "no key": returning null
    // would let the store mint a new key and orphan every stored take.
    final Uint8List bytes;
    try {
      bytes = base64Decode(v);
    } on FormatException {
      throw const TakeStoreException(
        TakeStoreError.corrupt,
        'stored encryption key is not valid base64',
      );
    }
    if (bytes.length != 32) {
      throw const TakeStoreException(
        TakeStoreError.corrupt,
        'stored encryption key has the wrong length',
      );
    }
    return bytes;
  }

  @override
  Future<Uint8List> create() async {
    final key = generateKeyBytes();
    await _storage.write(key: keyName, value: base64Encode(key));
    return key;
  }

  @override
  Future<void> delete() => _storage.delete(key: keyName);
}
