"""R10J preserves the existing V50 finite-cycle and stop measurements."""
import unittest
import test_development_v50_cycle_stop as shared
class CycleStop(shared.CycleStop):
    pass
if __name__ == "__main__": unittest.main()
