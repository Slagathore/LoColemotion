"""Actual worker transition and publication hooks on synthetic hold samples."""
import json
import unittest
import uuid
from pathlib import Path
import test_development_passive_entry_replay as retained
ROOT = Path(__file__).resolve().parents[1]
class WorkerSettlingBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / 'SporeSpore_Evidence' / ('r10u-worker-settling-boundary-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10U_WORKER_SETTLING_BOUNDARY_ROOT', cls.root, flush=True)
        source = ROOT.parent / 'SporeSpore_Evidence/r10t-settling-orchestrator-8b37b87eb6574f789f128035963ffa54/retained_terminal_inputs.json'
        output = cls.root / 'result.json'
        run = retained.PassiveEntryReplay._run_retained.__func__(cls, 'res://tests/test_r10u_worker_settling_boundary.gd', ['--',str(source),str(output)], 'interface', 180)
        if not output.exists():
            raise AssertionError((run.returncode, run.stdout.decode('utf-8',errors='replace')[-2000:], run.stderr.decode('utf-8',errors='replace')[-5000:]))
        cls.result=json.loads(output.read_text())
        assert cls.result['ok'] and run.returncode == 0, {k:v for k,v in cls.result['checks'].items() if not v}
    def test_worker_and_prefix_selection(self):
        self.assertTrue(all(self.result['checks'].values()))
    def test_no_physical_claim(self):
        self.assertEqual(0,self.result['solver_step_count'])
        self.assertEqual(0,self.result['world_build_count'])
        self.assertFalse(self.result['physical_route_qualified'])
if __name__ == '__main__': unittest.main()
