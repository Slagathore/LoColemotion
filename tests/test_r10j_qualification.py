"""Retained raw log corruption controls; no qualification or world is created."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_campaign_authority as authority
import r10j_qualification as qualification


def fixture():
    logs = {'component.stdout.log': b'retained native component\n',
            'component.stderr.log': b'Ran 8 tests in 1.2s\n\nOK\n'}
    spec = [dict(id='component', tests=8)]
    actual = [dict(id='component', passed=True, exit_code=0, timed_out=False, test_count=8, expected_test_count=8,
                   stdout='component.stdout.log', stderr='component.stderr.log',
                   stdout_sha256=authority.sha(logs['component.stdout.log'])[7:],
                   stderr_sha256=authority.sha(logs['component.stderr.log'])[7:])]
    return actual, spec, logs


class Qualification(unittest.TestCase):
    def test_exact_raw_logs_and_actual_population(self):
        actual, spec, logs = fixture()
        self.assertEqual(8, qualification.validate_stage_stream(actual, spec, logs.__getitem__))

    def test_missing_extra_failed_timed_out_and_boolean_counts_refuse(self):
        for defect in ('missing', 'extra', 'failed', 'timeout', 'boolean'):
            actual, spec, logs = fixture()
            if defect == 'missing': actual = []
            elif defect == 'extra': actual += copy.deepcopy(actual)
            elif defect == 'failed': actual[0]['exit_code'] = 1
            elif defect == 'timeout': actual[0]['timed_out'] = True
            else: actual[0]['test_count'] = True
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)

    def test_changed_or_rebound_failing_raw_log_refuses(self):
        for rebound in (False, True):
            actual, spec, logs = fixture()
            logs['component.stderr.log'] = b'Ran 8 tests in 1.2s\n\nFAILED (failures=1)\n'
            if rebound: actual[0]['stderr_sha256'] = authority.sha(logs['component.stderr.log'])[7:]
            with self.subTest(rebound=rebound), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)

    def test_path_escape_duplicate_result_and_partial_count_refuse(self):
        for defect in ('path', 'duplicate', 'count'):
            actual, spec, logs = fixture()
            if defect == 'path': actual[0]['stdout'] = '../component.stdout.log'
            else:
                logs['component.stderr.log'] = logs['component.stderr.log']*2 if defect == 'duplicate' else b'Ran 7 tests in 1.2s\n\nOK\n'
                actual[0]['stderr_sha256'] = authority.sha(logs['component.stderr.log'])[7:]
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                qualification.validate_stage_stream(actual, spec, logs.__getitem__)


if __name__ == '__main__':
    unittest.main()
