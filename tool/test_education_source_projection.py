"""Negative controls for exact app-only source derivation; no SDK required."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import build_education_source_projection as education
import check_v2l_source_projection as source


class EducationSourceProjectionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = {key: (source.APP / path).read_bytes()
                    for key, path in source.INPUTS.items()}
        self.bundle = {key: self.raw[key] for key in education.OUTPUTS}

    def reject(self, bundle: dict[str, bytes]) -> None:
        with self.assertRaisesRegex(ValueError, 'APP_ONLY_'):
            education.verify_bundle(self.raw['course'], self.raw['policy'], bundle)

    def change(self, key: str, edit) -> dict[str, bytes]:
        changed = copy.deepcopy(self.bundle)
        value = json.loads(changed[key]); edit(value)
        changed[key] = education.canonical(value)
        return changed

    def test_course_byte_drift_cannot_be_silently_repinned(self) -> None:
        with self.assertRaisesRegex(ValueError, 'CURRENT_COURSE_SHA_DRIFT'):
            education.expected_files(self.raw['course'] + b' ', self.raw['policy'])

    def test_policy_change_cannot_turn_future_media_into_accepted(self) -> None:
        policy = json.loads(self.raw['policy'])
        policy['templates']['normal']['qualityAndSourceReview']['acceptance'] = 'ACCEPTED'
        with self.assertRaisesRegex(ValueError, 'POLICY_TEMPLATE_SHA_DRIFT'):
            education.expected_files(self.raw['course'], education.canonical(policy))

    def test_current_cue_and_all_its_embedded_hashes_are_rederived(self) -> None:
        def edit(manifest):
            scene = manifest['lessonRecords'][0]['scenes'][1]
            scene['sourceCue']['en'] = 'Unsupported instruction added to a reviewed cue.'
            scene['sourceCueSHA256'] = education.sha(education.canonical(scene['sourceCue']))
            scene['prompt']['sourceCue'] = copy.deepcopy(scene['sourceCue'])
            scene['captions']['sourceCueSHA256'] = scene['sourceCueSHA256']
        self.reject(self.change('production_manifest', edit))

    def test_whole_spec_restricts_prompt_even_when_cue_is_unchanged(self) -> None:
        def edit(manifest):
            manifest['lessonRecords'][0]['scenes'][0]['prompt']['direction'] = 'New unsupported direction.'
        self.reject(self.change('production_manifest', edit))

    def test_idempotency_key_is_not_reusable_after_a_spec_change(self) -> None:
        def edit(manifest):
            manifest['lessonRecords'][0]['scenes'][0]['idempotencyKey'] = 'motion-media-v1:' + '0' * 64
        self.reject(self.change('production_manifest', edit))

    def test_proof_cannot_claim_the_old_five_app_scope(self) -> None:
        self.reject(self.change('source_proof', lambda proof: proof.update(scope='five-apps')))

    def test_actual_generated_media_count_cannot_increase(self) -> None:
        def edit(manifest):
            manifest['counts']['generatedMedia'] = 1
            manifest['lessonRecords'][0]['scenes'][0]['generatedAssetSHA256'] = '1' * 64
        self.reject(self.change('production_manifest', edit))

    def test_proof_cannot_acquire_release_eligibility(self) -> None:
        self.reject(self.change('source_proof', lambda proof: proof.update(releaseEligible=True)))

    def test_catalog_cannot_acquire_visibility_or_progress(self) -> None:
        self.reject(self.change('source_catalog', lambda catalog: catalog.update(visible=True, progressEffect=1)))

    def test_projection_cannot_clear_or_add_a_hold_by_editing_its_row(self) -> None:
        def edit(projection):
            projection['rows'][0][10] = True
        self.reject(self.change('projection', edit))

    def test_unknown_bundle_member_is_refused(self) -> None:
        bundle = dict(self.bundle)
        bundle['foreign_app'] = b'{}'
        self.reject(bundle)

    def test_repo_only_proof_input_leaf_symlink_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'app'; root.mkdir()
            for key, path in source.INPUTS.items():
                target = root / path; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(self.raw[key])
            outside = Path(temporary) / 'outside-proof.json'
            outside.write_bytes(self.raw['source_proof'])
            proof = root / source.INPUTS['source_proof']
            proof.unlink(); proof.symlink_to(outside)
            with self.assertRaisesRegex(source.ProjectionError, 'INPUT_SYMLINK'):
                source.check_app(root)

    def test_owner_review_policy_is_pending_without_external_expert_gate(self) -> None:
        policy = json.loads(self.raw['policy'])
        self.assertIs(policy['externalExpertMandatory'], False)
        self.assertEqual(len(policy['amendments']), 16)
        for template in policy['templates'].values():
            self.assertNotIn('qualityAndEducatorGate', template)
            self.assertEqual(template['qualityAndSourceReview']['acceptance'], 'NOT_ACCEPTED')
            self.assertEqual(template['qualityAndSourceReview']['technicalAndSourceReview'], 'PENDING')
            self.assertNotIn('human_technical_educator_acceptance', template['activationGate']['requires'])
            self.assertIn('reviewed_technical_and_source_semantics', template['activationGate']['requires'])
        first_read = policy['templates']['first_read']['firstReadScoreSourceRules']
        self.assertEqual(first_read['initialReveal'], 'silent_score_and_equivalent_text_only')
        self.assertEqual(first_read['playedExample'], 'only_after_learner_first_attempt_and_self_notes')
        self.assertEqual(first_read['reviewStatus'], 'PENDING_NOT_ACCEPTED')


if __name__ == '__main__':
    unittest.main()
