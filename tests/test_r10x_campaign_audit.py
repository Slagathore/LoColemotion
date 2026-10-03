"""Invalid/unopened population accounting without launching or qualifying worlds."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10x_campaign_authority as authority
import r10x_campaign_audit as audit
import r10x_dependency_manifest as dependencies


def fixture(base):
    attempt = uuid.uuid4().hex
    root = base / ('r10x-production-ghost-' + attempt)
    root.mkdir()
    specs = authority.population('development_ghost')
    pairs = []
    for seed in (42445,):
        parent = uuid.uuid4().hex
        pair_root = base / ('development-recovery-smoke-' + parent)
        children = [dict(cell_id=c['cell_id'], role=c['role'], parent_attempt_id=parent,
            child_attempt_id=uuid.uuid4().hex, termination_nonce=uuid.uuid4().hex,
            campaign_attempt_id=attempt, evidence_path=(pair_root / 'children' / c['role']).as_posix())
            for c in specs if c['seed']['seed'] == seed]
        pairs.append(dict(attempt_id=parent, root=pair_root.as_posix(), seed=authority.seed_identity(seed), children=children))
    claim = dict(mode='development_ghost', cells=specs, pairs=pairs,
        children=[c for p in pairs for c in p['children']], attempt_id=attempt,
        production_route_key='sha256:'+'1'*64, source_commit='0'*40,
        synthetic_zero_world_fixture=True, physical_acceptance_authority=False)
    (root / 'campaign_claim.json').write_text(json.dumps(claim), encoding='utf-8')
    (root / 'source_manifest.json').write_text('{"synthetic_zero_world_fixture":true}', encoding='utf-8')
    return root, claim


class CampaignAudit(unittest.TestCase):
    def setUp(self):
        self.base=authority.EVIDENCE/('r10x-campaign-audit-controls-'+uuid.uuid4().hex)
        self.base.mkdir()
        # All synthetic claims stay nested and can never reserve the real population.
        patcher=patch.object(authority,'EVIDENCE',self.base)
        patcher.start();self.addCleanup(patcher.stop)

    def test_missing_children_are_retained_as_two_unopened_cells(self):
        root, claim = fixture(self.base)
        with patch.object(dependencies, 'validate', return_value=claim['production_route_key']):
            result = audit.audit(root)
        self.assertEqual([c['cell_id'] for c in claim['cells']], [c['cell_id'] for c in result['cells']])
        self.assertEqual(['unopened']*2, [c['outcome'] for c in result['cells']])
        self.assertEqual(0, result['total_world_builds'])
        self.assertEqual(0, result['total_solver_steps'])
        self.assertEqual('invalid', result['outcome'])
        self.assertFalse(result['all_finite_tasks_passed'])

    def test_launch_started_without_report_has_unknown_counts_and_retained_binding(self):
        root, claim = fixture(self.base)
        child = Path(claim['children'][0]['evidence_path'])
        child.mkdir(parents=True)
        sentinel = child / 'campaign_launch_started.json'
        sentinel.write_text('{"synthetic_zero_world_fixture":true}', encoding='utf-8')
        with patch.object(dependencies, 'validate', return_value=claim['production_route_key']):
            result = audit.audit(root)
        self.assertEqual(['invalid', 'unopened'], [c['outcome'] for c in result['cells']])
        self.assertIsNone(result['total_world_builds'])
        self.assertIsNone(result['total_solver_steps'])
        self.assertEqual(audit.smoke.sha(sentinel), result['cells'][0]['retained_files'][0]['raw_sha256'])

    def test_individual_positive_diagnostic_cannot_repair_invalid_pair(self):
        root, claim = fixture(self.base)
        diagnostic = dict(finite_cells=[dict(finite_task_predicates_passed=True, execution_valid=True)])
        with patch.object(dependencies, 'validate', return_value=claim['production_route_key']), \
             patch.object(audit.smoke, 'audit', return_value=diagnostic):
            result = audit.audit(root)
        self.assertTrue(all(c['independent_cell_diagnostic']['finite_task_predicates_passed'] for c in result['cells']))
        self.assertTrue(all(c['execution_valid'] is False for c in result['cells']))
        self.assertFalse(result['all_finite_tasks_passed'])

    def test_published_invalid_is_closable_but_cannot_masquerade_as_success(self):
        result = dict(execution_valid=False, production_route_key='sha256:'+'1'*64, cells=[])
        supervisor = dict(ok=False, failure_code='R10X_CAMPAIGN_INVALID', independent_audit=result,
                          production_route_key=result['production_route_key'])
        audit.validate_supervisor(supervisor, result)
        for key, value in (('ok', True), ('failure_code', ''), ('independent_audit', {}),
                           ('production_route_key', 'changed')):
            changed = copy.deepcopy(supervisor)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                audit.validate_supervisor(changed, result)


if __name__ == '__main__':
    unittest.main()
