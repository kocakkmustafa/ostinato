import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../ui_copy.dart';
import 'tuner_check_memory.dart';
import 'tuner_copy.dart';
import 'tunings.dart';

enum SessionTuningGateState { unchecked, untuned, tuned, continued }

/// Pure gate decision from today's tuner result (RAM only).
SessionTuningGateState sessionTuningGateState(TunerCheckMemory memory) {
  final check = memory.today;
  if (check == null) {
    return memory.continuedWithoutTuning
        ? SessionTuningGateState.continued
        : SessionTuningGateState.unchecked;
  }
  return check.allInTune
      ? SessionTuningGateState.tuned
      : SessionTuningGateState.untuned;
}

/// Session-start tuning gate (F4.1, §6.4): "[Tune] [Continue anyway]".
/// It never blocks: continuing is always possible, and it never closes the
/// tuner on its own. It sits next to, and does not change, the existing
/// held-note tuning check of the note observer.
class SessionTuningGateCard extends StatefulWidget {
  const SessionTuningGateCard({
    super.key,
    this.preset = TuningPresets.guitarStandard,
    this.memory,
    this.onTune,
  });

  final TuningPreset preset;
  final TunerCheckMemory? memory;

  /// Opens the tuner; defaults to [openTuner] via the caller. Injected so
  /// the setup wizard (F4.2) or tests can route elsewhere.
  final Future<void> Function(BuildContext context)? onTune;

  @override
  State<SessionTuningGateCard> createState() => _SessionTuningGateCardState();
}

class _SessionTuningGateCardState extends State<SessionTuningGateCard> {
  late final TunerCheckMemory _memory =
      widget.memory ?? TunerCheckMemory.instance;

  @override
  void initState() {
    super.initState();
    _memory.addListener(_changed);
  }

  @override
  void dispose() {
    _memory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = sessionTuningGateState(_memory);
    final check = _memory.today;
    final p = OstinatoPalette.of(context);
    final text = switch (state) {
      SessionTuningGateState.unchecked => uiText(
        context,
        TunerCopy.gateUnchecked,
      ),
      SessionTuningGateState.untuned => uiText(
        context,
        TunerCopy.gateUntuned,
        values: {
          'v0': appInteger(context, check!.notInTune),
          'v1': appInteger(context, check.total),
        },
      ),
      SessionTuningGateState.tuned => uiText(context, TunerCopy.gateTuned),
      SessionTuningGateState.continued => uiText(
        context,
        TunerCopy.gateContinued,
      ),
    };
    return GlassCard(
      key: const Key('session-tuning-gate'),
      gradientColors: p.guitar.grad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker(uiText(context, TunerCopy.gateKicker), color: p.guitar.ink),
          const SizedBox(height: 8),
          Text(
            text,
            key: const Key('session-tuning-gate-text'),
            style: hankenText(size: 13.5, height: 1.45),
          ),
          if (state != SessionTuningGateState.tuned) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  key: const Key('session-tuning-gate-tune'),
                  onPressed: widget.onTune == null
                      ? null
                      : () => widget.onTune!(context),
                  child: Text(uiText(context, TunerCopy.gateTune)),
                ),
                if (state != SessionTuningGateState.continued)
                  TextButton(
                    key: const Key('session-tuning-gate-continue'),
                    onPressed: _memory.continueWithoutTuning,
                    child: Text(uiText(context, TunerCopy.gateContinue)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
