# Comfortable written vocal foundation — source integration candidate

This local source candidate adds an explicitly written, self-observed Library entry and 16 ordered TR/EN lessons. It does not activate voice camera/posture lessons, microphone capture, scoring, sustained/vibrato gates, paid/media/physical capabilities, or audio references. Opening/reading lessons records no progress and grants no mastery. There is no diagnosis, voice classification, fixed interval, range or intonation measurement.

## Proposal mapping and boundaries

The independently accepted pedagogical proposal v2 is preserved outside the app at `../vocal-proposal/vocal_beginner.proposal.v2.json`. Proposal v3 changes only lesson 6 practice wording: sustain one gentle hum through beats 1–2 in bar 1, release into silence on 3–4; bar 2 has two separate starts. This correction is sealed separately, not a rewrite of accepted v2 evidence.

Runtime asset `assets/content/vocal_beginner.v1.json` maps proposal v3 as follows: remove `proposalVersion` and `runtimeIntegrated`; add schemaVersion=1, id=voice.beginner.written, pitchMode=personal-relative:L-M-H;no-fixed-interval. Title, prerequisites, exit, four bilingual lesson sections, paper answers, contour, rhythm symbols and all eight study bars are preserved exactly. Add only diagram references: lesson 6 rhythm, lesson 9 contour, lessons 13–15 study; all others empty. Decoder validates this mapping, exact fields, symbol roles, 16 ordered IDs, two four-quarter contour bars, eight eight-half-beat study bars, tone L/M/H, nonempty bilingual syllables and immutable nested data. A bar starts with voice or explicit rest; a first continuation is rejected. Silent bars 6 and 8 are intentional.

The original tables show quarter rhythm/contour tasks and a separate answer disclosure; they never judge a performance. Study columns are half-beats counted 1 & 2 & 3 & 4 &. V starts the printed tone/syllable; = continues existing sound OR silence; R releases into silence. H exclusively means a personally nearby higher tone. No fixed notes/intervals or reference sound is implied. Normal breathing, phrase shortening, stopping/resting and recording adaptations remain available throughout. “Counts” are reading suggestions, never respiratory targets. Accessible text accompanies horizontally scrollable tables. Answer panels reset on lesson reopening. The course retries verified asset failures and suppresses retained old content during bundle replacement using the existing accepted written-course navigation pattern.

## Beginning and exit

Entry: comfortable ordinary speaking voice today, quiet environment, willingness to self-observe and rest; no prior notation. Stop for pain, strain, dizziness or increased effort; do not sing while hoarse/ill/tired. Persistent problems belong with an appropriate professional, not an app verdict. The course progresses through unforced support, ordinary breath, short gentle onset/release/hum, counted silence, small personal pitch direction, vowels and original clear words, eighths, an original adaptable eight-bar study, an honest same-task correction and an another-day revisit. Exit is explaining/attempting these tasks comfortably with self-observation and symbol reading, not confirmed pitch/range/voice health/mastery.

## Firsthand sources consulted

- NIH/NIDCD, [Taking Care of Your Voice](https://www.nidcd.nih.gov/health/taking-care-your-voice), updated June 11 2025: rest and voice-use boundaries. No disease treatment, prescribed exercise dose, diet or medication instructions adopted.
- Laurel Irene and David Harris, [VoiceScienceWorks authors and teaching](https://www.voicescienceworks.org/what-we-do.html), [Build Your Own Warm-Up](https://www.voicescienceworks.org/build-your-own-warm-up.html), [SOVT exercises](https://www.voicescienceworks.org/sovt-exercises.html): individual comfortable starting pitch, small goal-directed patterns and brief gentle humming. No therapeutic claim, straw/water-pressure exercise, fixed 15-minute dose, extremes, breath holding, forced muscles or vocal fry instruction adopted.

All exercises, words, tables and explanations are original. No song, picture, audio/video or copyrighted worksheet is distributed. Detailed proposal source selection and limits are preserved in `../vocal-proposal/SOURCE-MAP-v3.md`.

## Qualification status

UNQUALIFIED SOURCE-ONLY. Test sources cover actual Library navigation, all 16 lessons in both languages at 390×844 with 2× text, hidden/reset answers, study horizontal access, strict malformed fields, corrupt asset refusal, retry and stale/unmounted loads. Analyzer, tests and render verification have NOT run: parent explicitly paused those resource lanes. No bass v4 runtime acceptance is implied by this overlay. Piano and ukulele prior accepted results remain bound to their immutable prior trees; this combined new tree awaits independent code review and a released verification lane. Canonical accepted main and guest PR3 remain untouched.
