"""R10K cross-language route integration before any development world."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate
from development_passive_entry_profile import _source_snapshot
from test_development_r10k_worker_component import GODOT, write

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10k-v51-partial-fall-integrated-v23.json'
INPUT = EVIDENCE / 'development-v51-walking-adapter-756cb143d8214f019a816292206406e3/input.json'


class R10KRouteSelection(unittest.TestCase):
    def test_complete_candidate_selection_and_crossed_contracts(self):
        selected = candidate.selection(candidate.reference_for_path(PROFILE))
        schedule = selected['diagnostic_schedule']
        self.assertEqual('r10k_v51_partial_fall_recovery_route_v1', candidate.walking_policy_id(schedule))
        self.assertEqual((320, 30, 1, 240, 3160, 3512), tuple(candidate.limits(selected).values()))
        for key in ['walking_entry_profile_id', 'walking_start_profile_id', 'walking_policy_id', 'walking_policy_contract_sha256', 'runtime_sha256']:
            with self.subTest(key=key), self.assertRaises(ValueError):
                candidate.walking_policy_id(dict(schedule, **{key: 'crossed'}))

    def test_actual_worker_prefix_and_four_native_routes(self):
        out = Path(os.environ.get('SPORE_R10K_ROUTE_ROOT', str(EVIDENCE / ('development-r10k-route-selection-' + uuid.uuid4().hex))))
        out.mkdir(exist_ok=False)
        print('R10K_ROUTE_SELECTION_EVIDENCE ' + str(out), flush=True)
        before = _source_snapshot()
        write(out / 'source_before.json', before)
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10k_route_selection.gd', '--', str(INPUT), str(out / 'result.json')]
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
        self.assertEqual(before, after, 'R10K_ROUTE_SOURCE_DRIFT')
        error = (out / 'stderr.log').read_text(encoding='utf-8')
        self.assertEqual(0, process.returncode, error)
        self.assertNotIn('ERROR:', error)
        result = json.loads((out / 'result.json').read_bytes())
        self.assertTrue(result['ok'], result['checks'])
        self.assertEqual(45, len(result['checks']))
        for label in ['resume', 'matched', 'ramp', 'hold']:
            ledger = result['result'][label]['ledger']
            self.assertTrue(ledger['ok'])
            self.assertEqual(8, ledger['detached_hinge_parameter_container_count'])
            self.assertEqual((0, 0, 0), (ledger['world_build_count'], ledger['scene_tree_insertion_count'], ledger['solver_step_count']))


if __name__ == '__main__':
    unittest.main()
