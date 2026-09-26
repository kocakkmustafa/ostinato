# Guitar Single-Note Evidence Implementation Plan

> **For agentic workers:** Implement the tasks below in order and mark their evidence in the final report. The founder authorized this bounded implementation but did not authorize commits, pushes, signed builds, or native microphone activation.

**Goal:** Add a reproducible, conservative guitar single-note evaluator and measure it on licensed real guitar recordings with player-disjoint development and holdout sets.

**Architecture:** Keep the existing `YinPitchSource` and `AudioConfidenceGate` as the signal primitives. Add a guitar-specific decision wrapper that analyzes one isolated note without `expectedHzPrior`, rejects insufficient or unstable windows, and reports pitch only when the observed octave and note are supported. A separate replay tool downloads GuitarSet mono microphone recordings and JAMS labels into the task scratch directory, derives isolated monophonic note windows, and emits counts and errors without persisting audio in the application.

**Tech Stack:** Dart package `ostinato_audio`, Dart `test`, Python 3 standard-library HTTP Range/ZIP reader, GuitarSet 1.1.0 (`CC-BY-4.0`, Zenodo record 3371780).

**Initial model-evidence scope (extended by Task 5):** No Flutter UI, manifest/Info.plist microphone permission, native streamer, chord grading, shared `motion-core`, workflow, other apps, provider, or store change. Preserve the existing `.github/workflows/checks.yml` WIP.

---

## Design and acceptance contract

- The result is `observed` only for stable, single-note, sufficiently audible windows. It includes measured frequency, named note/octave, signed cents from the target, and accepted-window coverage. `rejected` includes a reason and no correctness score.
- A target note may select a range and final comparison, but the YIN `expectedHzPrior` octave snap is forbidden for correctness decisions: a played E3 cannot count as E2. An octave ambiguity is rejected.
- The existing gate's dB values are **dBFS**, never environmental dB(A). This stage makes no hearing-exposure or posture judgment.
- Dataset split is by GuitarSet player ID: `00` and `01` development; `02` and `03` holdout. Two fixed solo takes per player are selected before running the evaluator. No training occurs. Any gate threshold adjustment uses only development players; holdout is read once for final evidence.
- Report candidate notes, exclusion reasons, accepted notes, wrong note/octave calls, absolute cents median/p90, and coverage per split and player. A zero/low sample count cannot silently become a pass.
- Dataset WAV/JAMS downloads go only under `scratch/2026-09-26-motion-courses/ostinato`, remain below 1 GiB, and are removed only after a path/size/SHA-256/license receipt is written. The receipt and aggregate report remain; no recordings enter Git.
- This stage does not authorize a user-facing correctness promise. Physical iOS/Android recording and independent player/device holdout are separate gates.

## Task 1: Isolated-note replay corpus

**Files:** Create `tool/guitar_single_note_corpus.py`; create task scratch receipt/report at runtime.

- [x] Reuse the repo's proven `HttpRangeFile` to fetch eight named GuitarSet solo WAV/JAMS pairs into the task scratch path. Check Zenodo's `cc-by-4.0` metadata and hash every entry. Abort if accumulated download size approaches 1 GiB.
- [x] Derive labeled windows from the six `note_midi` JAMS streams only when exactly one note overlaps the full analysis interval; reject boundary/overlap/short/out-of-range events with named reasons. Keep source player and recording identity in a JSON manifest.
- [x] Verify that no source player or recording appears in both sets. Inspect actual candidate counts before evaluator changes.

## Task 2: Single-note evaluator

**Files:** Create `packages/ostinato_audio/lib/src/pitch/guitar_single_note_evaluator.dart`; export it from `packages/ostinato_audio/lib/ostinato_audio.dart`; create `packages/ostinato_audio/test/guitar_single_note_evaluator_test.dart`.

- [x] Write focused failing tests for a clean expected note, one-semitone error, octave-high impostor, weak signal, white noise, attack/transition, and disagreeing windows. Every rejected case must have no correctness verdict.
- [x] Implement the smallest wrapper over prior-free YIN and the existing confidence gate. Require repeated compatible observations; a single lucky window cannot pass. Compare octave explicitly and keep diagnostic measurements separate from the pass decision.
- [x] Run `dart test test/guitar_single_note_evaluator_test.dart` from `packages/ostinato_audio` and the package's full `dart test` suite.

## Task 3: Fixed-configuration replay and evidence

**Files:** Create `tool/guitar_single_note_replay.dart`; create `docs/evidence/production-line/guitar-single-note-gate-2026-09-26.json`.

