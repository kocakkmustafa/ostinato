# Four-string bass written beginner foundation

Layered on accepted local piano+ukulele tree `fce7cdd8532b489fdd3f0461b58b36f483342d84`. Reuses the existing verified ContentBundleLoader, strict JSON pattern, localized course/lesson navigation and original Flutter vectors. Working directory/cache is reused to respect the disk floor; accepted prior source trees, patches and evidence remain immutable in Git objects and workspace artifacts. No new framework, live posture discipline or dependency pin is added.

## Setup and outcome

Right-handed, fretted, four-string electric bass, standard SOUNDING 4→1 E1 A1 D2 G2, C4=middle C. Secure appropriate strap/support, external bass-capable tuning aid and quiet appropriate amplification are entry requirements. Low-output manual-guided setup avoids compensating with hard plucks. Unknown string sets, altered tuning, piccolo/fretless/five/six strings and left-handed orientations are not silently adapted. Conventional bass staff notation is one octave above the sound: written E2 A2 D3 G3 represent open sounding E1 A1 D2 G2. App text/tuner references, fret map, tab answer pitch labels always refer to SOUNDING pitches; the staff examples explicitly label WRITTEN pitches. No audio reference is supplied.

Eighteen TR/EN lessons each contain explanation, concrete practice, self-check and error recovery. The endpoint is an attempted, understood original study with an actionable same-task/same-tempo correction loop and another-day revisit, rather than automatic completion or a certificate. Full musicianship, professional sight-reading and measured learning effectiveness remain outside this local written-source acceptance.

| Lessons | Learning progression |
|---|---|
| 1–4 | Identify setup; safe strap/support and quiet output; external tuning and octave caution; string/fret/finger conventions and relaxed fretting |
| 5–8 | Gentle plucks; i/m alternation; four-count pulse with counted silence; two-hand muting including unused strings |
| 9–11 | Fretted note examples with shifting instead of forced stretch; open-string crossing; roots, perfect fifths and octaves |
| 12–13 | Original two-bar tab with explicit quarter timing and hidden exact string/fret answers; four open-string bass-clef examples with written/sounding octave pair |
| 14–15 | Eighth counts and N/H/R rhythm-table legend; compose a two-bar root/fifth idea with one controlled variation |
| 16–18 | Original eight-bar study, bar/count error isolation, same-task correction, another-day exit review |

## Original examples and decoder boundary

Tab: 4/0, 4/3, 3/0, 3/2 | 2/0, 2/2, 1/0, 4/0, all quarter notes. Sounding pitches: E1 G1 A1 B1 | D2 E2 G2 E1. Answers compare every beat's string/fret pair; pitches are explanatory and do not verify playing. Staff examples are separate open-string quarter-note examples, not a new four-note melody or a complete sight-reading task. Written positions above the bottom staff line are E2=-2 (ledger), A2=1 (bottom space), D3=4 (middle line), G3=7 (top space).

Eight-bar study: each bar has eight equal half-beat event cells. N attacks one explicit string/fret and replaces the previous sound, H adds no attack while retaining ringing or existing silence, R stops sound while count continues. H is this table's hold instruction, explicitly distinguished from tab hammer-on. Root/fifth/open/octave paths are original, no copied song or backing recording. Bar 8 ends sounding on beat 3, while counting continues through beat 4. All events and tab pairs come from the same authenticated course asset as the lesson text.

Exact root/lesson/event fields, positive int schema, supported tuning/pitch convention, ordered complete lessons, bilingual nonblank text, bounded string/fret coordinates (1–4 / 0–3), eight-event bars and supported diagram references are decoded fail-closed. Manifest asset SHA, byte length and catalog digest are checked first. Library entry is a real written-course route; no fake measured bass contract is created. Load/retry/back/stale-result behavior follows accepted piano/ukulele.

## Primary source verification, 2026-10-04

- [Fender manufacturer beginner guide](https://www.fender.com/articles/techniques/how-to-play-bass-guitar): E/A/D/G string order, instrument setup tools and index/middle fingerstyle entry. Songs, images, videos and paid lessons are not reused. Its loose guitar-string and universal-scale wording is not adopted.
- [KORG GA-2 manufacturer specifications](https://www.korg.com/us/products/tuners/ga_2/specifications.php): bass reference-tone order 4E/3A/2D/1G and sound-out references two octaves above target. Lesson 3 explicitly guards against tightening to a higher reference octave; a sound-out beep is not automatically the bass register. No tuner tone is played or embedded.
- [Fender tuning guide](https://www.fender.com/articles/setup/how-to-tune-your-bass): external tuning aid/manual-guided checks. Embedded demonstration audio/video was not played or incorporated.
- [StudyBass tuning](https://www.studybass.com/gear/bass-tuning/bass-guitar-tunings/), teacher-authored original instruction: four-string EADG versus other string counts and piccolo octave change.
- [StudyBass holding](https://www.studybass.com/lessons/bass-technique/holding-the-bass/): support and freeing the hands. General comfortable options are used; its medical/posture assertions and exact body proportions are not copied.
- [StudyBass plucking](https://www.studybass.com/lessons/bass-technique/plucking/): numbering, small alternating index/middle motion and two-hand string control. This course chooses one gentle beginner option, not a universally required technique.
- [StudyBass fretting](https://www.studybass.com/lessons/bass-technique/fretting/): pressure behind the wire, comfortable thumb/support, shifting instead of forced stretch. No injury diagnosis or guaranteed corrective claim is adopted.
- [StudyBass muting](https://www.studybass.com/lessons/bass-technique/open-string-muting/): lower unused strings controlled by plucking hand and higher ones by fretting hand.
- [StudyBass musical alphabet](https://www.studybass.com/lessons/basics/the-musical-alphabet/) and [basic intervals](https://www.studybass.com/lessons/intervals/basic-intervals/): note-letter cycle, semitone/octave and fretboard interval conventions. TR lesson 1 explicitly maps C D E F G A B to Do Re Mi Fa Sol La Si; lesson 4 explains the semitone prerequisite before fifth/octave work.
- [StudyBass tab](https://www.studybass.com/lessons/reading-music/how-to-read-bass-tab/): top G/D/A/bottom E, fret numbers and explicit rhythm legend. Its examples were not copied.
- [StudyBass pitch notation](https://www.studybass.com/lessons/reading-music/pitch-notation/) and [fretboard notes](https://www.studybass.com/lessons/reading-music/bass-clef-fretboard-notes/): five-line bass staff and lowest written E ledger placement, distinct from string lines. Its diagram/PDF is restricted to distribution on its site and is not incorporated. Our vectors are independently drawn.

These sources check basic technical conventions; they do not prove the authored pacing, numeric octave interpretation or actual learner outcomes. Independent pedagogy/code review is requested on the stable candidate before closure. Unavailable guessed Yamaha/VSL/Ibanez/D’Addario pages and failed search results are not used as verification evidence.

## Qualification and limits

Planned local tests: strict malformed inputs and authenticated tampering; complete TR/EN curriculum; independent sounding pitch/interval/staff checks; real Library entry; retry, stale load and pending unmount; all-lesson back/next and answer reset at narrow 2× text; real-font vector and open-answer renders with every study row/last cell. Test/build/render lane is currently paused for shared disk coordination, so these are not claimed as completed yet.

No account, credentials, provider, mail, native build, model download, media/paid/physical feature flag or store/deploy action. No automatic pitch/posture/tuning judgments, AI score, progress evidence or mastery acceptance. Motion publication access remains a separate gate; actual teaching/device/audio/physical acceptance remains open.
