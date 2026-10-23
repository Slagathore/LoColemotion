"""Complete zero-world safety gate, one contained finite search, independent replay."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import sys
import uuid

from gpu_quadruped_model import ROOT,FLAGS,sha
from portable_search_control import CONTRACT,contract
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_gpu_quadruped_probe import bindings as previous_bindings
from audit_gpu_portable_search import audit

HERE=Path(__file__).resolve().parent


def bindings(core):
    value=previous_bindings(core);paths=[CONTRACT,HERE/'gpu_portable_search_v1.json',HERE/'gpu_portable_search_invalid_closure_v1.json']
    for directory in ['sdk/adapter_kit','sdk/adaptation_provider']:
        paths.extend((ROOT/directory).glob('*.py'));paths.extend((ROOT/directory).glob('*.json'))
    value['source'].update({p.relative_to(ROOT).as_posix():sha(p) for p in paths})
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--core',type=Path,required=True);p.add_argument('--run',action='store_true');a=p.parse_args()
    core=a.core.resolve(strict=True);source=source_identity(a.run);c=contract()
    if sha(core)!=c['core_sha256']:raise ValueError('Core runtime binding')
    folder=ROOT.parent/'SporeSpore_Evidence'/('sdk2-gpu-portable-search-v2-'+uuid.uuid4().hex);folder.mkdir();print(str(folder),flush=True)
    receipt=dict(ledger_scope=c['ledger_scope'],source_commit=source,contract=c,synthetic=False,ok=False,physical_started=False,planned_worlds=dict(gpu=4,cpu=4),**{k:False for k in FLAGS})
    create=jobs.api('CreateMutexW',[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api('ReleaseMutex',[W.HANDLE])
    handle=jobs.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'));acquired=False
    try:
        if jobs.wait(handle,0) not in (0,128):raise RuntimeError('Another physical operation owns the mutex')
        acquired=True;receipt['binding']=bindings(core);write_new(folder/'declaration.json',receipt)
        env=dict(EXPLORER_TEST_OUTPUT=str(folder),QUADRUPED_TEST_CORE=str(core),SPORESPORE_LOCOMOTION_LIBRARY=str(core),PYTHONPATH=str(ROOT/'sdk')+';'+str(ROOT/'sdk/python'))
        for name,test in [('measurement-gate','test_actuation_measurement.py'),('quadruped-gate','test_gpu_quadruped_probe.py'),('portable-gate','test_portable_search.py')]:
            invoke([sys.executable,'-B','-m','unittest','discover','-s',str(HERE),'-p',test,'-v'],folder/name,120,env)
        invoke([sys.executable,'-B','-m','unittest','adaptation_provider.test_conformance','-v'],folder/'provider-gate',90,env)
        invoke([sys.executable,'-B','-m','unittest','test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant'],folder/'containment-gate',60,dict(env,PYTHONPATH=str(ROOT/'sdk/explorer')))
        invoke([sys.executable,'-B',str(HERE/'gpu_portable_search.py'),'--check-only','--core',str(core)],folder/'runtime-gate',60)
        receipt['preflight']=json.loads((folder/'runtime-gate/stdout.log').read_text())
        if receipt['preflight']['ok'] is not True or receipt['preflight']['world_build_count']!=0:raise ValueError('Preflight refused')
        if bindings(core)!=receipt['binding'] or source_identity(a.run)!=source:raise ValueError('Qualification source/runtime drift')
        receipt['zero_world_gate_passed']=True
        if a.run:
            write_new(folder/'consumed.json',dict(attempt_id=folder.name,source_commit=source,planned_worlds=receipt['planned_worlds']))
            receipt['physical_started']=True;physical=folder/'physical'
            invoke([sys.executable,'-B',str(HERE/'gpu_portable_search.py'),'--core',str(core),'--output',str(physical),'--permit',str(physical/'contained.permit')],physical,c['maximum_worker_wall_seconds'])
            receipt['audit']=audit(physical,core);write_new(folder/'independent-audit.json',receipt['audit'])
        if bindings(core)!=receipt['binding'] or source_identity(a.run)!=source:raise ValueError('Execution source/runtime drift')
        receipt['ok']=True
    except BaseException as exc:
        receipt['error']=f'{type(exc).__name__}: {exc}'
        if (folder/'physical/worker-result.json').is_file():receipt['partial_worker_result']=json.loads((folder/'physical/worker-result.json').read_text())
    finally:
        if acquired:release(handle)
        jobs.close(handle);write_new(folder/'receipt.json',receipt)
    print(json.dumps(dict(ok=receipt['ok'],output=str(folder),physical_started=receipt['physical_started'],error=receipt.get('error'))),flush=True)
    return 0 if receipt['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
