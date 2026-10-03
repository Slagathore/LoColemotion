"""Real R10Z walking/hold session interfaces and original-route regression.

Run under the native operation lock. Detached native sessions and joints do not
construct a creature or step a physics world. Full launch remains unqualified.
"""
from pathlib import Path
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10z_native_component as native
from development_passive_entry_profile import _source_snapshot
import test_development_r10q_source_orchestration as shared


class R10ZHoldRouteInterface(unittest.TestCase):
    run_godot = shared.R10QSourceOrchestration.run_godot

    @classmethod
    def setUpClass(cls):
        native.runtime()  # Exact DLL and compiled source binding, before loading.
        cls.out = native.EVIDENCE / ('r10z-hold-route-interface-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = _source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        cls.input = native.EVIDENCE / 'development-v51-walking-adapter-756cb143d8214f019a816292206406e3/input.json'
        shared.write(cls.out / 'input-binding.json', native.diagnosis.binding(cls.input))
        print('R10Z_HOLD_ROUTE_INTERFACE_ROOT ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = _source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'source drift during interface tests'

    def test_successor_sessions_motor_commands_and_cold_refusals(self):
        result = self.run_godot('successor', 'test_r10z_hold_route_interface.gd', self.input, 180)
        self.assertTrue(result['checks']['launch_authority_still_refused'])
        self.assertTrue(result['checks']['post_hold_cold_native_replay'])
        for variant in ('resume', 'ramp', 'hold', 'post_hold'):
            self.assertTrue(result['checks'][variant + '_production_motor_ledger'])
        self.assertFalse(result['physical_route_qualified'])

    def test_original_route_sessions_still_pass(self):
        result = self.run_godot('original', 'test_r10z_original_hold_route_interface.gd', self.input, 180)
        self.assertTrue(result['checks']['post_hold_cold_native_replay'])
        self.assertFalse(result['physical_route_qualified'])

    def test_report_policy_and_contact_population_refusals(self):
        contract = ROOT / 'sdk/recovery/r10z_v50_post_recovery_hold_policy_contract_v1.json'
        fixed = native.read(contract)
        # Explicitly synthetic identity rows exercise routing only. Motor command
        # and native response verification belong to the interface test above.
        start = dict(schema_version=fixed['receipt_schema_prefix'] + 'session_v1',
            selected_policy_id=fixed['policy_id'],
            selected_policy_digest=native.diagnosis.binding(contract)['raw_sha256'],
            development_walking_policy_id=fixed['selection_id'],
            controller_profile_sha256=fixed['native_profile_sha256'])
        session = dict(session_id='r10z-synthetic-hold-policy-selection',
            evaluation_segment_id='v50_post_recovery_settling', start_receipt=start,
            completion_receipt=dict(adapter_summary=dict(controller_policy_id=fixed['policy_id'])))
        source = self.out / 'synthetic-policy-report.json'
        shared.write(source, dict(synthetic_identity_rows_only=True,
            report=dict(retained_arm=dict(walking_sessions=[session]))))
        result = self.run_godot('policy-report', 'test_r10z_hold_policy_report.gd', source, 60)
        self.assertEqual(15, len(result['checks']))


if __name__ == '__main__':
    unittest.main()
