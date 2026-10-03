"""Run every unchanged recovery control and refusal check against the V52 DLL."""
import unittest
import test_development_r10k_control_component as prior

class R10MControlComponent(prior.R10KControlComponent):
    profile_path = prior.ROOT / 'sdk/development/recovery_candidates/v53-bounded-stop-velocity-core-v1.json'

if __name__ == '__main__': unittest.main()
