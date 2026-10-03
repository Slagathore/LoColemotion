"""R10U worker selectors and actual native facade starts, with no world."""
import json
import unittest
import uuid
from pathlib import Path
import test_development_passive_entry_replay as retained
ROOT = Path(__file__).resolve().parents[1]
class HoldRouteInterface(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / 'SporeSpore_Evidence' / ('r10u-hold-route-interface-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10U_HOLD_ROUTE_INTERFACE_ROOT', cls.root, flush=True)
        source = ROOT.parent / 'SporeSpore_Evidence/development-v51-walking-adapter-756cb143d8214f019a816292206406e3/input.json'
        output = cls.root / 'result.json'
        run = retained.PassiveEntryReplay._run_retained.__func__(cls, 'res://tests/test_r10u_hold_route_interface.gd', ['--',str(source),str(output)], 'interface', 180)
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
