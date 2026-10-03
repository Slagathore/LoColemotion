"""Original development data exercises the prospective task auditor; no worlds."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'sdk/python'))
import r10j_finite_task_audit as audit
from sporespore_locomotion import LocomotionCore


class RetainedTaskAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure = json.loads((ROOT / 'sdk/recovery/r10j_settled_hold_pair_closure_v1.json').read_text())
        cls.binding = json.loads((ROOT / 'sdk/development/recovery_candidates/r10i-joint-pose-entry-core-v1.runtime.json').read_text())
        profile = json.loads((ROOT / 'sdk/development/recovery_candidates/r10j-v50-settled-hold-integrated-v1.json').read_text())
        path = Path(cls.binding['runtime']['path'])
        with path.open('rb') as stream:
            cls.runtime_sha = 'sha256:'+hashlib.file_digest(stream, 'sha256').hexdigest()
        if cls.runtime_sha != profile['runtime_sha256']:
            raise ValueError('R10J_RETAINED_TASK_RUNTIME_DRIFT')
        cls.core = LocomotionCore(path)

    def load(self, role):
        bound = self.closure['roles'][role]['report']
        path = Path(bound['path'])
        with path.open('rb') as stream:
            self.assertEqual(bound['raw_sha256'], 'sha256:'+hashlib.file_digest(stream, 'sha256').hexdigest())
        self.assertEqual(bound['byte_length'], path.stat().st_size)
        report = json.loads(path.read_text())
        compiled = self.core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
        return report, compiled

    def test_both_retained_roles_meet_task_measurements_without_regrading_failed_launch(self):
        self.assertFalse(self.closure['launcher_ok'])
        self.assertIsNone(self.closure['independent_audit_ok'])
        for role, commands in zip(audit.ROLES, (1088, 1157)):
            with self.subTest(role=role):
                report, compiled = self.load(role)
                result = audit.measure(report, compiled)
                self.assertTrue(result['finite_task_predicates_passed'])
                self.assertEqual(commands, result['envelope']['sample_count'])
                self.assertEqual(7, len(result['envelope']['predicates']))
                for field in ('original_attempt_reclassified', 'physical_acceptance_authority', 'release_authority'):
                    self.assertIs(result[field], False)
                self.assertEqual(0, result['world_build_count'])
                self.assertEqual(0, result['solver_step_count'])
                del report, compiled, result

    def test_one_unsettled_sample_breaks_final_hold_dwell_despite_many_earlier_ready_samples(self):
        report, compiled = self.load(audit.ROLES[0])
        self.assertTrue(audit.entry_measurement(report, compiled)['passed'])
        rows = report['stance_entry']['readiness_rows']
        row = copy.deepcopy(rows[-15])
        source = row['source']
        center = source['packet']['native_source']['observation']['center_of_mass']
        center['linear_velocity_world_m_s']['x'] = 1.
        # A consistent synthetic negative changes the measurement as well as
        # its derived readiness. Forging only the ready flag is a refusal below.
        source['readiness'] = audit.readiness.measure(source['projection']['request'], center, compiled,
                                                       audit.contract()['stance_entry'])
        self.assertFalse(source['readiness']['ready'])
        rows[-15] = row
        result = audit.entry_measurement(report, compiled)
        self.assertFalse(result['passed'])
        self.assertEqual(14, result['final_consecutive_hold_ready'])

    def test_forged_readiness_and_missing_final_measurement_are_refused(self):
        report, compiled = self.load(audit.ROLES[0])
        row = report['stance_entry']['readiness_rows'][-1]
        row['source']['readiness']['ready'] = False
        with self.assertRaisesRegex(ValueError, 'ENTRY_RECOMPUTATION'):
            audit.entry_measurement(report, compiled)
        row['source']['readiness']['ready'] = True
        report['stance_entry']['readiness_rows'].pop()
        with self.assertRaisesRegex(ValueError, 'ENTRY_COMMAND_POPULATION'):
            audit.entry_measurement(report, compiled)


if __name__ == '__main__':
    unittest.main()
