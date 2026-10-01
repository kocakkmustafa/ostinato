import 'dart:io';

final RegExp _canonicalAccountUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Keeps local history under the signed-in Motion identity. A null identity
/// retains the pre-account local path; it is never silently assigned to a new
/// user. Supabase user IDs are UUIDs, so rejecting any other path segment also
/// prevents traversal if a caller supplies a malformed ID.
Directory accountDataDirectory(Directory root, String? accountUserId) {
  if (accountUserId == null) return root;
  final valid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (!valid.hasMatch(accountUserId)) {
    throw ArgumentError.value(accountUserId, 'accountUserId', 'Expected UUID');
  }
  return Directory('${root.path}/accounts/${accountUserId.toLowerCase()}');
}

/// Lists only canonical account directories created by this app. Links and
/// unrelated files are never offered to the shared deletion-receipt check.
Future<List<String>> localAccountIds(Directory root) async {
  final accounts = Directory('${root.path}/accounts');
  if (await FileSystemEntity.type(accounts.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return <String>[];
  }
  final ids = <String>[];
  await for (final entry in accounts.list(followLinks: false)) {
    if (entry is! Directory) continue;
    final name = entry.path.substring(accounts.path.length + 1);
    if (_canonicalAccountUuid.hasMatch(name)) ids.add(name);
  }
  return ids..sort();
}

/// Called only after verified common-account deletion, with the user ID
/// captured before remote sign-out. Sign-out and switching keep local data.
Future<void> deleteAccountData(Directory root, String accountUserId) async {
  final directory = accountDataDirectory(root, accountUserId);
  if (await directory.exists()) await directory.delete(recursive: true);
}
