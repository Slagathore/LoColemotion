"""Reject corrupted retained-cell claims without creating a physical world."""
import copy
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10v_development_closure as closure


class RetainedPopulationClosure(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = closure.read(closure.REVIEW/'population_locations.json')[-1]
        root = closure.EVIDENCE/spec['run']
        declaration = closure.read(root/'declaration.json')
        audit = closure.read(root/'independent_audit.stdout.json')
        child_root = root/'children'/'kick_passive_recovery_resume'
        cls.original = [declaration['children'][0], audit['children'][0], audit['r10v_finite_development']['cells'][0],
            closure.read(child_root/'passive_entry_replay_result.json'),
            closure.root_scalars(child_root/'worker_report.json',
                ['world_build_count','external_kick_application_count','solver_step_count','seed','stop_reason'])]

    def validate(self, rows):
        return closure.check_cell(*rows, 41343, 'prone', 'direct')

    def test_original_prone_cell_is_positive_without_new_physics(self):
        value = self.validate(self.original)
        self.assertEqual((value['solver_steps'],value['walking_commands'],value['physical_kicks']), (2041,1157,1))
        self.assertTrue(value['all_tasks_positive'])

    def test_transplanted_child_identity_is_rejected(self):
        rows = copy.deepcopy(self.original)
        rows[2]['child_attempt_id'] = '0'*32
        with self.assertRaisesRegex(ValueError,'CELL_IDENTITY'): self.validate(rows)

    def test_aggregate_positive_cannot_hide_failed_predicate(self):
        rows = copy.deepcopy(self.original)
        rows[2]['measurement']['predicates']['recovery_completed'] = False
        with self.assertRaisesRegex(ValueError,'CELL_PREDICATES'): self.validate(rows)

    def test_consistent_shortened_replay_still_refuses_original_step_count(self):
        rows = copy.deepcopy(self.original)
        rows[3]['transition_count'] -= 1
        rows[1]['passive_entry_replay'] = copy.deepcopy(rows[3])
        with self.assertRaisesRegex(ValueError,'REPLAY_STEP_COUNT'): self.validate(rows)

    def test_consistent_short_stop_is_rejected(self):
        rows = copy.deepcopy(self.original)
        rows[2]['measurement']['walking']['stopping_commands'] = 119
        rows[3]['finite_walking_measurement'] = copy.deepcopy(rows[2]['measurement']['walking'])
        rows[1]['passive_entry_replay'] = copy.deepcopy(rows[3])
        with self.assertRaisesRegex(ValueError,'FINITE_WALKING'): self.validate(rows)

    def test_development_cell_cannot_grant_acceptance(self):
        rows = copy.deepcopy(self.original)
        rows[2]['measurement']['physical_acceptance_authority'] = True
        with self.assertRaisesRegex(ValueError,'CELL_AUTHORITY'): self.validate(rows)

    def test_failed_prehost_cannot_be_reclassified(self):
        original_read = closure.read
        def changed(path):
            value = original_read(path)
            if Path(path) == closure.FAILED_PREHOST/'qualification.json':
                value['ok'] = True
            return value
        with mock.patch.object(closure,'read',side_effect=changed):
            with self.assertRaisesRegex(ValueError,'FAILED_PREHOST_REGRADED'): closure.failed_prehost()

    def test_negative_control_registry_retains_deliberately_crossed_request(self):
        # The successful host qualification intentionally mutated this request.
        # Retention must preserve its observed bytes without "repairing" them.
        probe = closure.EVIDENCE/'r10v-production-host-5419ec8147634c0a8fcd053bdef48983'
        self.assertIn(probe, closure.evidence_roots())


if __name__ == '__main__':
    unittest.main()
