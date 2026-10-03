"""Small Windows job owner: descendants cannot outlive the owning host handle."""
import ctypes as C
from ctypes import wintypes as W
import os

K=C.WinDLL('kernel32',use_last_error=True)

def api(name,args,result=W.BOOL):
    f=getattr(K,name);f.argtypes=args;f.restype=result;return f

close=api('CloseHandle',[W.HANDLE])
open_process=api('OpenProcess',[W.DWORD,W.BOOL,W.DWORD],W.HANDLE)
wait=api('WaitForSingleObject',[W.HANDLE,W.DWORD],W.DWORD)
times=api('GetProcessTimes',[W.HANDLE,C.POINTER(W.FILETIME),C.POINTER(W.FILETIME),C.POINTER(W.FILETIME),C.POINTER(W.FILETIME)])
in_job=api('IsProcessInJob',[W.HANDLE,W.HANDLE,C.POINTER(W.BOOL)])
create=api('CreateJobObjectW',[C.c_void_p,W.LPCWSTR],W.HANDLE)
set_info=api('SetInformationJobObject',[W.HANDLE,C.c_int,C.c_void_p,W.DWORD])
query=api('QueryInformationJobObject',[W.HANDLE,C.c_int,C.c_void_p,W.DWORD,C.c_void_p])
assign=api('AssignProcessToJobObject',[W.HANDLE,W.HANDLE])
terminate=api('TerminateJobObject',[W.HANDLE,W.UINT])

class Basic(C.Structure):
    _fields_=[('ProcessTime',C.c_int64),('JobTime',C.c_int64),('Flags',W.DWORD),
        ('MinWorkingSet',C.c_size_t),('MaxWorkingSet',C.c_size_t),('ActiveLimit',W.DWORD),
        ('Affinity',C.c_size_t),('Priority',W.DWORD),('Scheduling',W.DWORD)]

class IO(C.Structure):
    _fields_=[(n,C.c_uint64) for n in ['ReadOps','WriteOps','OtherOps','ReadBytes','WriteBytes','OtherBytes']]

class Extended(C.Structure):
    _fields_=[('Basic',Basic),('IO',IO),('ProcessMemory',C.c_size_t),('JobMemory',C.c_size_t),
        ('PeakProcessMemory',C.c_size_t),('PeakJobMemory',C.c_size_t)]


def checked(value):
    if not value:raise C.WinError(C.get_last_error())
    return value


def identity(pid):
    handle=open_process(0x1000|0x100000,False,pid)
    if not handle:return None
    try:
        created,exited,kernel,user=(W.FILETIME() for _ in range(4))
        checked(times(handle,C.byref(created),C.byref(exited),C.byref(kernel),C.byref(user)))
        return dict(pid=pid,creation_filetime=(created.dwHighDateTime<<32)|created.dwLowDateTime,
            running=wait(handle,0)==258)
    finally:close(handle)


def current_identity():
    value=identity(os.getpid());value.pop('running');return value


def alive(expected):
    value=identity(expected['pid'])
    return value is not None and value['running'] and value['creation_filetime']==expected['creation_filetime']


def current_in_job():
    result=W.BOOL();checked(in_job(W.HANDLE(-1),None,C.byref(result)));return bool(result.value)


class Job:
    def __init__(self):
        self.handle=checked(create(None,None))
        info=Extended();info.Basic.Flags=0x2000 # KILL_ON_JOB_CLOSE; no descendant breakaway.
        try:checked(set_info(self.handle,9,C.byref(info),C.sizeof(info)))
        except BaseException:self.close();raise
    def add(self,process):checked(assign(self.handle,W.HANDLE(int(process._handle))))
    def pids(self):
        data=C.create_string_buffer(8+512*C.sizeof(C.c_size_t))
        checked(query(self.handle,3,data,C.sizeof(data),None))
        count=W.DWORD.from_buffer(data,4).value
        assert count<=512
        return list((C.c_size_t*count).from_buffer(data,8))
    def terminate(self):checked(terminate(self.handle,125))
    def close(self):
        if self.handle:close(self.handle);self.handle=None
