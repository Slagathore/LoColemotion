"""R10J hold: actual retained R10I boundaries, 240 counterfactual V50 hold commands through Godot's native bridge, and the real hold scheduler."""
import hashlib
import json
from pathlib import Path
import unittest
import uuid
from development_recovery_candidate_test_support import selected, arguments, ROOT
import test_development_passive_entry_replay as shared


class V50HoldEntryBoundaries(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = ROOT.parent / 'SporeSpore_Evidence' / ('r10j-hold-boundaries-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10J_HOLD_BOUNDARIES_ROOT', cls.root, flush=True)
        closure = json.loads((ROOT / 'sdk/recovery/r10i_flexed_entry_pair_closure_v1.json').read_bytes())
        reports = []
        for role in ('matched_no_kick_continuation', 'kick_passive_recovery_resume'):
            ref = closure['roles'][role]['report']
            raw = Path(ref['path']).read_bytes()
            assert 'sha256:'+hashlib.sha256(raw).hexdigest() == ref['raw_sha256']
            reports.append(shared.parse_json(raw))
        baseline, kicked = reports
        # Project only complete existing session, handoff, transition, request and
        # readiness-projection objects. Never edit an observed file or claim new behavior.
        arm = baseline['retained_arm']
        rows = baseline['stance_entry']['neutral_control_rows']
        readiness = baseline['stance_entry']['readiness_rows']
        assert len(rows) == 240 and len(readiness) == 240
        # The hold opens where the R10I ramp closed: use only the retained post-ramp observations.
        complete = [r['step']['portable_step_receipt']['native_output']['next_memory']['joint_pose_entry']['reference_ramp_complete'] for r in rows]
        first = complete.index(True)
        assert first == 163 and all(complete[first:])
        rows = rows[first:]
        readiness = readiness[first:]
        cls.expected_count = len(rows)
        item = dict(expected_count=cls.expected_count,arm=dict(walking_sessions=[s for s in arm['walking_sessions'] if s['evaluation_segment_id'] == 'neutral_stance_entry'],
                            walking_actuation_handoff_receipts=arm['walking_actuation_handoff_receipts']),
                    kicked_transitions=[dict(event=t['event'], advance=t['advance']) for t in kicked['passive_entry']['orchestrator_transitions']],
                    requests=[r['step']['sample_receipt']['request'] for r in rows],
                    frames=[dict(floor_reference=r['source']['projection']['request']['floor_reference'],
                                 measured_body_frame=r['source']['projection']['request']['measured_body_frame'],
                                 state=r['source']['projection']['request']['state']) for r in readiness])
        path = cls.root / 'retained_interface_inputs.json'
        path.write_text(json.dumps(item, separators=(',', ':'), allow_nan=False)+'\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_recovery_v50_hold_entry_boundaries.gd',
                                ['--', str(path), *arguments(cls.selection)], 'hold_boundaries', 120)
        lines = [shared.parse_json(line.split(' ', 1)[1]) for line in run.stdout.decode().splitlines() if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
        if len(lines) != 1 or b'ERROR:' in run.stdout+run.stderr:
            raise AssertionError((run.returncode, run.stdout[-3000:], run.stderr[-3000:]))
        cls.result = lines[0]

    def check(self, prefix):
        checks = {k: v for k, v in self.result['checks'].items() if k.startswith(prefix)}
        self.assertTrue(checks)
        self.assertTrue(all(checks.values()), (checks, self.result.get('failure')))

    def test_actual_arm_handoff_recovery_phase_and_hold_binding(self):
        self.check('handoff_')
        self.check('recovery_')
        self.check('hold_')

    def test_post_ramp_counterfactual_hold_commands_converge_and_equal_stateless_bytes(self):
        self.check('transport_')
        self.assertEqual(self.expected_count, self.result['native_commands'])
        self.assertEqual(77, self.expected_count)
        self.assertGreater(self.result['first_target_error_rad'], 0.5)
        self.assertLess(self.result['last_target_error_rad'], 0.15)
        self.assertLess(self.result['last_target_error_rad'] * 3.0, self.result['first_target_error_rad'])
        self.assertEqual(0, self.result['world_build_count'])
        self.assertEqual(0, self.result['solver_step_count'])

    def test_actual_hold_scheduler_ramp_closure_dwell_and_both_timeouts(self):
        self.check('scheduler_')


if __name__ == '__main__':
    unittest.main()
