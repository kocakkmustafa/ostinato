"""Pure, app-only education source projection. No media or acceptance is created.

The three reviewed preproduction policy templates are historical inputs. Every
cue, lesson hash, complete production spec, filename and source pin is rebuilt
from the exact current written course. This module performs no disk writes.
"""
from __future__ import annotations

import copy
import hashlib
import json
import re

COURSE_SHA256 = '9e8f01c2ebffbd28ffaf8203be0bce036867d857c3e009a79bf2cf43a75a1f96'
POLICY_SHA256 = '0f19ae4d5238a3ea44b436f2dd74c7a5e2f759fc18ce48ae57d668539e4c04e4'
SCOPE = 'ostinato-only-education-2026-10-20'
SIDECAR = 'tool/source_proof/education-2026-10-20/'
OUTPUTS = {
    'production_manifest': SIDECAR + 'production-manifest.v1.json',
    'source_catalog': SIDECAR + 'source-catalog.v1.json',
    'source_proof': SIDECAR + 'source-proof.v1.json',
    'slice': 'assets/motion_content/ostinato.source-slice.v1.json',
    'projection': 'assets/motion_content/ostinato.source-projection.v1.json',
    'qa': 'assets/motion_content/ostinato_source_pins_v2k.json',
}


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':'), allow_nan=False).encode('utf-8')


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require(ok: bool, code: str) -> None:
    if not ok:
        raise ValueError(code)


def cues(lesson: dict) -> list[tuple[str, int | None, dict, str]]:
    labels = {'tr': ('Uyarlama', 'Öz değerlendirme', 'Dur'),
              'en': ('Adaptation', 'Self review', 'Stop')}
    review = {tag: (f'{a}: {lesson["adaptation"][tag]}\n'
                    f'{r}: {lesson["selfCheck"][tag]}\n'
                    f'{s}: {lesson["stopSignal"][tag]}')
              for tag, (a, r, s) in labels.items()}
    require(len(lesson['teachingSteps']) == 3, 'THREE_TEACHING_STEPS')
    return [('orientation', None, lesson['objective'], 'learningObjective'),
            *[('full_sequence', i + 1, cue, f'teachingSequence/{i}')
              for i, cue in enumerate(lesson['teachingSteps'])],
            ('drill_and_transfer', None, lesson['practice'], 'currentPractice'),
            ('correction_or_explanation', None, lesson['commonError'],
             'commonErrorAndCorrection'),
            ('adaptation_and_review', None, review,
             'adaptation+selfReview+stopSignal')]


def make_scenes(lesson: dict, course_sha: str, templates: dict) -> list[dict]:
    result = []
    lesson_id = lesson['id']
    last = lesson_id == 'guitar.journey.independent.next_cycle'
    for role, step, cue, field in cues(lesson):
        template = 'first_read' if last and role == 'full_sequence' and step == 2 else 'last' if last else 'normal'
        scene = copy.deepcopy(templates[template])
        suffix = f'{role}-{step:02d}' if step is not None else role
        scene_id = f'ostinato:{lesson_id}:{suffix}'
        cue_sha = sha(canonical(cue))
        scene.update(sceneId=scene_id, courseSourceSHA256=course_sha,
                     role=role, sequenceStep=step, sourceCueField=field,
                     sourceCue=copy.deepcopy(cue), sourceCueSHA256=cue_sha,
                     sourceLessonCanonicalSHA256=sha(canonical(lesson)),
                     generatedAssetSHA256=None)
        original = lesson['mediaBrief']
        scene['prompt'].update(sourceCue=copy.deepcopy(cue), visualSource={
            'status': 'EXPLICIT_SOURCE_SHOT', 'text': original['shot']})
        scene['captions'].update(sourceCueSHA256=cue_sha,
                                 sourceCaptionRule=original.get('captions'))
        scene['audio']['sourceFormat'] = original.get('format')
        scene['format']['sourceSpecification'] = original.get('format')
        scene['integrationTarget'].update(lessonId=lesson_id,
            proposedExternalMediaRegistryKey=scene_id)
        spec = copy.deepcopy(scene)
        spec.pop('generatedAssetSHA256')
        spec.pop('idempotencyRule')
        spec_sha = sha(canonical(spec))
        slug = re.sub(r'[^a-z0-9]+', '-', lesson_id.lower()).strip('-')
        role_slug = re.sub(r'[^a-z0-9]+', '-', suffix.lower()).strip('-')
        stem = f'ostinato/{slug}--{sha(lesson_id.encode())[:8]}/{role_slug}--{spec_sha}--master-format-pending'
        scene['format']['filenameVariantsWithoutExtension'] = [stem]
        scene['productionSpecSHA256'] = spec_sha
        scene['idempotencyKey'] = 'motion-media-v1:' + spec_sha
        result.append(scene)
    return result


