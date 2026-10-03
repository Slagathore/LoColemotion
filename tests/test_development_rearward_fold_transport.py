"""Re-exercise passive source/transport coverage on the new compiled superset."""
import unittest

import test_development_passive_entry_transport as shared
import test_development_passive_entry_worker as worker


class RearwardFoldTransport(shared.PassiveEntryTransport):
    binding_path = 'sdk/development_rearward_fold_runtime_binding_v1.json'
    native_script = 'tests/test_development_rearward_fold_transport.gd'

    def test_existing_scheduler_deadline_and_handoff_controls(self):
        # Scheduler kernels are pure and need no new physical runtime. Keep
        # all original deadline/one-time-handoff controls in the selected gate.
        worker.PassiveEntryWorker().test_distinct_scheduler_keeps_original_schema_closed()


if __name__ == '__main__':
    unittest.main()
