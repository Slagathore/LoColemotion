"""Production R10P header checks on explicitly synthetic, incomplete reports."""
import copy
import json
import unittest
import uuid

import test_r10p_campaign_runner as runner
from test_r10p_campaign_runner import authority, entry
import r10p_pair_audit as reader


class PairHeader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not hasattr(runner.CampaignRunner, 'result'):
            runner.CampaignRunner.setUpClass()
        value = copy.deepcopy(runner.CampaignRunner.result['modes']['development_ghost'])
        attempt = uuid.uuid4().hex
        cls.root = authority.EVIDENCE / ('r10p-production-ghost-' + attempt)
        cls.root.mkdir()
        for pair in value['pairs']:
            for child in pair['children']:
                child['campaign_attempt_id'] = attempt
        claim = dict(schema_version='sporespore_r10p_campaign_claim_v1', mode='development_ghost',
            attempt_id=attempt, source_commit='0'*40, candidate_profile=entry.reference(),
            cells=value['cells'], children=[c for p in value['pairs'] for c in p['children']],
            synthetic_zero_world_fixture=True, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False)
        path = cls.root / 'campaign_claim.json'
        path.write_text(json.dumps(claim), encoding='utf-8')
        cls.fixtures = []
        for pair, declaration in zip(value['pairs'], value['declarations']):
            declaration['children'] = pair['children']
            context = declaration['r10p_campaign']
            context.update(campaign_attempt_id=attempt,
                claim_binding=dict(path=path.as_posix(), raw_sha256=authority.sha(path.read_bytes())))
            campaign = authority.validate_pair_declaration(declaration)
            worker = entry.selection()['worker_selection']
            for descriptor in pair['children']:
                report = dict(schema_version=worker['report_schema'], work_id=worker['work_id'],
                    source_commit='0'*40, parent_attempt_id=pair['attempt_id'],
                    child_attempt_id=descriptor['child_attempt_id'], arm_id=descriptor['role'], process_id=123,
                    seed=pair['seed']['seed'], maximum_solver_step_count=3512,
                    model_construction_attempt_count=1, model_construction_count=1, world_attempt_count=1,
                    world_build_count=1, complete_route_proven=False, held_out=False,
                    physical_acceptance_authority=False, release_authority=False, behavioral_conclusion='none',
                    telemetry_profile='unchanged_full_per_step_capture', ok=True, solver_step_count=1,
                    global_solver_frame_count=1, after_interaction_step_count=0, coverage_complete=False,
                    status='development_smoke_coverage_incomplete', ledger_scope=campaign['ledger_scope'],
                    r10p_campaign=context, seed_label=pair['seed']['label'], seed_sha256=pair['seed']['sha256'],
                    held_out_cell_access_count=0, r10k_partial_recovery={'synthetic_marker': True})
                for field in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
                    report[field] = declaration[field]
                cls.fixtures.append((report, descriptor, declaration))
        # These are header-only fixtures, with no retained arm, launch receipt,
        # DLL evaluation or replay; the complete reader cannot accept them.
        (cls.root / 'synthetic_header_fixtures.json').write_text(json.dumps(cls.fixtures), encoding='utf-8')

    def test_three_declared_development_headers_accept_exact_campaign_context(self):
        for report, descriptor, declaration in self.fixtures:
            reader.validate_header(report, descriptor, declaration, 123)
        self.assertEqual(3, len(self.fixtures))

    def test_header_refuses_crossed_identity_promotion_and_typed_counter_changes(self):
        report, descriptor, declaration = self.fixtures[0]
        changes = dict(seed=40743, process_id=124, child_attempt_id='other', parent_attempt_id='other',
            source_commit='9'*40, candidate_profile={}, baseline_reused=True, comparative_authority=True,
            held_out=True, held_out_cell_access_count=False, r10p_campaign={}, seed_label='other', seed_sha256='other',
            physical_acceptance_authority=True, release_authority=True, solver_step_count=True,
            world_build_count=True, maximum_solver_step_count=3513, global_solver_frame_count=2,
            coverage_complete=1, ledger_scope={}, synthetic_test_fixture=True, r10o_development={})
        for key, changed in changes.items():
            with self.subTest(key=key), self.assertRaises(ValueError):
                reader.validate_header(dict(report, **{key: changed}), descriptor, declaration, 123)
        for field in ('r10p_campaign', 'seed_label', 'seed_sha256', 'held_out_cell_access_count'):
            changed = copy.deepcopy(report)
            changed.pop(field)
            with self.subTest(missing=field), self.assertRaises(ValueError):
                reader.validate_header(changed, descriptor, declaration, 123)

    def test_declaration_refuses_wrong_worker_incomplete_roles_and_changed_claim(self):
        report, descriptor, declaration = self.fixtures[0]
        for mutate in (lambda d: d.update(worker_resource='res://other.gd'),
                       lambda d: d['children'].pop(),
                       lambda d: d['r10p_campaign']['claim_binding'].update(raw_sha256='sha256:'+'0'*64),
                       lambda d: d.update(r10o_development={}),
                       lambda d: d.update(development_execution_mode='single_kick_controller_diagnostic_v1')):
            changed = copy.deepcopy(declaration)
            mutate(changed)
            with self.assertRaises(ValueError):
                reader.validate_header(report, descriptor, changed, 123)


if __name__ == '__main__':
    unittest.main()
