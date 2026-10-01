# Opt-in Guitar Note Observation

Founder scope: on-device, optional microphone use during guitar practice;
raw audio is never stored or uploaded. Parent approved implementation after
the full native/controller audit. Shared Core, paid/posture/scored gates,
workflow WIP, providers, Vault, commits and pushes are excluded. Root owns
local store listing drafts and all simulator operations.

## Product contract

- A separate course practice route displays an approximate observed note,
  frequency and cents relative to the nearest equal-tempered note center.
  It has no target match, tuning-success, chord, mastery or health verdict.
- No reliable observation means no numeric result. A conservative additional
  harmonic-family residual guard rejects conflicting spectral energy; it
  cannot prove that every harmonic/octave mixture is monophonic.
- The v1 GuitarSet note gate evidence is studio/isolated-note evidence only.
  A short visible notice states that real-phone validation is open.
- Every guitar lesson remains usable and completable without a microphone.
  Results never enter course progress or account/session history.
- Start requests permission after an explicit user action. Stop, route exit,
  account change and loss of foreground close capture and clear result/RAM.
  Foreground return never automatically restarts listening.

## Audit findings to resolve

- iOS capture file is referenced but absent from Sources. Both native audio
  method/event channels are unregistered; microphone declarations and iOS
  permission-handler macro are absent.
- Controller dispose does not stop capture; inactive/hidden handling, late
  permission/start cancellation, sample-rate change and stale-result handling
  are absent. Initial route and native read-failure events are incomplete.
- iOS tap events need main-thread dispatch and stale-session guards. Android
  capture needs guarded start/read failures, actual rate/route events and
  generation checks for queued chunks. Event cancellation must stop native
  capture as well as remove a listener.

## Implementation sequence

1. Add cancellation/lifecycle/stop-dispose tests; harden Dart source/channel.
2. Separate target-free observation from existing single-note evaluation;
   add finite/clipping and harmonic-residual refusal tests with original
   synthetic fixtures. Keep the original evaluator/config semantics intact.
3. Add a bounded RAM-only practice controller: quiet-room calibration,
   sample/route validation, one DSP task at a time, stale-result timeout and
   complete stop clearing. Use an isolate for actual DSP work.
4. Register and retain native channels; add iOS Sources and permissions;
   harden foreground/interrupt/cancel/queued-buffer behavior on both platforms.
5. Add a themed opt-in screen and course entry, permission/no-result states,
   physical-device limitation notice and accurate app privacy copy. Store
   metadata is updated by root, not this writer.
6. Run focused/full audio and Flutter tests/analyze; native compile without
   booting a simulator. Preserve exact receipts for any new licensed replay
   downloads and delete only those downloads after evaluation.

## Open physical acceptance

Fake channels and a successful native build do not prove live microphone
behavior. Real iOS/Android permission indicator, background/stop cleanup,
sample-rate/routes, external tuner comparison, quiet/noisy rooms and multi
source refusal remain explicit physical-phone acceptance gates. No acoustic
dB(A), timing score or automatic course completion is introduced.


## Implementation readback — 2026-09-26

Implemented the separate optional course observer and source/native lifecycle.
The prior-free base evaluator keeps its offline API; the production screen only
consumes target-free observations. New synthetic refusal checks exposed a
subharmonic mixture, so a fundamental-power refusal was frozen before real replay
performance was examined. Players00/01 development21/38 accepted,0wrong;
previously unused players04/05 holdout50/52 accepted,0wrong; median2.254cents and
p906.960cents among accepted holdout notes. No learned model was trained, and the
52 studio candidates are not representative phone/novice/chord evidence.

All198 Flutter tests and124 audio package tests pass; both analyses are clean.
Source and observer regression checks cover delayed permission/ready/start,
old-owner and delayed-subscription stop/restart, real Flutter lifecycle events,
account change, stale/busy/late DSP refusal, denial, route change and dispose.
Independent review closed6 concrete findings with20app+13DSP+1external probe.
Native source membership, permission declarations and channels compile on root's
serial iOS/Android builds; native integration retry includes a built-in iOS enum
route normalization followup. The native course test uses an isolated test-owner
support directory and only prepare/stop; it never asks permission or opens capture.

The second licensed replay downloaded16files/29,334,966bytes; all hashes/sizes were
verified and all16 exact downloads deleted. The receipt and results remain in the
owned scratch path. The original16files/29,542,721bytes also remain deleted.
Full implementation evidence: `docs/evidence/production-line/guitar-note-observation-2026-09-26.json`.
Root's serial native course/bridge test passed on both platforms:
iOS19.3s build/4s test and Android13.1s build/6s test. It loads the actual
60-lesson bundle, writes viewed/practiced/self-report metadata through native
path_provider in an isolated test UUID owner, recreates the route and reads disk
progress. Event-channel prepare/ready/stop also passes with zero PCM and no
permission request. This accepts native course persistence and bridge registration;
physical microphone behavior remains open.
