"""Refuse promotion or loss of the consumed R10AJ evidence population."""
import copy
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10aj_hip_recenter_closure as closure


class ClosureRefusals(unittest.TestCase):
    def setUp(self):
        self.record=closure.read(closure.RECORD)

    def test_false_success_refused(self):
        self.record['claim_boundary']['recovery_success_obtained']=True
        with self.assertRaises(AssertionError): closure.audit(self.record)

    def test_rerun_permission_refused(self):
        self.record['claim_boundary']['rerun_authorized']=True
        with self.assertRaises(AssertionError): closure.audit(self.record)

    def test_omitted_evidence_refused(self):
        self.record['bindings'].pop()
        with self.assertRaises(AssertionError): closure.audit(self.record)

    def test_crossed_freeze_refused(self):
        self.record['source_commit']='0'*40
        with self.assertRaises(AssertionError): closure.audit(self.record)

    def test_changed_score_refused(self):
        self.record['claim_boundary']['sdk1_score']='15/20'
        with self.assertRaises(AssertionError): closure.audit(self.record)


if __name__ == '__main__': unittest.main()
