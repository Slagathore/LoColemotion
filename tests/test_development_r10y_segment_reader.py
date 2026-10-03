"""Reopen the actual synthetic R10Y worker segment through its independent reader."""
from pathlib import Path
import sys
import unittest
import uuid
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10y_worker_component as worker
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10YSegmentReader(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = worker.EVIDENCE / ('r10y-segment-reader-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        record = worker.native.read(worker.RECORD)
        cls.source = worker.native.verify(next(item for item in record['retained_evidence']
            if item['path'].endswith('r10y-worker-8b05d840800c4b409709f847b2119c1d/new-partial.json')))
        shared.write(cls.out / 'input-binding.json', worker.native.diagnosis.binding(cls.source))
        print('R10Y_SEGMENT_READER_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'R10Y_READER_SOURCE_DRIFT'

    def test_actual_worker_segment_and_crossed_sources(self):
        result = self.run_godot('partial-segment', 'test_development_r10y_segment_reader.gd', self.source, 180)
        self.assertEqual(303, result['replay']['transition_count'])
        self.assertEqual(240, result['replay']['entry_observation_count'])
        self.assertEqual(63, result['replay']['partial_observation_count'])
        self.assertFalse(result['full_report_checked'])

if __name__ == '__main__': unittest.main()
