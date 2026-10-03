"""R10M cross-language route integration before any development world."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
from development_passive_entry_profile import _source_snapshot
from test_development_r10k_worker_component import GODOT, write

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10m-v53-bounded-stop-integrated-v1.json'
INPUT = EVIDENCE / 'development-v51-walking-adapter-756cb143d8214f019a816292206406e3/input.json'


class R10MRouteSelection(unittest.TestCase):
    def test_complete_candidate_selection_and_crossed_contracts(self):
        selected = candidate.selection(candidate.reference_for_path(PROFILE))
        schedule = selected['diagnostic_schedule']
        self.assertEqual('r10m_v53_partial_fall_recovery_route_v1', candidate.walking_policy_id(schedule))
        self.assertEqual((320, 30, 1, 240, 3160, 3512), tuple(candidate.limits(selected).values()))
        for key in ['walking_entry_profile_id', 'walking_start_profile_id', 'walking_policy_id', 'walking_policy_contract_sha256', 'runtime_sha256']:
            with self.subTest(key=key), self.assertRaises(ValueError):
                candidate.walking_policy_id(dict(schedule, **{key: 'crossed'}))

    def test_task_requirements_and_native_recovery_are_unchanged(self):
        old = candidate.read(ROOT / 'sdk/recovery/r10k_partial_fall_finite_cycle_contract_v1.json')
        new = candidate.read(ROOT / 'sdk/recovery/r10m_bounded_stop_velocity_finite_cycle_contract_v1.json')
        for key in ['native_interaction', 'limits', 'finite_walking_observable', 'settled_tail',
                    'whole_walking_envelope', 'partial_recovery', 'prone_recovery']:
            with self.subTest(key=key):
                self.assertEqual(old[key], new[key])
        self.assertEqual('sporespore_balanced_wave_recovery_bounded_stop_velocity_v1',
                         new['controller_composition']['post_interaction_walking'])
        self.assertEqual((40541, 40543), tuple(new['prospective_populations']['development'][key]['seed']
            for key in ['first_attempt', 'additional_branch_diagnostic']))
        self.assertFalse(new['physical_execution_authorized'])
        selected = candidate.selection(candidate.reference_for_path(PROFILE))
        self.assertEqual(selected['candidate']['runtime_sha256'], new['controller_composition']['native_runtime_sha256'])
        original_read = candidate.read
        for field in ('native_runtime_sha256', 'post_interaction_walking'):
            def crossed_read(path):
                value = original_read(path)
                if Path(path).name == 'r10m_bounded_stop_velocity_finite_cycle_contract_v1.json':
                    value['controller_composition'][field] = 'crossed'
                return value
            with self.subTest(field=field), mock.patch.object(candidate, 'read', side_effect=crossed_read):
                with self.assertRaisesRegex(ValueError, 'R10M_TASK_NATIVE_IDENTITY'):
                    candidate.walking_policy_id(selected['diagnostic_schedule'])

    def test_launcher_refuses_missing_complete_safety_receipts(self):
        # Library mode cannot execute worlds or gate children even if this guard regresses.
        expression = (". ./sdk/run_development_recovery_smoke.ps1 -Library -ProfileSteps -ReuseContextChecks -CandidateProfile '"
                      + PROFILE.as_posix() + "'; Assert-R10MPreparationSafety -CompletedStages @() -SelectedStages $stages")
        command = ['pwsh', '-NoProfile', '-NonInteractive', '-Command', expression]
        process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        out = (Path(os.environ['SPORE_R10M_ROUTE_ROOT']).parent / 'launcher-refusal'
               if 'SPORE_R10M_ROUTE_ROOT' in os.environ else EVIDENCE / ('development-r10m-launcher-refusal-' + uuid.uuid4().hex))
        out.mkdir(exist_ok=False)
        (out / 'stdout.log').write_bytes(process.stdout)
        (out / 'stderr.log').write_bytes(process.stderr)
        write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
              library_mode=True, world_build_count=0, solver_step_count=0))
        self.assertEqual(1, process.returncode)
        self.assertIn(b'R10M_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING', process.stderr)

    def test_actual_worker_prefix_and_four_native_routes(self):
        out = Path(os.environ.get('SPORE_R10M_ROUTE_ROOT', str(EVIDENCE / ('development-r10m-route-selection-' + uuid.uuid4().hex))))
        out.mkdir(exist_ok=False)
        print('R10M_ROUTE_SELECTION_EVIDENCE ' + str(out), flush=True)
        before = _source_snapshot()
        write(out / 'source_before.json', before)
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10m_route_selection.gd', '--', str(INPUT), str(out / 'result.json')]
        started = time.monotonic()
        try:
            with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
            write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
                seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        except subprocess.TimeoutExpired:
            write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
            raise
        finally:
            after = _source_snapshot()
            write(out / 'source_after.json', after)
        self.assertEqual(before, after, 'R10M_ROUTE_SOURCE_DRIFT')
        error = (out / 'stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads((out / 'result.json').read_bytes())
        self.assertTrue(result['ok'], result['checks'])
        self.assertEqual(48, len(result['checks']))
        for label in ['resume', 'matched', 'ramp', 'hold']:
            ledger = result['result'][label]['ledger']
            self.assertTrue(ledger['ok'])
            self.assertEqual(8, ledger['detached_hinge_parameter_container_count'])
            self.assertEqual((0, 0, 0), (ledger['world_build_count'], ledger['scene_tree_insertion_count'], ledger['solver_step_count']))


if __name__ == '__main__':
    unittest.main()
