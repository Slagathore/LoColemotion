"""Cold terminal replay of the exact native startup study dependency key."""
import json
import unittest
import uuid
from pathlib import Path
import test_development_r10q_startup_sweep as sweep
import r10q_startup_sweep_component as component

class StartupReceipt(unittest.TestCase):
    def test_exact_component_key_and_all_terminal_native_bytes(self):
        out = sweep.EVIDENCE / ('r10q-startup-receipt-' + uuid.uuid4().hex)
        out.mkdir()
        print('R10Q_STARTUP_RECEIPT_EVIDENCE ' + str(out), flush=True)
        before = sweep._source_snapshot()
        sweep.write(out / 'source_before.json', before)
        result = component.audit(component.read(component.RECORD), cold=True)
        sweep.write(out / 'result.json', result)
        after = sweep._source_snapshot()
        sweep.write(out / 'source_after.json', after)
        self.assertEqual(before, after)
        self.assertEqual((3600, 563400, 0, 3600), tuple(result[k] for k in
            ('phase_cases', 'phase_step_calls', 'refused_cases', 'terminal_inputs_cold_replayed')))
        self.assertTrue(result['ok'])
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])

if __name__ == '__main__': unittest.main()
