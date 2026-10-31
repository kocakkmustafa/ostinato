import 'package:flutter/material.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../ui_copy.dart';
import 'retention_copy.dart';
import 'weekly_goal.dart';
import 'weekly_goal_store.dart';

/// Small weekly goal card for the home screen (F5.2). Hidden while loading
/// or when the local file cannot be read: the home screen never waits on it.
class WeeklyGoalCard extends StatefulWidget {
  const WeeklyGoalCard({super.key, this.storeFactory});

  final WeeklyGoalStore Function(String? accountUserId)? storeFactory;

  @override
  State<WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<WeeklyGoalCard> {
  WeeklyGoalStore? _store;
  String? _accountId;
  WeeklyGoalStatus? _status;
  bool _busy = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    WeeklyGoalStore.revision.addListener(_reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_store == null || id != _accountId) {
      _accountId = id;
      _store =
          widget.storeFactory?.call(id) ?? WeeklyGoalStore(accountUserId: id);
      _status = null;
      _reload();
    }
  }

  @override
  void dispose() {
    WeeklyGoalStore.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final store = _store;
    if (store == null) return;
    final token = ++_loadToken;
    store.load().then(
      (status) {
        if (mounted && token == _loadToken) setState(() => _status = status);
      },
      onError: (Object _) {
        if (mounted && token == _loadToken) setState(() => _status = null);
      },
    );
  }

  Future<void> _write(
    Future<WeeklyGoalStatus> Function(WeeklyGoalStore store) action, {
    UiCopy? done,
  }) async {
    final store = _store;
    if (store == null || _busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final status = await action(store);
      if (!mounted) return;
      setState(() => _status = status);
      if (done != null) {
        messenger?.showSnackBar(SnackBar(content: Text(uiText(context, done))));
      }
    } catch (_) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text(uiText(context, RetentionCopy.saveFailed))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGoalSheet(WeeklyGoalStatus status) async {
    final rules = _store!.rules;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiText(sheet, RetentionCopy.goalTitle),
                style: hankenText(size: 18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                uiText(sheet, RetentionCopy.goalNote),
                style: hankenText(size: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var n = rules.minSessionsPerWeek;
                    n <= rules.maxSessionsPerWeek;
                    n++
                  )
                    ChoiceChip(
                      key: Key('weekly-goal-option-$n'),
                      label: Text(appInteger(sheet, n)),
                      selected: n == status.goal,
                      onSelected: (_) => Navigator.of(sheet).pop(n),
                    ),
                ],
              ),
              const Divider(height: 28),
              OutlinedButton.icon(
                key: const Key('weekly-goal-voice-rest'),
                icon: const Icon(Icons.bedtime_outlined),
                label: Text(uiText(sheet, RetentionCopy.voiceRest)),
                onPressed: () => Navigator.of(sheet).pop('rest'),
              ),
              const SizedBox(height: 6),
              Text(
                uiText(sheet, RetentionCopy.voiceRestNote),
                style: hankenText(size: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice is int && choice != status.goal) {
      await _write((s) => s.setGoal(choice));
    } else if (choice == 'rest') {
      await _write(
        (s) => s.recordVoiceRestDay(),
        done: RetentionCopy.offAppSaved,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final p = OstinatoPalette.of(context);
    final ink = p.voice.ink;
    String n(int v) => appInteger(context, v);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GlassCard(
        key: const Key('weekly-goal-card'),
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kicker(uiText(context, RetentionCopy.kicker), color: ink),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    uiText(
                      context,
                      RetentionCopy.progress,
                      values: {'v0': n(status.credit), 'v1': n(status.goal)},
                    ),
                    key: const Key('weekly-goal-progress'),
                    style: hankenText(size: 17, weight: FontWeight.w600),
                  ),
                ),
                for (var i = 0; i < status.goal; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: ExcludeSemantics(
                      child: Icon(
                        i < status.credit
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 13,
                        color: ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                status.currentWeekMet
                    ? uiText(context, RetentionCopy.met)
                    : uiText(
                        context,
                        RetentionCopy.daysLeft,
                        values: {'v0': n(status.daysLeftInWeek)},
                      ),
                if (status.streakActive) ...[
                  uiText(
                    context,
                    RetentionCopy.streak,
                    values: {'v0': n(status.streakWeeks)},
                  ),
                  uiText(
                    context,
                    RetentionCopy.freezes,
                    values: {'v0': n(status.freezesLeft)},
                  ),
                ] else
                  uiText(context, RetentionCopy.startStreak),
              ].join(' · '),
              key: const Key('weekly-goal-streak'),
              style: hankenText(size: 13, height: 1.45),
            ),
            const SizedBox(height: 6),
            Text(
              uiText(context, RetentionCopy.rules),
              style: hankenText(size: 11.5, height: 1.4, color: p.textMuted),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  key: const Key('weekly-goal-off-app'),
                  onPressed: _busy
                      ? null
                      : () => _write(
                          (s) => s.recordOffAppPractice(),
                          done: RetentionCopy.offAppSaved,
                        ),
                  child: Text(uiText(context, RetentionCopy.offApp)),
                ),
                TextButton(
                  key: const Key('weekly-goal-settings'),
                  onPressed: _busy ? null : () => _openGoalSheet(status),
                  child: Text(uiText(context, RetentionCopy.goalButton)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
