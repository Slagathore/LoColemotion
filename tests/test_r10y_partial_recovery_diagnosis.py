"""The retained-trace reader must not count duplicate native receipts as steps."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10y_partial_recovery_diagnosis as diagnosis


class PartialTraceReaderTests(unittest.TestCase):
    def fixture(self):
        packet = {'native_receipt': {'step': {'memory': {'total_steps_observed': 1}}}}
        packet['call'] = {'value': packet['native_receipt']}
        return json.dumps(dict(arm_id=diagnosis.KICK, r10v_partial_recovery=dict(
            declaration={'entry_request': {}}, final_memory={'total_steps_observed': 2},
            step_packets=[packet, packet]), r10v_upright_recovery={'step_packets': [packet]},
            seed=51007, source_commit=diagnosis.SOURCES[1]), indent=2)

    def read(self, raw):
        with patch.object(Path, 'open', return_value=io.StringIO(raw)):
            return list(diagnosis.read_partial(Path('bound-report.json')))

    def test_only_partial_packets_count_once_and_late_metadata_survives(self):
        rows = self.read(self.fixture())
        self.assertEqual(2, sum(k == 'packet' for k, _ in rows))
        metadata = {k: v for k, v in rows if k != 'packet'}
        self.assertEqual(51007, metadata['seed'])
        self.assertEqual(diagnosis.SOURCES[1], metadata['source_commit'])
        self.assertEqual({'total_steps_observed': 2}, metadata['final_memory'])

    def test_incomplete_packet_and_section_refuse(self):
        raw = self.fixture()
        for clipped in (raw[:raw.index('    "step_packets"') + 24],
                        raw[:raw.index('  "r10v_upright_recovery"')].rstrip().removesuffix('},')):
            with self.subTest(clipped=clipped[-30:]), self.assertRaises(ValueError):
                self.read(clipped)

    def test_missing_or_empty_partial_population_refuses(self):
        for raw in ('{}', json.dumps({'r10v_partial_recovery': {'step_packets': []}}, indent=2)):
            with self.assertRaisesRegex(ValueError, 'R10Y_DIAGNOSIS_'):
                self.read(raw)

    def test_duplicate_partial_section_refuses(self):
        raw = self.fixture()
        duplicate = raw[:-1] + ',\n' + raw[2:]
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_PARTIAL_SECTION'):
            self.read(duplicate)


if __name__ == '__main__':
    unittest.main()
