"""Zero-world controls for isolated Studio timing, never motor semantics."""
import copy
import os
from pathlib import Path
import re
import unittest
import uuid

from materialize_godot_bridge_profile import instrument_walking, validate_walking_profile, WALKING_STAGES

HERE = Path(__file__).resolve().parent


class WalkingProfileControls(unittest.TestCase):
    def project(self):
        folder = Path(os.environ['EXPLORER_TEST_OUTPUT'])/('walking-profile-'+uuid.uuid4().hex)
        walking = folder/'sdk/explorer/studio/godot_live_walking.gd'
        worker = folder/'sdk/explorer/native_recovery/worker.gd'
        for target, name in ((walking, 'godot_live_walking.gd'), (worker, 'godot_live_walking_worker.gd')):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((HERE/name).read_bytes())
        return folder, walking, worker

    def test_original_calls_refusals_and_returns_remain_verbatim(self):
        root, walking, worker = self.project()
        original = walking.read_text(); old_worker = worker.read_text()
        self.assertEqual(instrument_walking(root), list(WALKING_STAGES))
        updated = walking.read_text()
        stripped = re.sub(r'(?m)^[\t]*# _studio_profile_begin[^\n]*\n.*?^[\t]*# _studio_profile_end\n', '', updated, flags=re.S)
        self.assertEqual(stripped.rstrip(), original.rstrip())
        self.assertIn('LiveWalk._studio_profile_rows.clear()', worker.read_text())
        self.assertEqual(worker.read_text().count('studio_live_walking_profile'), 1)
        self.assertLess(worker.read_text().index('studio_live_walking_profile'), worker.read_text().index('"zero_world":LiveChecks.run()'))
        self.assertIn(old_worker.split('\t\t_live_commands=1\n')[0], worker.read_text())
        with self.assertRaisesRegex(ValueError, 'already installed'): instrument_walking(root)

    def test_drift_refused_before_either_file_is_written(self):
        for name in ('sample', 'motor_readbacks_valid', '_live_commands=1', 'message_type'):
            root, walking, worker = self.project()
            target = walking if name in ('sample', 'motor_readbacks_valid') else worker
            target.write_text(target.read_text().replace(name, name+'_changed'), encoding='utf-8', newline='\n')
            before = [p.read_bytes() for p in (walking, worker)]
            with self.assertRaises(ValueError): instrument_walking(root)
            self.assertEqual(before, [p.read_bytes() for p in (walking, worker)])

    def test_profile_population_and_clock_corruption_are_refused(self):
        profile = dict(first_local_command=2, last_local_command=1800,
            preflight_and_first_command_excluded=True, solver_inputs_changed=False,
            stages={stage:dict(calls=1799, total_us=10000, maximum_us=100) for stage in WALKING_STAGES})
        self.assertEqual(validate_walking_profile(dict(studio_live_walking_profile=profile), 1800), profile)
        for mutate in (lambda p:p.update(first_local_command=1), lambda p:p.update(last_local_command=1799),
                       lambda p:p.update(preflight_and_first_command_excluded=False), lambda p:p.update(solver_inputs_changed=True),
                       lambda p:p['stages'].pop('sample'), lambda p:p['stages']['sample'].update(calls=1800),
                       lambda p:p['stages']['sample'].update(total_us=-1), lambda p:p['stages']['sample'].update(maximum_us=10001),
                       lambda p:p['stages']['sample'].update(total_us=10000.0)):
            bad = copy.deepcopy(profile); mutate(bad)
            with self.assertRaises(ValueError): validate_walking_profile(dict(studio_live_walking_profile=bad), 1800)


if __name__ == '__main__':
    unittest.main()
