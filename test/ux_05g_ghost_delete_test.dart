// OST-UX-05g Faz C (U): the Ghost file follows the account's data deletion
// path (`deleteAccountData`, lib/app/account_data_directory.dart), like the
// practice progress store.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

const _a = '11111111-2222-4333-8444-555555555555';
const _b = '66666666-7777-4888-8999-aaaaaaaaaaaa';
const _state = GhostState(
  level: GhostLevel.recall,
  validRuns: 2,
  lastRun: GhostLastRun.counted,
);

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ghost05g-del'));
  tearDown(() => root.deleteSync(recursive: true));

  FileGhostStore storeOf(String? id) =>
      FileGhostStore(directoryProvider: () async => root, accountUserId: id);

  test(
    '05g-C: dosya hesap klasorunde (accounts/<uuid>/ghost-screen.v1.json)',
    () async {
      await storeOf(_a).save(_state);
      expect(
        File('${root.path}/accounts/$_a/ghost-screen.v1.json').existsSync(),
        isTrue,
      );
      expect(File('${root.path}/ghost-screen.v1.json').existsSync(), isFalse);
    },
  );

  test('05g-C: hesap silme sonrasi basamak ve sayac sifirlanir', () async {
    await storeOf(_a).save(_state);
    expect(
      (await storeOf(_a).load()).level,
      GhostLevel.recall,
      reason: 'kontrol',
    );
    await deleteAccountData(root, _a);
    final after = await storeOf(_a).load();
    expect((after.level, after.validRuns), (GhostLevel.learn, 0));
    expect(Directory('${root.path}/accounts/$_a').existsSync(), isFalse);
  });

  test(
    '05g-C: baska hesabin Hayaleti silinmez; hesapsiz yol eski yerinde',
    () async {
      await storeOf(_a).save(_state);
      await storeOf(_b).save(_state);
      await storeOf(null).save(_state);
      await deleteAccountData(root, _a);
      expect((await storeOf(_b).load()).level, GhostLevel.recall);
      expect((await storeOf(null).load()).level, GhostLevel.recall);
      expect(File('${root.path}/ghost-screen.v1.json').existsSync(), isTrue);
    },
  );
}
