"""Apply the established finite-envelope refusal controls to the R10O contract."""
import unittest
from unittest import mock

import test_r10j_finite_task_audit as shared
import r10o_finite_task_audit as r10o


class R10OFiniteTaskAudit(shared.FiniteTaskAudit):
    def setUp(self):
        # Reuse the same boundary and corruption cases with the new real auditor.
        # No measurement function or predicate is mocked.
        selected = mock.patch.object(shared, 'audit', r10o)
        selected.start()
        self.addCleanup(selected.stop)


if __name__ == '__main__':
    unittest.main()
