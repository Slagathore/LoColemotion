"""V52 native support-transfer controls on the candidate-selected runtime."""
import json
import os
import unittest
import uuid
from unittest.mock import patch
import test_development_v52_extended_support_transfer as prior
from development_recovery_candidate_test_support import selected, candidate

class R10LExtendedTransfer(prior.ExtendedSupportTransfer):
    @classmethod
    def setUpClass(cls):
        choice = selected()
        binding = candidate.read(candidate.resource_path(choice['candidate']['runtime_binding']))
        out = prior.ROOT.parent / 'SporeSpore_Evidence' / ('development-r10l-transfer-gate-' + uuid.uuid4().hex)
        out.mkdir()
        print('R10L_TRANSFER_GATE_EVIDENCE ' + str(out), flush=True)
        # Only environment configuration is scoped here; native calls are real.
        with patch.dict(os.environ, SPORE_V52_DLL=binding['runtime']['path'], SPORE_V52_COMPONENT_ROOT=str(out)):
            super().setUpClass()
        # setUpClass has no test instance; retain this shared receipt directly.
        with (out / 'selected-runtime.json').open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(dict(candidate_profile=choice['candidate_profile'], runtime=binding['runtime']), stream, indent=2, allow_nan=False)
            stream.write('\n')

if __name__ == '__main__': unittest.main()
