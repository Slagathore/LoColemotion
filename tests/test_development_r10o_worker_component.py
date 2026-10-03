"""Exercise unchanged recovery hooks with the new R10O selection and V55 DLL."""
import unittest
import test_development_r10k_worker_component as prior


class R10OWorkerComponent(prior.R10KWorkerComponent):

    def run_godot(self, name, script, source, count, mode=None):
        if script == 'res://tests/test_development_r10k_orchestrator.gd':
            return super().run_godot(name, 'res://tests/test_development_r10o_orchestrator.gd', source, count, mode)
        self.assertEqual('res://tests/test_development_r10k_worker_hooks.gd', script)
        return super().run_godot(name, 'res://tests/test_development_r10o_worker_hooks.gd', source, count + 1, mode)


if __name__ == '__main__':
    unittest.main()
