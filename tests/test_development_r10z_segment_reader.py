"""Reopen the actual synthetic R10Z worker segment through its independent reader."""
from pathlib import Path
import sys
import unittest
import uuid
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10z_worker_component as worker
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared

class R10ZSegmentReader(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        cls.out = worker.EVIDENCE / ('r10z-segment-reader-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        record = worker.native.read(worker.RECORD)
        cls.source = worker.native.verify(next(item for item in record['retained_evidence']
            if item['path'].endswith('r10z-worker-e3d182ca97f04cea826e446d24e5b0fe/new-partial.json')))
        shared.write(cls.out / 'input-binding.json', worker.native.diagnosis.binding(cls.source))
        print('R10Z_SEGMENT_READER_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'R10Z_READER_SOURCE_DRIFT'

    def test_actual_worker_segment_and_crossed_sources(self):
        result = self.run_godot('partial-segment', 'test_development_r10z_segment_reader.gd', self.source, 180)
        self.assertEqual(303, result['replay']['transition_count'])
        self.assertEqual(240, result['replay']['entry_observation_count'])
        self.assertEqual(63, result['replay']['partial_observation_count'])
        self.assertFalse(result['full_report_checked'])

if __name__ == '__main__': unittest.main()
