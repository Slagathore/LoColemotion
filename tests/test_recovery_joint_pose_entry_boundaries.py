"""Actual retained report boundaries and 240 commands through Godot's native bridge."""
import hashlib
import json
from pathlib import Path
import unittest
import uuid
from development_recovery_candidate_test_support import selected, arguments, ROOT
import test_development_passive_entry_replay as shared


class JointPoseEntryBoundaries(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = ROOT.parent / 'SporeSpore_Evidence' / ('r10i-entry-boundaries-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10I_ENTRY_BOUNDARIES_ROOT', cls.root, flush=True)
        closure = json.loads((ROOT / 'sdk/recovery/r10h_stance_entry_pair_closure_v1.json').read_bytes())
        reports = []
        for role in ('matched_no_kick_continuation', 'kick_passive_recovery_resume'):
            ref = closure['roles'][role]['report']
            raw = Path(ref['path']).read_bytes()
            assert 'sha256:'+hashlib.sha256(raw).hexdigest() == ref['raw_sha256']
            reports.append(shared.parse_json(raw))
        baseline, kicked = reports
        # Project only complete existing session, handoff, transition and request
        # objects needed here. Never edit an observed file or claim new behavior.
        arm = baseline['retained_arm']
        item = dict(arm=dict(walking_sessions=[s for s in arm['walking_sessions'] if s['evaluation_segment_id'] == 'neutral_stance_entry'],
                            walking_actuation_handoff_receipts=arm['walking_actuation_handoff_receipts']),
                    kicked_transitions=[dict(event=t['event'], advance=t['advance']) for t in kicked['passive_entry']['orchestrator_transitions']],
                    requests=[r['step']['sample_receipt']['request'] for r in baseline['stance_entry']['neutral_control_rows']])
        path = cls.root / 'retained_interface_inputs.json'
        path.write_text(json.dumps(item, separators=(',', ':'), allow_nan=False)+'\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_recovery_joint_pose_entry_boundaries.gd',
                                ['--', str(path), *arguments(cls.selection)], 'boundaries', 90)
        rows = [shared.parse_json(line.split(' ', 1)[1]) for line in run.stdout.decode().splitlines() if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
        if len(rows) != 1 or b'ERROR:' in run.stdout+run.stderr:
            raise AssertionError((run.returncode, run.stdout[-3000:], run.stderr[-3000:]))
        cls.result = rows[0]

    def check(self, prefix):
        checks = {k: v for k, v in self.result['checks'].items() if k.startswith(prefix)}
        self.assertTrue(checks)
        self.assertTrue(all(checks.values()), (checks, self.result.get('failure')))

    def test_actual_arm_handoff_location_and_three_corruptions(self):
        self.check('handoff_')

    def test_actual_kicked_completion_phase_and_wrong_alias(self):
        self.check('recovery_')

    def test_240_native_session_responses_equal_stateless_bytes(self):
        self.check('transport_')
        self.assertEqual(240, self.result['native_commands'])
        self.assertEqual(0, self.result['world_build_count'])
        self.assertEqual(0, self.result['solver_step_count'])


if __name__ == '__main__':
    unittest.main()