- [x] Replay development players first and record every decision. If thresholds require adjustment, write the new values and justification before opening holdout output.
- [x] Replay holdout players once using the frozen configuration. Report error and refusal rates with denominators, per-player variation, and dataset mismatch (studio mono mic versus real phone).
- [x] Keep the app-local evidence JSON aggregate-only: source URLs/license/hashes, selection recipe, split IDs, configuration, counts, errors, limitations. It must contain no PCM or raw audio.

## Task 4: Verify and clean

**Files:** Only files above plus the scratch receipt.

- [x] Run `dart format` on changed Dart files, `dart analyze` and focused/full audio tests. Run `git diff --check` and inspect `git status --short` to confirm the workflow WIP is untouched.
- [x] Write the exact path/size/hash/license receipt for every downloaded file; delete only those exact downloads after replay, then record their absence. Leave the scratch receipt and aggregate report.
- [x] Report truthful gate state. Even good replay numbers do not enable microphone permission, native capture, chord grading, or store claims.

## Task 5: Complete guitar learning path (founder follow-up)

**Files:** `assets/content/guitar_journey.v1.json`, `lib/app/guitar_journey.dart`, `lib/app/guitar_journey_progress.dart`, `lib/app/screens/guitar_journey_screen.dart`, `lib/app/screens/instrument_screen.dart`, `pubspec.yaml`, focused tests and content validator.

- [x] Add 10 ordered modules and 60 original TR/EN lessons covering setup, tuning, single notes, rhythm/reading, open chords, strumming, scales, harmony, fingerstyle, controlled intermediate techniques and two original final performances. Each lesson carries specific instruction, practice, self-check, options, stop signal, source IDs and AI media brief. Use sources to guide sequence; reuse no copyrighted notation, footage or exercises.
- [x] Keep all 60 lessons in instruction/self-report mode. The offline pitch result does not create verified progress; existing camera course remains separate and its claims are unchanged.
- [x] Validate unique stable IDs, prerequisites, language completeness, source references, mode, capstones and reachability. Parse the same data in Flutter.
- [x] Add account-scoped, schema-versioned local progress with seen, practiced and self-reported completion as separate facts. Ensure content revisions cannot silently map an old completion onto different content, and shared account deletion removes the file via the existing account directory.
- [x] Add course/lesson pages in Ostinato's current palette/type and a guitar entry point. Show next lesson, module progress and evidence type without promising mastery.
- [x] Focused widget, progress and validation tests plus Flutter analyze/test. No audio permission, AI asset production or automatic scoring in this phase.

## Outcome and open acceptance gates

- Offline evaluator and immutable configuration completed. GuitarSet CC BY 4.0 replay used players 00/01 for development (22 accepted of 38) and 02/03 for holdout (47 of 49); no threshold tuning or model training occurred. No wrong note calls occurred among accepted labeled windows. This small studio sample does not establish physical-phone accuracy or false acceptance on wrong-note attempts.
- All 16 selected WAV/JAMS downloads (29,542,721 bytes total) were size/hash checked then deleted. Exact source/license/hash/cleanup evidence remains at `scratch/2026-09-26-motion-courses/ostinato/download-receipt.json`.
- The 10-module/60-lesson original bilingual text path is implemented. Each lesson has distinct practical teaching detail; note/fret routes, meter examples, 13 chord voicings and two original ready-to-play 16-bar performance options are supplied. The course has source references, visible predecessor guidance, comfort options, stop signals and teacher-review-required media briefs. Account-scoped progress records viewed, practice and self-reported completion separately; a changed course version cannot inherit an old completion.
- Native microphone capture/permissions, automatic note or chord scoring, AI media production, guitar-educator content/visual acceptance, real-device UI/persistence and microphone privacy acceptance remain open. No professional certification or clinical advice is claimed.
- The existing surface-honesty gate still rejects three HEAD-baseline strings outside this implementation: `docs/store/listing.tr-TR.json` contains “henüz” and “Mikrofon izni istenmez.”; `lib/app/screens/library_screen.dart` contains “Mikrofon izni istenmez.”. The new course has no remaining surface-honesty violation. Store copy and the legacy library screen were not changed.

### Final local verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter compact`: 173 tests passed with the final course asset; focused course suite has 6 tests, including a Turkish 320px-wide lesson at 1.6 text scale.
- `python3 -B tools/validate_guitar_journey.py`: 10 modules / 60 bilingual lessons / 2 capstones valid; 4 mutation/structure unit tests passed.
- Existing library and reference validators passed; surface-honesty self-test passed. Whole surface-honesty validation has only the three HEAD-baseline findings described above.
- `ostinato_audio`: full package `dart test` passed 118 tests; final package `dart analyze` is clean. Replay tool analysis and the 7 focused single-note tests passed.
- `git diff --check`: clean. Existing workflow WIP remains untouched. No simulator, store, provider, core, Vault, commit or push action occurred.
