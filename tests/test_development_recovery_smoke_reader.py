"""Small refusal controls for smoke labels, bounds, and library-only loading."""
import copy
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_smoke as reader


class SmokeReader(unittest.TestCase):
    def fixture(self):
        descriptor = dict(role=reader.ROLES[0], child_attempt_id='a' * 32)
        declaration = dict(source_snapshot=dict(head='b' * 40), attempt_id='c' * 32,
                           maximum_precondition_steps=320, walking_prefix_steps=30, interaction_steps=1,
                           after_interaction_steps=30, maximum_steps_per_child=382)
        report = dict(schema_version=reader.SCHEMA, work_id=reader.WORK, source_commit='b' * 40,
            parent_attempt_id='c' * 32, child_attempt_id='a' * 32, arm_id=reader.ROLES[0], process_id=123,
            seed=40200, maximum_solver_step_count=382, model_construction_attempt_count=1,
            model_construction_count=1, world_attempt_count=1, world_build_count=1,
            complete_route_proven=False, held_out=False, physical_acceptance_authority=False,
            release_authority=False, behavioral_conclusion='none', telemetry_profile='unchanged_full_per_step_capture',
            ok=True, solver_step_count=302, global_solver_frame_count=302,
            after_interaction_step_count=30, coverage_complete=True, status='development_smoke_complete',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='unofficial_physical_smoke', question_class='development'))
        return report, descriptor, declaration

    def test_synthetic_header_only_not_a_physical_route(self):
        report, descriptor, declaration = self.fixture()
        reader.validate_header(report, descriptor, declaration, 123)
        report['coverage_complete'] = False
        report['status'] = 'development_smoke_coverage_incomplete'
        reader.validate_header(report, descriptor, declaration, 123)

    def test_missing_promoted_crossed_and_out_of_bound_headers_refuse(self):
        report, descriptor, declaration = self.fixture()
        cases = [(key, None) for key in report]
        cases += [('schema_version', 'sporespore_qsdk_r10f_process_isolated_child_raw_v1'),
                  ('work_id', 'QSDK-R10F-L15-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT'),
                  ('complete_route_proven', True), ('physical_acceptance_authority', True),
                  ('release_authority', True), ('world_build_count', True), ('world_build_count', 2),
                  ('solver_step_count', 383), ('solver_step_count', 0), ('solver_step_count', 302.0),
                  ('after_interaction_step_count', 31), ('after_interaction_step_count', -1),
                  ('coverage_complete', 'true'), ('process_id', 124), ('process_id', 123.0),
                  ('child_attempt_id', 'd' * 32), ('source_commit', 'e' * 40)]
        for key, value in cases:
            with self.subTest(key=key, value=value):
                changed = copy.deepcopy(report)
                changed[key] = value
                with self.assertRaises((ValueError, TypeError)):
                    reader.validate_header(changed, descriptor, declaration, 123)

    def test_actual_library_mode_loads_but_rejects_execution_flags(self):
        host = 'C:/Program Files/PowerShell/7/pwsh.exe'
        source = 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'
        for flags, expected in (([], 0), (['-RunPhysical'], 1), (['-L15'], 1)):
            result = subprocess.run([host, '-NoProfile', '-NonInteractive', '-File', source,
                                     '-DevelopmentLibrary', *flags], cwd=ROOT, capture_output=True,
                                    timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
            self.assertEqual(expected, result.returncode, result.stderr)
            if expected:
                self.assertIn(b'DEVELOPMENT_LIBRARY_EXECUTION_FLAGS_FORBIDDEN', result.stderr)
            else:
                self.assertEqual(b'', result.stdout)


if __name__ == '__main__':
    unittest.main()
