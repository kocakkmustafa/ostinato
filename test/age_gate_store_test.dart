import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/age_gate_store.dart';

// Product AgeGateStore against a synthetic directory with real File IO.
void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ostinato_age_gate_'));
  tearDown(() => root.deleteSync(recursive: true));

  File marker() => File('${root.path}/ostinato.age_gate.v1.json');

  test('no marker means sign-up is not blocked', () async {
    expect(await AgeGateStore(directory: root).read(), isFalse);
  });

  test('an under-13 result persists across a new store instance', () async {
    await AgeGateStore(directory: root).markBlocked();
    expect(await AgeGateStore(directory: root).read(), isTrue);
    expect(
      await marker().readAsString(),
      '{"schemaVersion":1,"blocked":true}',
      reason: 'only the fixed fact is written, no birth data or account',
    );
    expect(File('${marker().path}.tmp').existsSync(), isFalse);
  });

  test('an unreadable or changed marker stays blocked', () async {
    for (final bytes in [
      '{broken',
      '{"schemaVersion":2,"blocked":false}',
      '[]',
      '{"schemaVersion":1}',
    ]) {
      marker().writeAsStringSync(bytes);
      expect(await AgeGateStore(directory: root).read(), isTrue, reason: bytes);
    }
  });
}
