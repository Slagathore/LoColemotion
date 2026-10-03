"""Apply the established finite-envelope refusal controls to the R10N contract."""
import unittest
from unittest import mock

import test_r10j_finite_task_audit as shared
import r10n_finite_task_audit as r10n


class R10NFiniteTaskAudit(shared.FiniteTaskAudit):
    def setUp(self):
        # Reuse the same boundary and corruption cases with the new real auditor.
        # No measurement function or predicate is mocked.
        selected = mock.patch.object(shared, 'audit', r10n)
        selected.start()
        self.addCleanup(selected.stop)


if __name__ == '__main__':
    unittest.main()
