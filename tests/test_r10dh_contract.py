"""Finite decision and declaration controls; no native world is constructed."""
import copy
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10dh_contract as C
import r10dh_dependency_manifest as M


class Contract(unittest.TestCase):
    def test_declared_cells(self):
        C.validate_design(C.read(C.DESIGN)); C.validate_task(C.read(C.TASK))
        self.assertEqual(18912, sum(x['maximum_solver_steps'] for x in C.population('held_out')))
        self.assertEqual([72, 72, 73, 73, 74, 74], [x['seed']['prefix_phase'] for x in C.population('held_out')])
        exposed = C.read(C.EXPOSURE)['exposed_prefix_phases']
        self.assertFalse(set(exposed) & {72, 73, 74})
        original=C.read(C.ROOT/'sdk/recovery/r10dh_held_out_finite_decision_design_v1.json')
        successor=C.read(C.DESIGN)
        self.assertTrue(C.same(original['held_out'],successor['held_out']))
        self.assertTrue(C.same(original['development_ghost'],successor['development_ghost']))
        import r10dh_authority as A
        self.assertEqual('r10dh-development_ghost-single-use-v2',A.CLAIMS['development_ghost'].name)
        self.assertEqual('r10dh-held_out-single-use-v1',A.CLAIMS['held_out'].name)

    def test_strict_json(self):
        for text in ('{"a":1,"a":2}', '{"a":NaN}', '{"a":Infinity}'):
            with self.subTest(text=text), self.assertRaises(ValueError): C.parse(text)

    def test_population_refusals(self):
        good = C.population('held_out')
        changes = [[], good[:-1], good + [good[0]], list(reversed(good)), [good[0]]*6]
        for field, value in [('maximum_world_attempts', True), ('maximum_solver_steps', 9999), ('role', 'unknown')]:
            altered = copy.deepcopy(good); altered[0][field] = value; changes.append(altered)
        for cells in changes:
            with self.subTest(cells=cells), self.assertRaises(ValueError): C.validate_population(cells, 'held_out')
        for phase in (True, 71, 75, 72.0):
            with self.subTest(phase=phase), self.assertRaises(ValueError): C.seed_identity(phase, 'held_out')

    def test_negative_or_incomplete_never_adopted(self):
        rows = [dict(cell=cell, valid=True, measurement=dict(finite_task_predicates_passed=True)) for cell in C.population('held_out')]
        self.assertTrue(C.decide(rows, 'held_out', True)['sdk1_m07_satisfied'])
        for i in range(6):
            negative = copy.deepcopy(rows); negative[i]['measurement']['finite_task_predicates_passed'] = False
            result = C.decide(negative, 'held_out', True)
            self.assertTrue(result['execution_valid']); self.assertFalse(result['sdk1_m07_satisfied'])
            invalid = copy.deepcopy(rows); invalid[i]['valid'] = False
            self.assertFalse(C.decide(invalid, 'held_out', True)['execution_valid'])
        for bad in (rows[:-1], rows+[rows[0]], list(reversed(rows))):
            self.assertFalse(C.decide(bad, 'held_out', True)['sdk1_m07_satisfied'])
        self.assertFalse(C.decide(rows, 'held_out', False)['sdk1_m07_satisfied'])
        ghost = [dict(cell=c, valid=True, measurement=dict(finite_task_predicates_passed=True)) for c in C.population('development_ghost')]
        self.assertFalse(C.decide(ghost, 'development_ghost', True)['sdk1_m07_satisfied'])

    def test_manifest_key_covers_raw_and_git(self):
        sources = [dict(path='sdk/a.gd', raw_sha256='sha256:'+'1'*64, byte_length=2, git_blob_oid='2'*40)]
        images = dict(images=dict(engine=dict(path='C:/engine.exe', raw_sha256='sha256:'+'3'*64, byte_length=4)))
        original = M.keyed(sources, images, {})['production_route_key']
        for field, value in [('raw_sha256', 'sha256:'+'4'*64), ('git_blob_oid', '5'*40), ('byte_length', 3)]:
            bad = copy.deepcopy(sources); bad[0][field] = value
            self.assertNotEqual(original, M.keyed(bad, images, {})['production_route_key'])
        self.assertNotEqual(original, M.keyed(sources, images, {'core.autocrlf': 'true'})['production_route_key'])
        self.assertTrue(M.included('sdk/conformance/r10dh_campaign.py'))
        self.assertTrue(M.included('sdk/recovery/r10dh_held_out_finite_decision_design_v1.json'))
        self.assertFalse(M.included(M.AUTHORITY))
        with self.assertRaises(ValueError): M.keyed(sources*2, images, {})

    def test_contract_change_refused(self):
        for key, bad in [('required_kicked_entry_kind', 'partial'), ('maximum_workers', 2),
                         ('physical_timeout_seconds', 2400), ('physical_execution_authorized', True)]:
            v = C.read(C.TASK); v[key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError): C.validate_task(v)
        for key, bad in [('retry_permitted', True), ('maximum_world_attempts', True), ('all_cells_must_pass', False)]:
            v = C.read(C.DESIGN); v['held_out'][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError): C.validate_design(v)


if __name__ == '__main__': unittest.main(verbosity=2)
