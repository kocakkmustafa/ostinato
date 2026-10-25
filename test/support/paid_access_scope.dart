import 'package:flutter/widgets.dart';
import 'package:ostinato/app/account_connection.dart';

/// Records every paid-lesson admission and answers with a fixed membership
/// result. The product guard decides only free vs paid; this stands in for
/// Core's sign-in + server membership check so course walks can reach paid
/// lessons (member) or prove they stay closed (non-member).
final class PaidAccessProbe {
  PaidAccessProbe({this.member = true});

  bool member;
  int calls = 0;
  final ValueNotifier<String?> userId = ValueNotifier<String?>(
    'synthetic-member',
  );

  Widget wrap(Widget child) => AccountScope(
    connection: AccountConnection(
      userId: userId,
      pageBuilder: (_) => const SizedBox.shrink(),
      requirePaidAccess: (_) async {
        calls++;
        return member;
      },
    ),
    currentUserId: userId.value,
    child: child,
  );

  void dispose() => userId.dispose();
}