def expected_files(course_raw: bytes, policy_raw: bytes) -> dict[str, bytes]:
    """Exact deterministic outputs; a new course needs a reviewed new pin."""
    require(sha(course_raw) == COURSE_SHA256, 'CURRENT_COURSE_SHA_DRIFT')
    require(sha(policy_raw) == POLICY_SHA256, 'POLICY_TEMPLATE_SHA_DRIFT')
    course, policy = json.loads(course_raw), json.loads(policy_raw)
    require(policy['scope'] == SCOPE and set(policy['templates']) ==
            {'normal', 'last', 'first_read'}, 'APP_ONLY_POLICY_SCOPE')
    require(policy['externalExpertMandatory'] is False and
            len(policy['amendments']) == 16, 'OWNER_REVIEW_POLICY')
    for template in policy['templates'].values():
        require(template['productionState'] == 'PREPRODUCTION_UNGENERATED' and
                template['activationGate']['state'] == 'BLOCKED_NO_MEDIA_OR_APP_BINDING' and
                template['activationGate']['appMediaUrlOrBundleFieldWritten'] is False and
                template['qualityAndSourceReview']['acceptance'] == 'NOT_ACCEPTED' and
                template['qualityAndSourceReview']['technicalAndSourceReview'] == 'PENDING',
                'ACTUAL_MEDIA_REVIEW_STAYS_PENDING')
    require(len(course['modules']) == 10 and
            all(len(m['lessons']) == 6 for m in course['modules']), 'COURSE_SHAPE')
    actual = [l for m in course['modules'] for l in m['lessons']]
    require(len({l['id'] for l in actual}) == 60, 'UNIQUE_SIXTY_LESSONS')
    records = []
    for order, (module, lesson) in enumerate(
            ((m, l) for m in course['modules'] for l in m['lessons']), 1):
        records.append({'app': 'ostinato', 'assetId': f'ostinato.{lesson["id"]}.v8e.demo',
            'courseSourceSHA256': COURSE_SHA256,
            'lessonCanonicalSHA256': sha(canonical(lesson)), 'lessonId': lesson['id'],
            'moduleId': module['id'], 'order': order, 'title': lesson['title'],
            'lessonPlannedMinutesNotClipDuration': lesson['minutes'], 'sceneCount': 7,
            'scenes': make_scenes(lesson, COURSE_SHA256, policy['templates']),
            'qualifiedMedia': 0, 'technicalAndSourceReviewAccepted': False})
    counts = {'apps': 1, 'lessons': 60, 'scenes': 420, 'variants': 420,
              'generatedMedia': 0, 'qualifiedMedia': 0}
    closed = {'visible': False, 'releaseEligible': False, 'progressEffect': 0,
              'approvedProductionTrustRoot': False}
    manifest = {'schemaVersion': 1, 'kind': 'OSTINATO_EDUCATION_PRODUCTION_MANIFEST_V1',
        'scope': SCOPE, 'courseSourceSHA256': COURSE_SHA256,
        'policyTemplateSHA256': POLICY_SHA256, 'historicalBasis': policy['historicalBasis'],
        'counts': counts, 'lessonRecords': records, **closed}
    manifest_raw = canonical(manifest)
    manifest_sha = sha(manifest_raw)
    lessons, rows = [], []
    for record in records:
        lesson = {k: record[k] for k in ['app', 'lessonId', 'assetId',
                  'courseSourceSHA256', 'lessonCanonicalSHA256']}
        lesson.update(membershipStatus='SOURCE_PINNED_TEST_ONLY', scenes=[])
        for order, full in enumerate(record['scenes']):
            scene = {k: full[k] for k in ['sceneId', 'productionSpecSHA256',
                'sourceCueSHA256', 'idempotencyKey', 'productionState']}
            stem = full['format']['filenameVariantsWithoutExtension'][0]
            identity = {'manifestSHA256': manifest_sha, 'app': 'ostinato',
                'courseSourceSHA256': COURSE_SHA256, 'lessonId': lesson['lessonId'],
                'lessonCanonicalSHA256': lesson['lessonCanonicalSHA256'],
                'assetId': lesson['assetId'], **scene, 'variantStem': stem}
            pin = sha(canonical(identity))
            scene['variants'] = [{'stem': stem, 'sourcePinSHA256': pin}]
            lesson['scenes'].append(scene)
            rows.append([pin, lesson['lessonId'], lesson['assetId'], scene['sceneId'],
                order, stem, lesson['lessonCanonicalSHA256'], scene['productionSpecSHA256'],
                scene['sourceCueSHA256'], scene['idempotencyKey'], False])
        lessons.append(lesson)
    require(len(rows) == len({r[0] for r in rows}) == 420, 'UNIQUE_420_PINS')
    catalog = {'schemaVersion': 1, 'kind': 'OSTINATO_EDUCATION_SOURCE_CATALOG_V1',
        'scope': SCOPE, 'state': 'CLOSED_PREPRODUCTION_SOURCE_MEMBERSHIP_ONLY',
        'manifestSHA256': manifest_sha, 'courseSourceSHA256': COURSE_SHA256,
        'counts': counts, 'lessons': lessons, 'holds': [], **closed}
    catalog_raw = canonical(catalog)
    catalog_sha = sha(catalog_raw)
    proof = {'schemaVersion': 1, 'kind': 'OSTINATO_EDUCATION_SOURCE_PROOF_V1',
        'scope': SCOPE, 'courseSourceSHA256': COURSE_SHA256,
        'policyTemplateSHA256': POLICY_SHA256, 'manifestSHA256': manifest_sha,
        'sourceCatalogSHA256': catalog_sha, 'counts': counts,
        'policyAmendmentsSHA256': sha(canonical(policy['amendments'])),
        'externalExpertMandatory': False,
        'historicalBasis': policy['historicalBasis'], **closed}
    proof_raw = canonical(proof)
    proof_sha = sha(proof_raw)
    common = {'schemaVersion': 1, 'appId': 'ostinato',
        'courseSourceSHA256': COURSE_SHA256, 'sourceCatalogSHA256': catalog_sha,
        'sourceManifestSHA256': manifest_sha}
    source_slice = {**common, 'kind': 'MOTION_V2L_APP_SOURCE_SLICE_V1',
        'sourceProofSHA256': proof_sha, 'lessons': lessons, 'holds': []}
    projection = {**common, 'kind': 'MOTION_V2L_APP_SOURCE_PROJECTION_V1',
        'rows': sorted(rows, key=lambda r: r[0])}
    qa = {'schemaVersion': 1, 'kind': 'OSTINATO_V2K_SOURCE_PINS_QA_ONLY',
        'courseSourceSHA256': COURSE_SHA256, 'sourceCatalogSHA256': catalog_sha,
        'manifestSHA256': manifest_sha, 'sourceProofSHA256': proof_sha,
        'counts': {k: v for k, v in counts.items() if k != 'apps'},
        'lessons': lessons, 'visible': False, 'releaseEligible': False, 'progressEffect': 0}
    return {'production_manifest': manifest_raw, 'source_catalog': catalog_raw,
        'source_proof': proof_raw, 'slice': canonical(source_slice),
        'projection': canonical(projection),
        'qa': (json.dumps(qa, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()}


def verify_bundle(course_raw: bytes, policy_raw: bytes, bundle: dict[str, bytes]) -> None:
    expected = expected_files(course_raw, policy_raw)
    require(set(bundle) == set(expected), 'APP_ONLY_BUNDLE_MEMBERS')
    for key, raw in expected.items():
        require(bundle[key] == raw, 'APP_ONLY_DERIVATION_DRIFT:' + key)
