import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import '../ui_copy.dart';
import 'parental_consent_controller.dart';
import 'parental_consent_copy.dart';

/// Under-13 parent-approval screen (ADR-008 §3). Reached only from Core's
/// `onUnderThirteen` hand-off, which exists only while
/// `ostinatoParentalConsentEnabled` is true. No raw audio or video is touched.
class ParentalConsentPage extends StatefulWidget {
  const ParentalConsentPage({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
    this.countryCode,
  });

  final ParentalConsentController controller;
  final DateTime Function() clock;

  /// Test hook; null reads the device region (upper-case alpha-2 only).
  final String? countryCode;

  @override
  State<ParentalConsentPage> createState() => _ParentalConsentPageState();
}

class _ParentalConsentPageState extends State<ParentalConsentPage> {
  final _parentEmail = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int? _month;
  int? _year;

  ParentalConsentController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _c.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _parentEmail.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _country() {
    final raw =
        widget.countryCode ??
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final upper = raw?.toUpperCase();
    return upper != null && RegExp(r'^[A-Z]{2}$').hasMatch(upper)
        ? upper
        : null;
  }

  Future<void> _create() async {
    final year = _year;
    final month = _month;
    if (year == null || month == null) return;
    // Only an under-13 declaration belongs to this path.
    if (MotionAgePolicy.ageOn(year, month, widget.clock()) >=
        MotionAgePolicy.minimumAge) {
      return;
    }
    final ok = await _c.createAccount(
      email: _email.text,
      password: _password.text,
      age: MotionAgeDeclaration(
        birthYear: year,
        birthMonth: month,
        countryCode: _country(),
        policyVersion: MotionAgePolicy.version,
      ),
    );
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final core = MotionAccountLocalizations.of(context);
    String t(MotionAccountString key) => core.text(key);
    final phase = _c.phase;
    final noticeText = switch (_c.notice) {
      ConsentNotice.none => null,
      ConsentNotice.tooSoon => t(MotionAccountString.consentTooSoon),
      ConsentNotice.dailyLimit => uiText(
        context,
        ParentalConsentCopy.dailyLimit,
      ),
      ConsentNotice.invalidEmail => t(MotionAccountString.consentEmailInvalid),
      ConsentNotice.unavailable => uiText(
        context,
        ParentalConsentCopy.unavailable,
      ),
    };
    final now = widget.clock();
    final children = <Widget>[
      if (phase == ConsentPhase.loading || _c.busy)
        const LinearProgressIndicator(),
      if (phase == ConsentPhase.needParentEmail ||
          phase == ConsentPhase.expired ||
          phase == ConsentPhase.pending) ...[
        Text(t(MotionAccountString.parentalConsentNeeded)),
        const SizedBox(height: 12),
        if (phase == ConsentPhase.expired)
          Text(t(MotionAccountString.consentExpired)),
        if (phase == ConsentPhase.pending)
          Text(t(MotionAccountString.consentPending)),
        const SizedBox(height: 12),
        TextField(
          controller: _parentEmail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: t(MotionAccountString.parentEmail),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _c.busy
              ? null
              : () => _c.sendParentEmail(_parentEmail.text),
          child: Text(t(MotionAccountString.sendConsentRequest)),
        ),
        if (phase == ConsentPhase.pending)
          TextButton(
            onPressed: _c.busy ? null : _c.refresh,
            child: Text(uiText(context, ParentalConsentCopy.checkApproval)),
          ),
      ],
      if (phase == ConsentPhase.unavailable) ...[
        Text(uiText(context, ParentalConsentCopy.unavailable)),
        TextButton(
          onPressed: _c.busy ? null : _c.refresh,
          child: Text(t(MotionAccountString.retry)),
        ),
      ],
      if (phase == ConsentPhase.denied)
        Text(uiText(context, ParentalConsentCopy.denied)),
      if (phase == ConsentPhase.approved) ...[
        Text(uiText(context, ParentalConsentCopy.approved)),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: t(MotionAccountString.email)),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: t(MotionAccountString.password),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: _month,
          decoration: InputDecoration(
            labelText: t(MotionAccountString.birthMonth),
          ),
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text('$m')),
          ],
          onChanged: (v) => setState(() => _month = v),
        ),
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: InputDecoration(
            labelText: t(MotionAccountString.birthYear),
          ),
          items: [
            for (var y = now.year; y >= now.year - 12; y--)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (v) => setState(() => _year = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _c.busy ? null : _create,
          child: Text(t(MotionAccountString.createAccount)),
        ),
      ],
      if (noticeText != null) ...[
        const SizedBox(height: 12),
        Text(noticeText, key: const ValueKey('consent-notice')),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t(MotionAccountString.accountTitle))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    );
  }
}
