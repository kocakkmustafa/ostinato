# Guitar-TECHS independent observation evaluation

**Goal:** Evaluate the already accepted, frozen target-free guitar observer on a
second, commercially reusable corpus without changing production code or gates.

**Authorization:** Root approved this bounded implementation on 2026-09-26.
Native builds, physical devices and microphone capture remain root-owned. No
commit, push, provider, store or shared Core change is included.

## Design

Use the authors' Guitar-TECHS v1 record (Zenodo14963133, CC BY4.0), separately
from GuitarSet. P1 and P2 provide isolated notes and chords with synchronized
per-string MIDI. The source warns that audio/MIDI may be misaligned by up to
100ms. Pick one interior sustain window per listed MIDI value in each positive
recording, and the first12 distinct stable triads in one P1 chord recording,
using MIDI only, with 250ms after onset and 150ms before offset. Exclude short or overlapping
single-note labels; do not choose windows using detector output.

The production observer, configuration, and all19 independently reviewed files
remain byte-identical. MIDI is only a reference in the offline report, never a
prior supplied to the observer. Nominal MIDI cents difference is not continuous
F0 error: this corpus does not establish a calibrated continuous pitch trace.
Real chord results are a separate diagnostic, not universal polyphony rejection
or a chord recognition score. Count players, clips, input channels and windows
separately because multiple channels/windows are correlated observations.

Download only selected WAV/MIDI ZIP entries through strict HTTP206 ranges.
Reject ignored/malformed range responses before reading their body. The full
108/116MB archives and roughly1GB chord archives must never be downloaded.
Use at most64MiB peak retained task media and64MiB requested range bytes per
complete preparation attempt. Keep retry traffic separate from peak storage.
Single-note WAV entries are long (roughly53/106MB uncompressed), so hash/CRC
check them while streaming small blocks and retain only selected original-format
time crops. P1/P2 single-note micamp compressed entries plus P1 Set1major micamp
and MIDI total approximately62.4MB; full archives never enter RAM or disk.
Store temporary inputs only under
`scratch/2026-09-26-motion-device-release/note-corpus/`. Record source/version,
license/authors, exact entry/path/size/SHA256 and network bytes. Check these
before deleting only listed downloaded files; keep small JSON/text receipts.

## Steps

- [x] Record existing config and19-file review hashes, source metadata/license,
  and selected ZIP central directory entries without evaluating audio.
- [x] Add app-local corpus tool with a bounded strict-range reader, deterministic
  annotation-only selection, player/clip/channel provenance and exact receipts.
- [x] Add offline Dart replay using the unchanged `GuitarPitchObserver`; decode
  the observed WAV format explicitly, without native/plugin dependencies.
- [x] Run focused range/annotation/decoder checks and selected independent
  positive/chord replay. Report refusals, wrong notes and numeric-label limits.
- [x] Verify/delete exact downloaded files, seal result/tool/source hashes,
  check all19 reviewed files/config still match and review the narrow diff.

## Acceptance and limits

This work succeeds by producing reproducible, honest measurements, even if the
frozen observer performs poorly. There is no predetermined passing percentage
and no tuning after results. A failed clip/window remains in the report. No
learned model is trained and no physical-phone accuracy is asserted. The
existing198-test acceptance is preserved; only new offline tooling is tested.

## Measured result

Two players, two positive long recordings and34 selected windows:31 nominal
MIDI-note matches,3 refusals, zero different nominal notes. P1=14/17 accepted;
P2=17/17. A separate P1 Set1major recording provided12 stable MIDI-labelled
triad windows; all12 refused (4 notPeriodic,8 multipleSources). There is no
continuous-F0 truth, phone accuracy percentage or universal chord rejection.

Acquisition successfully requested64,556,529 range bytes (including two
bounded truncated-body retries), below64MiB. Peak retained MIDI/time-crop media
was1,038,704bytes. All49 files were SHA/size verified and deleted. The preceding
aborted transport attempt's19 files/282,338bytes were also verified/deleted;
its unlogged partialP2 network count is explicitly unknown, with an upper bound
in the preserved attempt receipt. No observer result was examined in that
aborted attempt. Whole WAV entries/archives were never retained.

Six Python range/annotation tests, five PCM/float decoder checks and Dart
analysis passed. All19 reviewed files, four DSP sources and the configuration
still match the pre-data freeze. A post-replay loader-only maintenance change
made network-journal writing explicit so isolated unit tests cannot overwrite
acquisition evidence; that old/new tool hash is declared in the report. Data
selection, replay and production DSP were unchanged.

Evidence: `docs/evidence/production-line/guitar-techs-independent-observation-2026-09-26.json`.
Small receipts/manifests/results/logs remain in the owned task scratch directory.
