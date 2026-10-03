"""Actual source and recovery bridges using the V52 DLL; no world construction."""
import unittest
import test_development_r10k_source_bridges as prior

class R10MSourceBridges(prior.R10KSourceBridges):
    def run_native(self, name, script, source, expected_checks, timeout):
        choices = {f'res://tests/test_development_r10k_{part}.gd': f'res://tests/test_development_r10m_{part}.gd'
                   for part in ['task_source', 'recovery_stage']}
        return super().run_native(name, choices[script], source, expected_checks, timeout)

if __name__ == '__main__': unittest.main()
