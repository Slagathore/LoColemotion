"""R10O uses the unchanged cycle/stop kernel on hash-bound exposed measurements.

This checks its shared finite measurement kernel, not a new V52 trajectory.
The selected native V52 command and reader path is exercised separately.
"""
import unittest
import test_development_v50_cycle_stop as shared
class CycleStop(shared.CycleStop):
    pass
if __name__ == '__main__': unittest.main()
