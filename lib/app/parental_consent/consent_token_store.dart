import 'dart:convert';
import 'dart:io';

import 'package:motion_account/motion_account.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the random device wait token of the under-13 parental consent flow
/// (ADR-008 §6-6) in one small file. The token is random, belongs to no child
/// and is the ONLY thing stored: no e-mail, birth date, country or account id.
/// Core never stores it; the server keeps only its SHA-256 digest.
abstract interface class ConsentTokenStorage {
  Future<String?> read();
  Future<String> readOrCreate();
  Future<String> renew();
  Future<void> clear();

  /// Durable note that a refusal was read; kept until the permanent marker
  /// is written (the server reads a refusal out only once).
  Future<void> markDenied();
  Future<bool> deniedSeen();
}

final class ConsentTokenStore implements ConsentTokenStorage {
  const ConsentTokenStore({this.directory, this.generate});

  final Directory? directory;

  /// Test hook only; production uses `MotionDeviceConsentToken.generate`.
  final String Function()? generate;

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/ostinato.parental_consent_token.v1.json');
  }

  /// The stored token, or null when none exists or the file is unreadable or
  /// changed (a damaged token is never trusted).
  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic> &&
          value['schemaVersion'] == 1 &&
          value.keys.every(
            (k) => k == 'schemaVersion' || k == 'token' || k == 'denied',
          ) &&
          (!value.containsKey('denied') || value['denied'] == true) &&
          MotionDeviceConsentToken.isWellFormed(value['token'] as String?)) {
        return value['token'] as String;
      }
    } on Object {
      // Fall through: treated as no token.
    }
    return null;
  }

  /// Returns the stored token, creating and persisting one first if needed.
  @override
  Future<String> readOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final token = (generate ?? MotionDeviceConsentToken.generate)();
    await _write(token);
    return token;
  }

  /// Replaces the token with a fresh one (a refused token cannot be reused).
  @override
  Future<String> renew() async {
    final token = (generate ?? MotionDeviceConsentToken.generate)();
    await _write(token);
    return token;
  }

  /// Removes the token (account bound to the approval, or flow finished).
  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> markDenied() async {
    final token = await read() ?? await renew();
    await _write(token, denied: true);
  }

  @override
  Future<bool> deniedSeen() async {
    final file = await _file();
    if (!await file.exists()) return false;
    try {
      final value = jsonDecode(await file.readAsString());
      return value is Map<String, dynamic> && value['denied'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> _write(String token, {bool denied = false}) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'token': token,
        if (denied) 'denied': true,
      }),
      flush: true,
    );
    await pending.rename(file.path);
  }
}
