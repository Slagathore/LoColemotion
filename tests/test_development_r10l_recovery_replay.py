"""Fresh worker and reader processes for R10L; synthetic inputs, zero worlds."""
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
from development_passive_entry_profile import _source_snapshot
from test_development_r10k_worker_component import GODOT, FIXTURES, write


class R10LRecoveryReplay(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10L_REPLAY_ROOT', str(EVIDENCE / ('development-r10l-recovery-replay-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = _source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10L_RECOVERY_REPLAY_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10L_REPLAY_SOURCE_DRIFT')

    def run_godot(self, name, script, args):
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script', script, '--', *map(str, args)]
        started = time.monotonic()
        with (self.out / (name + '.stdout.log')).open('xb') as stdout, (self.out / (name + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                    timeout=240, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (name + '.execution.json'), dict(command=command, timed_out=True,
                    direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        write(self.out / (name + '.execution.json'), dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (name + '.stderr.log')).read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error + (self.out / (name + '.stdout.log')).read_text(encoding='utf-8')[-3000:])

    def branch(self, mode, entry_count, canonical_count, partial_count):
        fixture = self.out / (mode + '.fixture.json')
        self.run_godot(mode + '-producer', 'res://tests/test_development_r10l_replay_fixture.gd', [FIXTURES, fixture, mode])
        result_path = self.out / (mode + '.result.json')
        self.run_godot(mode + '-reader', 'res://tests/test_development_r10l_replay_reader.gd', [fixture, result_path])
        result = json.loads(result_path.read_bytes())
        self.assertTrue(result['ok'], result)
        replay = result['replay']
        self.assertEqual((entry_count, canonical_count, partial_count), (replay['entry_observation_count'],
            replay['canonical_observation_count'], replay.get('partial_observation_count', 0)))
        self.assertEqual((0, 0), (replay['world_build_count'], replay['solver_step_count']))
        self.assertFalse(replay['physical_acceptance_authority'] or replay['release_authority'])

    def test_partial_fall_complete_recovery_segment(self):
        self.branch('partial', 240, 0, 63)

    def test_prone_real_confirmation_and_canonical_steps(self):
        self.branch('prone', 1, 13, 0)

    def test_legacy_replay(self):
        self.branch('legacy', 1, 13, 0)


if __name__ == '__main__':
    unittest.main()
