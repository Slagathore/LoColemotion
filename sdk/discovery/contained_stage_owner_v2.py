"""Versioned stage cleanup using retained handles and exact job membership."""
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import time
from showcase_owner import OwnedChild as LegacyOwnedChild,jobs

SCOPE=dict(subsystem="runtime",engine_scope="core",
    authority_mode="contained_stage_shutdown_diagnostic",question_class="development")
WAIT_TIMEOUT=258
CLEANUP_SECONDS=10.


def state(handle):
    value=jobs.wait(handle,0)
    if value not in (0,WAIT_TIMEOUT):
        raise RuntimeError("Contained process wait failed: "+str(value))
    return value


def capture(job,records):
    """Pin a process object, then verify membership in this exact job."""
    handles=[]
    try:
        for pid in job.pids():
            if type(pid) is not int or pid<=0:raise ValueError("Invalid contained PID")
            row=dict(pid=pid,member=None);records.append(row)
            handle=jobs.open_process(0x1000|0x100000,False,pid)
            if not handle:
                error=C.get_last_error();row["open_error"]=error
                # A vanished list entry is not a witness for any live process.
                if error==87 and pid not in job.pids():
                    row["status"]="left_job_before_handle_capture";continue
                raise RuntimeError("Could not pin contained process: "+str(error))
            keep=False
            try:
                member=W.BOOL()
                jobs.checked(jobs.in_job(handle,job.handle,C.byref(member)))
                row["member"]=bool(member.value)
                created,exited,kernel,user=(W.FILETIME() for _ in range(4))
                jobs.checked(jobs.times(handle,C.byref(created),C.byref(exited),C.byref(kernel),C.byref(user)))
                row["creation_filetime"]=(created.dwHighDateTime<<32)|created.dwLowDateTime
                row["initial_wait"]=state(handle)
                if member.value:
                    row["status"]="member_handle_retained";handles.append((handle,row));keep=True
                else:row["status"]="outside_owned_job"
            finally:
                if not keep:jobs.close(handle)
        return handles
    except BaseException:
        for handle,_ in handles:jobs.close(handle)
        raise


def await_members(handles):
    deadline=time.monotonic()+CLEANUP_SECONDS
    while True:
        running=[]
        for handle,row in handles:
            row["final_wait"]=state(handle)
            if row["final_wait"]==WAIT_TIMEOUT:running.append(row["pid"])
        if not running:return
        if time.monotonic()>=deadline:
            raise RuntimeError("Contained member handles did not signal: "+",".join(map(str,running)))
        time.sleep(.01)


class OwnedChild(LegacyOwnedChild):
    def __init__(self,command,cwd,env,folder):
        self.cleanup_folder=Path(folder);self.cleanup_complete=False;self.cleanup_error=None
        super().__init__(command,cwd,env,folder)

    def close(self):
        if self.cleanup_complete:
            if self.cleanup_error:raise RuntimeError(self.cleanup_error)
            return
        report=dict(schema_version="locolemotion_contained_stage_cleanup_v2",ledger_scope=SCOPE,
            ok=False,members=[],cleanup_seconds=CLEANUP_SECONDS,stable_handles=True,
            exact_job_membership=True,pid_reopened_after_job_close=False,
            physical_acceptance_authority=False,release_authority=False)
        handles=[];errors=[];started=time.monotonic()
        try:
            if self.job.handle:handles=capture(self.job,report["members"])
            self.job.close()
            if self.process is not None:self.process.wait(timeout=CLEANUP_SECONDS)
            await_members(handles)
            report["ok"]=True
        except BaseException as exc:errors.append(type(exc).__name__+": "+str(exc))
        finally:
            try:
                if self.job.handle:self.job.close()
                if self.process is not None and self.process.poll() is None:
                    self.process.wait(timeout=CLEANUP_SECONDS)
            except BaseException as exc:errors.append("Final cleanup: "+type(exc).__name__+": "+str(exc))
            for handle,_ in handles:jobs.close(handle)
            for stream in (getattr(self,"stdout",None),getattr(self,"stderr",None)):
                if stream is not None:stream.close()
            report["ok"]=report["ok"] and not errors
            report["errors"]=errors;report["wall_s"]=time.monotonic()-started
            self.cleanup_complete=True;self.cleanup_error="; ".join(errors) if errors else None
            try:
                with (self.cleanup_folder/"cleanup.json").open("x",encoding="utf-8",newline="\n") as stream:
                    json.dump(report,stream,indent=2,allow_nan=False);stream.write("\n")
            except BaseException as exc:
                self.cleanup_error=(self.cleanup_error or "")+"; cleanup receipt: "+type(exc).__name__+": "+str(exc)
        if self.cleanup_error:raise RuntimeError(self.cleanup_error)
