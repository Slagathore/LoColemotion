"""Build a separate pinned runtime and verify R10DD C/Python/Godot interfaces."""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import traceback
import r10dd_native_reference_component as component
import development_recovery_candidate_build as build
import development_passive_entry_profile as entry
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError

C=component.C
ID='r10dd-native-reference-core-v1'
BINDING=C.ROOT/f'sdk/development/recovery_candidates/{ID}.runtime.json'
EXTENSION=C.ROOT/f'sdk/adapters/godot/development_candidate_runtimes/{ID}.gdextension'
SCRIPT=C.ROOT/'tests/test_r10dd_native_api.gd'
RECORD=C.ROOT/'sdk/recovery/r10dd_native_interfaces_v1.json'
OLD=C.ROOT/'sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json'
IDS=['partial_entry','reference_observation_1','reference_observation_2','reference_observation_236','reference_observation_237']
CLAIMS=dict(native_controller_interfaces_qualified=True,physical_worker_integrated=False,
    complete_safety_gate_qualified=False,new_physical_population_declared=False,
    world_build_count=0,solver_step_count=0,physical_tracking_proven=False,
    physical_acceptance_authority=False,release_authority=False)


def verify(binding):
    path=Path(binding['path']);path=path if path.is_absolute() else C.ROOT/path
    actual=C.bind(path);assert actual['raw_sha256']==binding['raw_sha256'] and actual['byte_length']==binding['byte_length']
    return path


def fixtures(binding,marker):
    rows=[]
    for line in verify(binding['compiled_fixtures']).read_text(encoding='utf-8').splitlines():
        _,found,value=line.partition(marker)
        if found:rows.append(json.loads(value))
    return rows


def cases(new,old):
    indexed={r['id']:r for r in new};assert sorted(indexed)==sorted(IDS)
    for transport in ('abi','python'):
        for identity in IDS:
            row=indexed[identity]
            yield dict(id=transport+'_'+identity,transport=transport,runtime='new',method=row['method'],request=row['request'],expected=row['expected'])
        for kind in range(9):
            row=indexed['reference_observation_2'];request=copy.deepcopy(row['request'])
            if kind==0:request['schema_version']='crossed'
            elif kind==1:request['collection']['observation']['controller_ownership']['recovery_controller_id']='sporespore_exact_s169_partial_progressive_headroom_controller_v28'
            elif kind==2:request['step']['observation']['semantic_step']+=1
            elif kind==3:request['reference_memory']=None
            elif kind==4:request['reference_memory']['finished']=True
            elif kind==5:request['reference_memory']['last_command_sha256']='sha256:'+'a'*64
            elif kind==6:request['reference_memory']['profile_sha256']='sha256:'+'a'*64
            elif kind==7:request['collection']['observation_source_binding']['source_route_id']='crossed'
            else:request['step']['observation']['energy_balance']['cumulative_signed_external_work_j']+=1.
            yield dict(id=transport+'_refusal_'+str(kind),transport=transport,runtime='new',method=row['method'],request=request,expected=None)
    for runtime in ('new','old'):
        for row in old:
            yield dict(id=runtime+'_old_compatibility_'+row['id'],transport='python',runtime=runtime,method=row['method'],request=row['request'],expected=row['expected'])
    for identity in IDS[:2]:
        row=indexed[identity]
        yield dict(id='old_runtime_missing_'+identity,transport='python',runtime='old',method=row['method'],request=row['request'],expected=None,unavailable=True)


def dependencies():
    return [Path(__file__),component.CONTRACT,component.ENTRY,component.INPUTS,BINDING,EXTENSION,SCRIPT,OLD,
        C.ROOT/'sdk/python/sporespore_locomotion.py',C.ROOT/'sdk/include/sporespore_locomotion.h',
        C.ROOT/'sdk/development/r10ap_host_runtime_contract_v1.json',
        C.ROOT/'sdk/adapters/godot/gdscript/recovery_runtime.gd',C.ROOT/'sdk/trace_analysis/godot_authoritative_json_transport.gd']


