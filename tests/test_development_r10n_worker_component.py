"""Exercise unchanged recovery hooks with the new R10N selection and V54 DLL."""
import unittest
import test_development_r10k_worker_component as prior


class R10NWorkerComponent(prior.R10KWorkerComponent):

    def run_godot(self, name, script, source, count, mode=None):
        if script == 'res://tests/test_development_r10k_orchestrator.gd':
            return super().run_godot(name, 'res://tests/test_development_r10n_orchestrator.gd', source, count, mode)
        self.assertEqual('res://tests/test_development_r10k_worker_hooks.gd', script)
        return super().run_godot(name, 'res://tests/test_development_r10n_worker_hooks.gd', source, count + 1, mode)


if __name__ == '__main__':
    unittest.main()
