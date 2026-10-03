"""R10O focused native safety; the bound exhaustive startup sweep is retained."""
import json
import os
import unittest
import uuid
from unittest.mock import patch
import test_development_v55_initialized_zero_brake as prior
from development_recovery_candidate_test_support import selected, candidate
from v52_extended_support_transfer import verify

COMPONENT = 'sdk/recovery/v55_initialized_zero_brake_component_v1.json'
COMPONENT_SHA = 'sha256:83dfbc6478bf8fbbb8d0aea21ec0c964b87d67a8edcd8d14f99be1ddafd41ea5'
METHODS = [
    'test_identity_and_original_profile_limits',
    'test_original_policies_and_refusals_remain_byte_exact',
    'test_r10m_native_chains_preserve_startup_and_change_only_later_holding',
    'test_current_memory_on_legacy_histories',
    'test_r10n_exhausted_preparation_remains_a_safe_refusal',
    'test_crossed_state_and_caller_override_refuse',
]

class R10OInitializedBrake(prior.InitializedZeroBrake):
    @classmethod
    def setUpClass(cls):
        choice = selected()
        runtime = candidate.read(candidate.resource_path(choice['candidate']['runtime_binding']))
        if candidate.sha(prior.ROOT / COMPONENT) != COMPONENT_SHA:
            raise ValueError('R10O_EXHAUSTIVE_COMPONENT_RECORD_DRIFT')
        component = candidate.read(prior.ROOT / COMPONENT)
        if runtime['runtime'] != component['runtime'] or component['startup_cases'] != 1800 or component['startup_calls'] != 131400 or component['complete_startup_blend_cases'] != 1800 or component['startup_refusal_counts']:
            raise ValueError('R10O_EXHAUSTIVE_COMPONENT_COVERAGE_MISMATCH')
        for source in runtime['source_files'] + component['retained_evidence']:
            verify(source)
        verify(runtime['runtime'])
        out = prior.ROOT.parent / 'SporeSpore_Evidence' / ('development-r10o-initialized-brake-gate-' + uuid.uuid4().hex)
        out.mkdir()
        print('R10O_INITIALIZED_BRAKE_GATE_EVIDENCE ' + str(out), flush=True)
        with patch.dict(os.environ, SPORE_V55_DLL=runtime['runtime']['path'], SPORE_V55_COMPONENT_ROOT=str(out)):
            super().setUpClass()
        receipt = dict(candidate_profile=choice['candidate_profile'], runtime=runtime['runtime'],
            exhaustive_component=dict(path=COMPONENT, raw_sha256=COMPONENT_SHA),
            executed_tests=METHODS, exhaustive_startup_reexecuted=False,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
        (out / 'selected-runtime.json').write_text(json.dumps(receipt,indent=2)+'\n', encoding='utf-8', newline='\n')

def load_tests(loader, tests, pattern):
    # This exact six-test population is declared by the R10O stage contract.
    return unittest.TestSuite(R10OInitializedBrake(name) for name in METHODS)

if __name__ == '__main__': unittest.main()