def run(folder):
    folder=Path(folder).resolve();assert folder.is_relative_to(C.EVIDENCE)
    lock=C.read(folder/'operation-lock.json');assert lock['acquired'] and lock['owner_process_id']==os.getppid()
    before=[C.bind(p) for p in dependencies()];C.write_new(folder/'bindings-before.json',before)
    binding=C.read(BINDING);old_binding=C.read(OLD)
    for item in binding['source_files']:verify(item)
    for item in [*binding['build_evidence_files'],binding['runtime'],old_binding['runtime']]:verify(item)
    from r10aa_native_component import verify_frozen_build
    verify_frozen_build(binding)
    assert binding['core_test_count']==524
    new=fixtures(binding,'R10DD_NATIVE_FIXTURE ');old=fixtures(old_binding,'R10AP_PARTIAL_FIXTURE ')
    assert len(new)==5 and len(old)==7 and all(r['physical_source'] is False for r in new)
    engine=C.read(C.ROOT/'sdk/development/r10ap_host_runtime_contract_v1.json')['images']['godot_engine'];verify(engine)
    C.write_new(folder/'declaration.json',dict(contract=C.bind(component.CONTRACT),runtime=binding['runtime'],engine=engine,
        coverage='C ABI and Python:5 complete fixtures each plus9 refusals each;7 old API fixtures on each runtime and2 unavailable new API refusals on old DLL. Godot:5 complete fixtures plus5 crossed-schema refusals.',
        excluded='Native physical stepping, production worker and report finalization, launch safety, recovery or acceptance.',**CLAIMS))
    state=dict(ok=False)
    try:
        cores=dict(new=RecordedCore(binding['runtime']['path']),old=RecordedCore(old_binding['runtime']['path']))
        with (folder/'native-calls.jsonl').open('x',encoding='utf-8',newline='\n') as stream:
            for case in cases(new,old):
                core=cores[case['runtime']];core.raw_response=None;value=failure=None
                try:value=core._call_json_input('ss_'+case['method']+'_json',case['request']) if case['transport']=='abi' else getattr(core,case['method'])(case['request'])
                except LocomotionCoreError as error:failure=error.failure_code
                row=dict(case=case,value=value,failure_code=failure,response_raw_utf8=None if core.raw_response is None else core.raw_response.decode())
                stream.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');stream.flush()
                if case['expected'] is None:assert value is None and failure
                else:assert failure is None and value==case['expected'],case['id']
                if case.get('unavailable'):assert failure in ('R10DD_ENTRY_RUNTIME_UNAVAILABLE','R10DD_STEP_RUNTIME_UNAVAILABLE') and core.raw_response is None
        command=[engine['path'],'--headless','--path',str(C.ROOT),'--script','res://tests/test_r10dd_native_api.gd','--',binding['compiled_fixtures']['path'],str(folder/'godot-result.json')]
        env={k:v for k,v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_','SPORE_R10AG_'))}
        with (folder/'godot-stdout.txt').open('xb') as out,(folder/'godot-stderr.txt').open('xb') as err:
            with subprocess.Popen(command,cwd=C.ROOT,env=env,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW) as process:
                try:code=process.wait(timeout=180);timed_out=False
                except subprocess.TimeoutExpired:process.kill();process.wait();code=process.returncode;timed_out=True
        C.write_new(folder/'godot-execution.json',dict(command=command,return_code=code,timed_out=timed_out))
        assert code==0 and not timed_out and (folder/'godot-stderr.txt').read_bytes()==b''
        godot=C.read(folder/'godot-result.json');assert godot['ok'] and all(godot['checks'].values())
        assert godot['new_fixture_calls']==godot['negative_calls']==5
        observed=dict(core_tests_passed=524,composition_tests_passed=7,new_native_fixture_successes=10,
            new_native_refusals=18,historical_api_compatibility_calls=14,old_runtime_unavailable_refusals=2,
            godot_fixture_successes=5,godot_schema_refusals=5,**CLAIMS)
        C.write_new(folder/'result.json',observed);state['ok']=True
    except BaseException:state['error']=traceback.format_exc();raise
    finally:
        after=[C.bind(p) for p in dependencies()];C.write_new(folder/'bindings-after.json',after)
        state['source_unchanged']=before==after;C.write_new(folder/'execution.json',state)
    assert state['source_unchanged']
    C.write_new(RECORD,dict(schema_version='sporespore_r10dd_native_interfaces_v1',ledger_scope=C.read(component.CONTRACT)['ledger_scope'],
        execution_root=folder.as_posix(),dependencies=before,retained_evidence=[C.bind(p) for p in sorted(folder.iterdir()) if p.is_file()],observed=observed,claim_boundary=CLAIMS))
    return observed


def audit():
    record=C.read(RECORD)
    for b in [*record['dependencies'],*record['retained_evidence']]:verify(b)
    folder=Path(record['execution_root']);assert C.read(folder/'execution.json')==dict(ok=True,source_unchanged=True)
    assert C.read(folder/'bindings-before.json')==C.read(folder/'bindings-after.json')==record['dependencies']
    new=fixtures(C.read(BINDING),'R10DD_NATIVE_FIXTURE ');old=fixtures(C.read(OLD),'R10AP_PARTIAL_FIXTURE ')
    rows=[json.loads(line) for line in (folder/'native-calls.jsonl').read_text().splitlines()]
    expected=list(cases(new,old));assert len(rows)==len(expected)==44
    for row,case in zip(rows,expected,strict=True):
        assert row['case']==case
        if case['expected'] is None:assert row['failure_code'] and row['value'] is None
        else:assert row['failure_code'] is None and row['value']==case['expected']
    godot=C.read(folder/'godot-result.json');assert godot['ok'] and all(godot['checks'].values())
    assert record['observed']==C.read(folder/'result.json') and record['claim_boundary']==CLAIMS
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',action='store_true');parser.add_argument('--run',type=Path);args=parser.parse_args()
    if args.build:
        build.build(argparse.Namespace(candidate_id=ID,controller_id='sporespore_exact_s169_prone_to_standing_controller_v20',fixture_test='partial_native_reference_composition_tests',
            question='Finite V29 native reference interface component only; production worker/reader and applicable safety gate remain required before any diagnostic world.',build_profile='release',reuse_build_cache=True))
    else:print(json.dumps(run(args.run) if args.run else audit(),indent=2))
