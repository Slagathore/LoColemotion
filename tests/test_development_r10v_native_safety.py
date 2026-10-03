"""R10V startup budget for the unchanged three-test native safety population."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import test_development_recovery_smoke as original

CONTRACT = Path(__file__).resolve().parents[1] / 'sdk/development/r10v_safety_stage_contract_v3.json'
UNBOUND_WORKER = 'sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd'


class R10VNativeSafetySuite(unittest.TestSuite):
    def run(self, result, debug=False):
        native = original.native
        startup_timeout = json.loads(CONTRACT.read_bytes())['native_startup_timeouts_seconds']['shared_unbound_worker']
        if type(startup_timeout) is not int or startup_timeout != 60:
            raise ValueError('R10V_UNBOUND_STARTUP_DEADLINE_INVALID')

        def bounded_native(script, *, timeout=300):
            # Preserve the original 300-second complete setup. Only the exact
            # unbound worker call receives this prospective startup allowance.
            if script == UNBOUND_WORKER:
                if timeout != 20:
                    raise ValueError('R10V_UNEXPECTED_UNBOUND_CALL_DEADLINE')
                return native(script, timeout=startup_timeout)
            return native(script, timeout=timeout)

        with patch.object(original, 'native', bounded_native):
            return super().run(result, debug)


def load_tests(loader, tests, pattern):
    return R10VNativeSafetySuite(loader.loadTestsFromTestCase(original.DevelopmentSmoke))
