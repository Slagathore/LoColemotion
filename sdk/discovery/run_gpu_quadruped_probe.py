"""Complete safety gate, contained contact-bearing batch, independent audit."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import sys
import uuid

from gpu_quadruped_model import CONTRACT,HERE,ROOT,FLAGS,load_contract,sha
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,bindings as base_bindings,invoke,jobs
from audit_gpu_quadruped_probe import audit


def bindings(core):
    value=base_bindings()
    paths=[CONTRACT]+list((ROOT/'sdk/adapters/mujoco/sporespore_mujoco_adapter').glob('*.py'))
    paths += [ROOT/'sdk/explorer/showcase_model.py']
    value['source'].update({str(p.relative_to(ROOT)):sha(p) for p in paths})
    value['runtime'][str(core)]=sha(core)
    return value


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core',type=Path,required=True)
    parser.add_argument('--run',action='store_true')
    args=parser.parse_args();core=args.core.resolve(strict=True)
    source=source_identity(args.run);contract=load_contract()
    if sha(core)!=contract['core_sha256']:raise ValueError('Declared core bytes required')
    folder=ROOT.parent/'SporeSpore_Evidence'/('sdk2-gpu-quadruped-'+uuid.uuid4().hex);folder.mkdir()
    print(str(folder),flush=True)
    receipt=dict(ledger_scope=contract['ledger_scope'],source_commit=source,contract=contract,synthetic=False,
                 ok=False,physical_started=False,planned_worlds=dict(gpu=4,cpu=4),**{k:False for k in FLAGS})
    create=jobs.api('CreateMutexW',[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api('ReleaseMutex',[W.HANDLE])
    handle=jobs.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'));acquired=False
    try:
        if jobs.wait(handle,0) not in (0,128):raise RuntimeError('Another physical operation owns the mutex')
        acquired=True;receipt['binding']=bindings(core);write_new(folder/'declaration.json',receipt)
        env=dict(EXPLORER_TEST_OUTPUT=str(folder),QUADRUPED_TEST_CORE=str(core))
        for name,test in [('measurement-gate','test_actuation_measurement.py'),('quadruped-gate','test_gpu_quadruped_probe.py')]:
            invoke([sys.executable,'-B','-m','unittest','discover','-s',str(HERE),'-p',test,'-v'],folder/name,90,env)
        invoke([sys.executable,'-B','-m','unittest','test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant'],
               folder/'containment-gate',60,dict(env,PYTHONPATH=str(ROOT/'sdk/explorer')))
        invoke([sys.executable,'-B',str(HERE/'gpu_quadruped_probe.py'),'--core',str(core),'--check-only'],folder/'runtime-gate',60)
        receipt['preflight']=json.loads((folder/'runtime-gate/stdout.log').read_text())
        if receipt['preflight']['world_build_count']!=0 or receipt['preflight']['ok'] is not True:raise ValueError('Preflight refused')
        if bindings(core)!=receipt['binding'] or source_identity(args.run)!=source:raise RuntimeError('Qualification source/runtime drift')
        receipt['zero_world_gate_passed']=True
        if args.run:
            write_new(folder/'consumed.json',dict(attempt_id=folder.name,source_commit=source,planned_worlds=receipt['planned_worlds']))
            receipt['physical_started']=True;physical=folder/'physical'
            invoke([sys.executable,'-B',str(HERE/'gpu_quadruped_probe.py'),'--core',str(core),
                    '--output',str(physical),'--permit',str(physical/'contained.permit')],physical,contract['maximum_worker_wall_seconds'])
            receipt['audit']=audit(physical);write_new(folder/'independent-audit.json',receipt['audit'])
        if bindings(core)!=receipt['binding'] or source_identity(args.run)!=source:raise RuntimeError('Execution source/runtime drift')
        receipt['ok']=True
    except BaseException as exc:
        receipt['error']=f'{type(exc).__name__}: {exc}'
        result=folder/'physical/worker-result.json'
        if result.is_file():receipt['partial_worker_result']=json.loads(result.read_text())
    finally:
        if acquired:release(handle)
        jobs.close(handle);write_new(folder/'receipt.json',receipt)
    print(json.dumps(dict(ok=receipt['ok'],output=str(folder),error=receipt.get('error'),physical_started=receipt['physical_started'])),flush=True)
    return 0 if receipt['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
