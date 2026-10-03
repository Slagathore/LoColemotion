"""Run every unchanged recovery control and refusal check against the V54 DLL."""
import unittest
import test_development_r10k_control_component as prior

class R10NControlComponent(prior.R10KControlComponent):
    profile_path = prior.ROOT / 'sdk/development/recovery_candidates/v54-zero-velocity-brake-core-v1.json'

if __name__ == '__main__': unittest.main()
