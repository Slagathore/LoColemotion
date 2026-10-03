"""Re-use the complete passive-transport suite on the profile-bound DLL."""
import unittest
import test_development_passive_entry_transport as shared
import test_development_passive_entry_worker as worker
from development_recovery_candidate_test_support import selected


class CandidateTransport(shared.PassiveEntryTransport):
    native_script = 'tests/test_development_recovery_candidate_transport.gd'

    @classmethod
    def setUpClass(cls):
        cls.binding_path = selected()['candidate']['runtime_binding'].removeprefix('res://')
        super().setUpClass()

    def test_existing_scheduler_deadline_and_handoff_controls(self):
        worker.PassiveEntryWorker().test_distinct_scheduler_keeps_original_schema_closed()

    def test_new_runtime_binding_is_not_worker_or_physical_authority(self):
        # The generic build manifest describes a compiled artifact, not whether
        # a separately bound worker has subsequently been integrated. Keep the
        # historical test unchanged for the historical manifest schema.
        if self.binding['schema_version'] != 'sporespore_development_recovery_candidate_runtime_binding_v1':
            return super().test_new_runtime_binding_is_not_worker_or_physical_authority()
        for field in ('default_godot_extension_changed', 'old_pinned_adapter_overwritten',
                      'qualification_authority', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(self.binding[field], False, field)
        for field in ('world_build_count', 'solver_step_count'):
            self.assertEqual(0, self.binding[field], field)
            self.assertIs(type(self.binding[field]), int, field)
        self.assertEqual('development_runtime_artifact_binding', self.binding['ledger_scope']['authority_mode'])


if __name__ == '__main__':
    unittest.main()
