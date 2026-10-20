# Written education: first release scope

The current courses contain 128 original lessons: guitar 60, piano 16, vocal 16,
ukulele 18 and bass 18. They teach bounded instrument practice and self observation.
They do not certify playing accuracy, vocal health, mastery or instructor approval.
The guitar path retains its historical self report progress; the other four written
courses do not save progress or practice notes. Learners can keep their own written
observations and revisit the suggested lessons.

The 20 October acceptance decision does not require an external expert to approve
publication. Source, technical and accessibility review may be performed by the
owner and AI. Unknown results stay unknown; actual media, hardware or sensor
acceptance cannot be inferred from written content or a passing host test.

This update completes explanations in 19 existing lessons. Guitar introduces
instrument parts, string/fret/finger identities, pulse, notation and an original
four bar reading card in the visible practice lab. Piano adds enharmonic key names,
keyboard setting checks, 4/4 preparation and a touch response alternative. Vocal
separates pitch from loudness, explains half beat counting and adds a recall check.
Bass makes tempo comparisons and fretted note endings concrete. Ukulele's existing
bounded entry to exit tasks required no new lesson.

The authored JSON remains EN/TR. Fourteen presentation catalogs translate exact
source pairs: tr, en, es-419, pt-BR, de, fr, ja, ar, it, ko, id, pl, hi and zh-Hans.
Scientific pitch codes remain stable. German and Polish explanations distinguish
international B from local H. Translation review is an AI semantic review, not a
native speaker or physical instrument trial.

Update `tool/guitar_journey_enrichment.v1.json` before regenerating the guitar asset
with `python3 tool/build_guitar_journey.py`; editing only the asset creates drift.
For every authored source pair, update its presentation ID and every catalog.
`education_source_pair_coverage_test.dart` discovers course pairs independently of
the ID map. The course integrity manifest must be regenerated through its normal
Dart builder. SDK commands belong to the shared runtime coordinator.

Planned video source identities use the app scoped
`tool/source_proof/education-2026-10-20/` derivation. Every cue, full production
specification, idempotency key and source pin is rebuilt from the current course.
The historical five app records remain historical inputs. No generated or qualified
media is present; visibility, release eligibility and progress effects remain off.
The legacy authored `mediaStatus` string mentioning teacher review is not read by
runtime publication or progress gates and must not be changed to an approved state
as a substitute for inspecting an actual asset.

Public teaching videos were examined in bounded visual/caption sections. No source
video, transcript, proprietary diagram, song or teacher likeness was copied into
the product. Those reviews do not establish acoustic accuracy or teaching efficacy.
Real device sound, permissions, native typography and signed package acceptance
remain separate release work.
