"""Exercise the actual GDScript handoff scheduler without a physical worker."""
import json
import os
import unittest
import uuid

from development_recovery_candidate_test_support import ROOT, selected, arguments
import test_development_passive_entry_replay as shared


class PostRecoverySettling(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        previous = os.environ.get('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE')
        os.environ['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = 'sdk/development/recovery_candidates/r10t-v56-post-recovery-hold-integrated-v1.json'
        try:
            selection = selected()
        finally:
            if previous is None: os.environ.pop('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', None)
            else: os.environ['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = previous
        cls.root = ROOT.parent/'SporeSpore_Evidence'/('r10t-settling-scheduler-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10T_SETTLING_SCHEDULER_ROOT', cls.root, flush=True)
        path = cls.root/'synthetic_input.json'
        path.write_bytes(b'{"synthetic_scheduler_inputs_only":true}\n')
        run = shared.PassiveEntryReplay._run_retained.__func__(cls,
            'res://tests/test_r10t_post_recovery_settling.gd', ['--', str(path), *arguments(selection)], 'scheduler', 120)
        cls.result = shared.marker(run, 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')
        with (cls.root/'result.json').open('x', encoding='utf-8', newline='\n') as output:
            json.dump(cls.result, output, indent=2); output.write('\n')
        assert cls.result['ok'], cls.result

    def check_group(self, prefix):
        selected_checks = {k:v for k,v in self.result['checks'].items() if k.startswith(prefix)}
        self.assertTrue(selected_checks)
        self.assertTrue(all(selected_checks.values()), selected_checks)

    def test_speed_only_upright_and_direct_entry(self): self.check_group('entry_')
    def test_dwell_reset_and_exact_deadline(self): self.check_group('dwell_')
    def test_source_binding_and_memory_integrity(self): self.check_group('integrity_')
    def test_terminal_states_never_step(self): self.check_group('terminal_')
    def test_component_claim_boundary(self):
        self.check_group('scope_')
        self.assertEqual(self.result['native_policy_calls'], 0)
        self.assertEqual(self.result['world_build_count'], 0)
        self.assertFalse(self.result['physical_route_qualified'])


if __name__ == '__main__': unittest.main()
