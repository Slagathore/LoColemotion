"""Zero-physics lifecycle regressions and real contained Python process checks."""
import ctypes as C
from ctypes import wintypes as W
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid
import contained_stage_owner_v2 as owner
from showcase_owner import OwnedChild as LegacyOwnedChild,jobs

ROOT=Path(__file__).resolve().parents[2]


class LifecycleControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.output.mkdir(parents=True,exist_ok=True)

    def folder(self,name):
        value=self.output/(name+"-"+uuid.uuid4().hex);value.mkdir();return value

    def fixture(self,name,listed=None):
        child=owner.OwnedChild.__new__(owner.OwnedChild)
        child.cleanup_folder=self.folder(name);child.cleanup_complete=False;child.cleanup_error=None
        child.job=jobs.Job();child.process=None;child.stdout=io.StringIO();child.stderr=io.StringIO()
        if listed is not None:child.job.pids=lambda:list(listed)
        return child

    def report(self,child):
        return json.loads((child.cleanup_folder/"cleanup.json").read_text())

    def test_01_legacy_stale_list_entry_reproduces_false_refusal(self):
        folder=self.folder("legacy-stale-list")
        child=LegacyOwnedChild.__new__(LegacyOwnedChild);child.job=jobs.Job()
        child.job.pids=lambda:[os.getpid()];child.process=None
        child.stdout=io.StringIO();child.stderr=io.StringIO()
        try:
            with patch.object(time,"monotonic",side_effect=[0.,11.]):
                with self.assertRaisesRegex(RuntimeError,"Contained descendant did not exit"):
                    child.close()
            (folder/"fixture.json").write_text(json.dumps(dict(
                synthetic_stale_pid_fixture=True,original_incident_reproduced=False,
                listed_pid=os.getpid(),actual_owned_job_member=False,legacy_false_refusal=True,
                worlds_opened=0,solver_steps=0)),encoding="utf-8")
        finally:
            child.job.close();child.stdout.close();child.stderr.close()

    def test_02_running_process_in_other_job_is_excluded(self):
        child=self.fixture("outside-owned-job",[os.getpid()])
        self.assertTrue(jobs.current_in_job())
        child.close();r=self.report(child)
        self.assertTrue(r["ok"]);self.assertEqual(len(r["members"]),1)
        self.assertFalse(r["members"][0]["member"])
        self.assertEqual(r["members"][0]["status"],"outside_owned_job")
        self.assertTrue(jobs.identity(os.getpid())["running"])

    def test_03_wait_uses_held_handle_without_reopening_pid(self):
        row=dict(pid=123)
        with patch.object(jobs,"wait",return_value=0),patch.object(jobs,"identity",side_effect=AssertionError("PID reopened")),patch.object(jobs,"alive",side_effect=AssertionError("PID reopened")):
            owner.await_members([(42,row)])
        self.assertEqual(row["final_wait"],0)

    def test_04_live_member_timeout_remains_failure(self):
        row=dict(pid=123)
        with patch.object(jobs,"wait",return_value=258),patch.object(time,"monotonic",side_effect=[0.,10.]):
            with self.assertRaisesRegex(RuntimeError,"member handles did not signal"):
                owner.await_members([(42,row)])
        self.assertEqual(row["final_wait"],258)

    def test_05_invalid_wait_result_is_not_completion(self):
        for value in (4294967295,128,1):
            with patch.object(jobs,"wait",return_value=value):
                with self.assertRaisesRegex(RuntimeError,"wait failed"):owner.state(42)

    def test_06_membership_query_failure_releases_handle(self):
        job=SimpleNamespace(handle=7,pids=lambda:[123]);rows=[]
        with patch.object(jobs,"open_process",return_value=42),patch.object(jobs,"in_job",return_value=0),patch.object(jobs,"checked",side_effect=OSError("membership query")),patch.object(jobs,"close") as close:
            with self.assertRaises(OSError):owner.capture(job,rows)
            close.assert_called_once_with(42)
        self.assertIsNone(rows[0]["member"])

    def test_07_inaccessible_process_is_not_silently_omitted(self):
        job=SimpleNamespace(handle=7,pids=lambda:[123]);rows=[]
        with patch.object(jobs,"open_process",return_value=0),patch.object(C,"get_last_error",return_value=5):
            with self.assertRaisesRegex(RuntimeError,"Could not pin contained process"):owner.capture(job,rows)
        self.assertEqual(rows[0]["open_error"],5)

    def test_08_unresolved_pid_still_in_job_refuses(self):
        job=SimpleNamespace(handle=7,pids=lambda:[123]);rows=[]
        with patch.object(jobs,"open_process",return_value=0),patch.object(C,"get_last_error",return_value=87):
            with self.assertRaisesRegex(RuntimeError,"Could not pin contained process"):owner.capture(job,rows)

    def test_09_vanished_entry_is_explicitly_recorded(self):
        from unittest.mock import Mock
        job=SimpleNamespace(handle=7,pids=Mock(side_effect=[[123],[]]));rows=[]
        with patch.object(jobs,"open_process",return_value=0),patch.object(C,"get_last_error",return_value=87):
            self.assertEqual(owner.capture(job,rows),[])
        self.assertEqual(rows[0]["status"],"left_job_before_handle_capture")

    def test_10_signaled_member_still_gets_a_stable_handle(self):
        def member(handle,job,result):
            self.assertEqual(job,7);C.cast(result,C.POINTER(W.BOOL))[0]=True;return 1
        job=SimpleNamespace(handle=7,pids=lambda:[123]);rows=[]
        with patch.object(jobs,"open_process",return_value=42),patch.object(jobs,"in_job",side_effect=member),patch.object(jobs,"times",return_value=1),patch.object(jobs,"wait",return_value=0),patch.object(jobs,"close") as close:
            handles=owner.capture(job,rows)
            self.assertEqual(handles,[(42,rows[0])]);self.assertTrue(rows[0]["member"])
            owner.await_members(handles);close.assert_not_called()
        self.assertEqual(rows[0]["final_wait"],0)

    def test_11_delayed_signal_is_observed_on_same_handle(self):
        row=dict(pid=123)
        with patch.object(jobs,"wait",side_effect=[258,0]) as wait,patch.object(time,"sleep"):
            owner.await_members([(42,row)])
            self.assertEqual([x.args for x in wait.call_args_list],[(42,0),(42,0)])
        self.assertEqual(row["final_wait"],0)

    def test_12_successful_close_is_idempotent(self):
        child=self.fixture("idempotent",[]);child.close()
        before=(child.cleanup_folder/"cleanup.json").read_bytes();child.close()
        self.assertEqual((child.cleanup_folder/"cleanup.json").read_bytes(),before)
        self.assertTrue(child.stdout.closed and child.stderr.closed)

    def test_13_real_normal_stage_completion(self):
        child=owner.OwnedChild([sys.executable,"-B","-c","pass"],ROOT,{},self.folder("normal"))
        try:self.assertEqual(child.process.wait(timeout=10),0)
        finally:child.close()
        self.assertTrue(self.report(child)["ok"])

    def test_14_real_leaf_worker_and_grandchild_are_reaped(self):
        folder=self.folder("three-processes");ready=folder/"grandchild-ready.json"
        command=("import subprocess,sys,time,os,json; from pathlib import Path; "
            "p=subprocess.Popen([sys.executable,'-B','-c','import time; time.sleep(60)'],creationflags=subprocess.CREATE_NO_WINDOW); "
            "Path("+repr(str(ready))+").write_text(json.dumps(dict(worker_pid=os.getpid(),grandchild_pid=p.pid))); time.sleep(60)")
        child=owner.OwnedChild([sys.executable,"-B","-c",command],ROOT,{},folder)
        witnesses=[];rows=[]
        try:
            deadline=time.monotonic()+10
            while not ready.exists():
                self.assertLess(time.monotonic(),deadline);time.sleep(.02)
            while True:
                try:identities=json.loads(ready.read_text());break
                except json.JSONDecodeError:
                    self.assertLess(time.monotonic(),deadline);time.sleep(.02)
            witnesses=owner.capture(child.job,rows);self.assertGreaterEqual(len(witnesses),3)
            self.assertTrue(set(identities.values()).issubset({row["pid"] for _,row in witnesses}))
            child.close()
            self.assertTrue(all(owner.state(handle)==0 for handle,_ in witnesses))
            r=self.report(child);self.assertTrue(r["ok"])
            self.assertGreaterEqual(len([x for x in r["members"] if x["member"]]),3)
            self.assertTrue(all(x.get("final_wait")==0 for x in r["members"] if x["member"]))
        finally:
            try:child.close()
            finally:
                for handle,_ in witnesses:jobs.close(handle)

    def test_15_short_lived_stage_population(self):
        reports=[]
        for _ in range(8):
            child=owner.OwnedChild([sys.executable,"-B","-c","pass"],ROOT,{},self.folder("short"))
            try:self.assertEqual(child.process.wait(timeout=10),0)
            finally:child.close()
            reports.append(self.report(child))
        self.assertEqual(len(reports),8);self.assertTrue(all(r["ok"] for r in reports))

    def test_16_uncertain_leaf_exit_remains_failed_and_retained(self):
        from unittest.mock import Mock
        child=self.fixture("uncertain-exit",[])
        child.process=SimpleNamespace(wait=Mock(side_effect=subprocess.TimeoutExpired("fixture",10)),poll=lambda:None)
        with self.assertRaises(RuntimeError):child.close()
        r=self.report(child);self.assertFalse(r["ok"]);self.assertEqual(len(r["errors"]),2)
        self.assertTrue(all(x.kwargs==dict(timeout=10.) for x in child.process.wait.call_args_list))
        self.assertTrue(child.stdout.closed and child.stderr.closed)
        before=(child.cleanup_folder/"cleanup.json").read_bytes()
        with self.assertRaises(RuntimeError):child.close()
        self.assertEqual((child.cleanup_folder/"cleanup.json").read_bytes(),before)

    def test_17_capture_error_closes_job_and_retains_failure(self):
        child=self.fixture("membership-error",[os.getpid()])
        with patch.object(jobs,"in_job",side_effect=OSError("membership query")):
            with self.assertRaisesRegex(RuntimeError,"membership query"):child.close()
        self.assertIsNone(child.job.handle);self.assertFalse(self.report(child)["ok"])
        self.assertTrue(child.stdout.closed and child.stderr.closed)


if __name__=="__main__":unittest.main(verbosity=2)
