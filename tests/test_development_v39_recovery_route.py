"""V39 data selection for the shared worker and frozen-source closure resolver."""
import unittest
from unittest import mock
import test_development_v32_recovery_route as shared


class AirborneReferenceRecoveryRoute(shared.RecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_airborne_reference_v1'
    run_label = 'V39'
    contract_family = 'airborne_reference'
    contract_version = 1

    def test_python_policy_selection_requires_complete_explicit_pair(self):
        super().test_python_policy_selection_requires_complete_explicit_pair()
        import development_recovery_candidate_checkpoint as checkpoint
        schedule = self.selection['diagnostic_schedule']
        def projected(path, source):
            self.assertEqual('owned-'+self.run_label.lower()+'-integration-projection', source)
            return (shared.ROOT/path).read_bytes()
        with mock.patch.object(checkpoint.prior, 'committed', side_effect=projected):
            sources = checkpoint.walking_entry_rule_sources(schedule, 'owned-'+self.run_label.lower()+'-integration-projection')
            paths = {source['path'] for source in sources}
            for part in ('entry', 'start', 'policy'):
                self.assertIn('sdk/development/recovery_'+self.contract_family+'_walking_'+part+'_contract_v'+str(self.contract_version)+'.json', paths)
            self.assertIn('sdk/core/src/runtime.rs', paths)
            for key in ('walking_entry_profile_id','walking_start_profile_id','walking_policy_id',
                        'walking_policy_contract_sha256','runtime_sha256'):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    checkpoint.walking_entry_rule_sources(dict(schedule, **{key:'wrong'}), 'owned-'+self.run_label.lower()+'-integration-projection')
        def corrupt(path, source):
            raw = projected(path, source)
            return raw+b'\n' if path.endswith('runtime.rs') else raw
        with mock.patch.object(checkpoint.prior, 'committed', side_effect=corrupt), self.assertRaisesRegex(ValueError, 'BOUND_SOURCE'):
            checkpoint.walking_entry_rule_sources(schedule, 'owned-'+self.run_label.lower()+'-integration-projection')


if __name__=='__main__':
    unittest.main()
