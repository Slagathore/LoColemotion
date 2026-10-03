"""Verify R10AJ native composition through actual C/Python/Godot interfaces.

This component has no physical worker, world permission or acceptance authority.
Run --run under the native operation lock. Auditing reads retained bytes only.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import traceback
import uuid

import development_passive_entry_profile as source
import r10ai_concurrent_load_rise_closure as closure
import r10ai_native_component as previous
import r10ag_native_interface as mutations
import r10aa_native_component as builds
import r10aj_hip_recenter_kernel_component as kernel
import r10aj_hip_recenter_model as model
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10aj_hip_recenter_native_component_v1.json'
BINDING=ROOT/'sdk/development/recovery_candidates/r10aj-hip-recenter-core-v1.runtime.json'
EXTENSION=ROOT/'sdk/adapters/godot/development_candidate_runtimes/r10aj-hip-recenter-core-v1.gdextension'
SCRIPT=ROOT/'tests/test_r10aj_native_api.gd'
KERNEL_HEAD='8e7f249e98defd0b43b0ac7af60840858afb00fc'
IDS=previous.IDS
CLAIMS=dict(native_controller_composition_integrated=True,physical_worker_integrated=False,
    positive_hold_walking_consumer_coverage_complete=False,complete_safety_gate_qualified=False,
    new_physical_population_declared=False,original_result_regraded=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def historical_kernel():
    record=closure.read(kernel.RECORD)
    for item in [record['auditor'],*record['dependencies'],*record['retained_evidence']]:
        path=Path(item['path'])
        if path.is_relative_to(ROOT):
            raw=subprocess.check_output(['git','show',KERNEL_HEAD+':'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
            variants=[raw] if b'\r\n' in raw else [raw,raw.replace(b'\n',b'\r\n')]
            assert any(len(v)==item['byte_length'] and 'sha256:'+hashlib.sha256(v).hexdigest()==item['raw_sha256'] for v in variants),item['path']
        else:builds.verify(item)
    assert record['observed']['release_core_tests_passed']==478 and record['observed']['compiled_model_comparisons']==600
    return dict(commit=KERNEL_HEAD,component=closure.bind(kernel.RECORD),original_bindings_authenticated=True)


def fixtures(binding,marker):
    return previous.fixtures(binding,marker)


def inputs():
    binding=closure.read(BINDING);builds.verify_frozen_build(binding)
    assert binding['core_test_count']==485
    for item in [*binding['source_files'],*binding['build_evidence_files'],binding['runtime'],binding['compiled_fixtures']]:builds.verify(item)
    assert closure.bind(ROOT/binding['local_build_path'])['raw_sha256']==binding['runtime']['raw_sha256']
    current=fixtures(binding,'R10AJ_PARTIAL_FIXTURE ');assert [r['id'] for r in current]==IDS
    assert '11 passed; 0 failed' in builds.verify(binding['compiled_fixtures']).read_text()
    old_binding=closure.read(previous.BINDING)
    old=fixtures(old_binding,'R10AI_PARTIAL_FIXTURE ');assert [r['id'] for r in old]==IDS
    builds.verify(old_binding['runtime'])
    engine=closure.read(ROOT/'sdk/development/r10ag_host_runtime_contract_v1.json')['images']['godot_engine'];builds.verify(engine)
    return binding,current,old_binding,old,engine


def cases(current,old):
    for transport in ('abi','python'):
        for row in current:
            yield dict(id=transport+'_'+row['id'],transport=transport,runtime='new',method=row['method'],request=row['request'],expected=row['expected'])
        for name,symbol,request,expected in mutations.cases(current):
            if expected is None:
                yield dict(id=transport+'_'+name,transport=transport,runtime='new',
                    method=symbol.removeprefix('ss_').removesuffix('_json').replace('r10aa','r10aj'),request=request,expected=None)
        wrong_owner=copy.deepcopy(current[1]['request'])
        wrong_owner['collection']['observation']['controller_ownership']['recovery_controller_id']='sporespore_exact_s169_partial_concurrent_load_rise_controller_v25'
        yield dict(id=transport+'_v25_owner_refused',transport=transport,runtime='new',method=current[1]['method'],request=wrong_owner,expected=None)
        wrong_api=copy.deepcopy(current[1]['request'])
        wrong_api['schema_version']='sporespore_r10ai_partial_concurrent_load_rise_step_control_request_v1'
        yield dict(id=transport+'_old_api_v26_owner_refused',transport=transport,runtime='new',method=old[1]['method'],request=wrong_api,expected=None)
    for runtime in ('new','old'):
        for row in old:
            yield dict(id='compatibility_'+runtime+'_'+row['id'],transport='abi',runtime=runtime,method=row['method'],request=row['request'],expected=row['expected'])
    for row,code in zip(current[:2],('R10AJ_ENTRY_RUNTIME_UNAVAILABLE','R10AJ_STEP_RUNTIME_UNAVAILABLE')):
        yield dict(id='old_missing_'+row['id'],transport='python',runtime='old',method=row['method'],request=row['request'],expected=None,failure_code=code)


def validate_rows(rows,current,old):
    expected=list(cases(current,old));assert len(rows)==len(expected)==68
    for row,case in zip(rows,expected,strict=True):
        assert row['case']==case
        if case['expected'] is None:
            assert row['result'] is None and row['failure_code'],case['id']
            if 'failure_code' in case:
                assert row['failure_code']==case['failure_code'] and row['response_raw_utf8'] is None
            else:assert json.loads(row['response_raw_utf8'])['ok'] is False
        else:
            assert row['failure_code'] is None and row['result']==case['expected'],case['id']
            assert json.loads(row['response_raw_utf8'])==dict(ok=True,value=row['result'])
    return dict(native_successes=28,native_refusals=40,new_fixture_count=7,
        python_public_fixture_successes=7,python_public_crossed_refusals=19,
        old_api_compatibility_calls=14,old_runtime_unavailable_refusals=2)


def run_native(out,binding,current,old_binding,old):
    cores=dict(new=RecordedCore(binding['runtime']['path']),old=RecordedCore(old_binding['runtime']['path']));rows=[]
    with (out/'native-calls.jsonl').open('x',encoding='utf-8',newline='\n') as stream:
        for case in cases(current,old):
            core=cores[case['runtime']];core.raw_response=None;result=failure=None
            try:
                result=(getattr(core,case['method'])(case['request']) if case['transport']=='python'
                    else core._call_json_input('ss_'+case['method']+'_json',case['request']))
            except LocomotionCoreError as error:failure=error.failure_code
            row=dict(case=case,result=result,failure_code=failure,response_raw_utf8=core.raw_response.decode() if core.raw_response is not None else None)
            stream.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');stream.flush();rows.append(row)
    return validate_rows(rows,current,old)


def geometry(binding):
    manifest=closure.read(kernel.INPUTS);builds.verify(manifest['fixture']);value=closure.read(manifest['fixture']['path'])
    parsed=[]
    for line in builds.verify(binding['compiled_fixtures']).open(encoding='utf-8'):
        _,marker,payload=line.partition('R10AJ_GEOMETRY_FIXTURE ')
        if marker:parsed.append(json.loads(payload))
    assert len(parsed)==len(value['observations'])==600;largest=0.
    for result,row in zip(parsed,value['observations'],strict=True):
        o=row['observation'];assert result['semantic_step']==o['semantic_step']
        assert result['source_sha256']==row['original_plan']['source_observation_sha256']
        qualified=all(row['original_plan']['qualified_support'])
        joints=[j['position_rad'] for j in o['state']['ordered_joint_observations']]
        rebuilt=model.plan(value['descriptor'],o['state']['base_pose_world']['orientation_xyzw'],joints,[True]*4)
        expected=row['original_plan']['ordered_target_positions_rad'] if qualified else rebuilt['targets']
        assert result['mode']==('unchanged_v25_reference' if qualified else 'weak_support_hip_recenter')
        largest=max(largest,max(abs(a-b) for a,b in zip(result['targets'],expected,strict=True)))
    assert largest<1e-10
    return dict(compiled_geometry_comparisons=600,source_observation_hashes_preserved=600,maximum_target_error_rad=largest)


def run_godot(out,binding,engine):
    command=[engine['path'],'--headless','--path',str(ROOT),'--script','res://tests/test_r10aj_native_api.gd','--',binding['compiled_fixtures']['path'],str(out/'godot-result.json')]
    environment={k:v for k,v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_','SPORE_R10AG_'))}
    with (out/'godot.stdout.txt').open('xb') as stdout,(out/'godot.stderr.txt').open('xb') as stderr:
        with subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr,env=environment,creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try:code=process.wait(timeout=180);timed_out=False
            except subprocess.TimeoutExpired:process.kill();process.wait();code=process.returncode;timed_out=True
            closure.write_new(out/'godot.execution.json',dict(command=command,process_id=process.pid,returncode=code,timed_out=timed_out,timeout_seconds=180,**CLAIMS))
    assert code==0 and not timed_out and (out/'godot.stderr.txt').read_bytes()==b''
    return previous.godot_result(out)


def dependencies():
    return [Path(__file__),BINDING,EXTENSION,SCRIPT,kernel.RECORD,Path(model.__file__),Path(builds.__file__),
        Path(previous.__file__),Path(mutations.__file__),previous.BINDING,kernel.INPUTS,
        ROOT/'sdk/python/sporespore_locomotion.py',ROOT/'sdk/include/sporespore_locomotion.h',
        ROOT/'sdk/conformance/development_recovery_refusal.py',ROOT/'sdk/development/r10ag_host_runtime_contract_v1.json']


def run():
    assert not RECORD.exists();out=EVIDENCE/('r10aj-native-component-'+uuid.uuid4().hex);out.mkdir()
    print('R10AJ_NATIVE_ROOT '+out.as_posix(),flush=True)
    before=source._source_snapshot();bindings=[closure.bind(p) for p in dependencies()]
    closure.write_new(out/'source-before.json',before);closure.write_new(out/'bindings-before.json',bindings)
    execution=dict(ok=False,**CLAIMS)
    try:
        binding,current,old_binding,old,engine=inputs();history=historical_kernel()
        closure.write_new(out/'declaration.json',dict(runtime=binding['runtime'],engine=engine,historical_kernel=history,
            covered='Original selector, V26 ownership, source, phase, energy, 600-command raise timeout, 60-sample synthetic standing, actual C ABI/Python/Godot, old V25 compatibility and two-way identity refusal.',
            not_covered='Physical stepping, worker schedule, complete report consumption, launch safety or acceptance.',**CLAIMS))
        observed=run_native(out,binding,current,old_binding,old);godot=run_godot(out,binding,engine)
        measured=geometry(binding);closure.write_new(out/'geometry.json',measured)
        observed.update(core_tests_passed=485,composition_tests_passed=7,kernel_tests_passed=4,
            godot_fixture_calls=godot['new_fixture_calls'],godot_crossed_schema_refusals=godot['negative_calls'],
            historical_kernel_commit=KERNEL_HEAD,**measured,**CLAIMS)
        closure.write_new(out/'result.json',observed);execution['ok']=True
    except BaseException:execution['error']=traceback.format_exc();raise
    finally:
        after=source._source_snapshot();ending=[closure.bind(p) for p in dependencies()]
        closure.write_new(out/'source-after.json',after);closure.write_new(out/'bindings-after.json',ending)
        execution['source_unchanged']=before==after and bindings==ending;closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10aj_hip_recenter_native_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='core_godot_c_abi_python',authority_mode='zero_world_native_composition_component',question_class='development'),
        evidence_root=out.as_posix(),dependencies=bindings,retained_evidence=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        observed=observed,historical_kernel=history,claim_boundary=CLAIMS,
        next_action='Declare a fresh R10AJ candidate/worker and full production report consumer selecting this exact V26 runtime. Complete the applicable safety gate before a fresh bounded diagnostic. Paired commissioning, official held-out acceptance and M07 adoption remain before 15/20.')
    closure.write_new(RECORD,record);return observed


def audit():
    record=closure.read(RECORD);assert record['claim_boundary']==CLAIMS
    for item in [*record['dependencies'],*record['retained_evidence']]:builds.verify(item)
    binding,current,old_binding,old,engine=inputs();assert historical_kernel()==record['historical_kernel']
    out=Path(record['evidence_root']);assert closure.read(out/'source-before.json')==closure.read(out/'source-after.json')
    assert closure.read(out/'bindings-before.json')==closure.read(out/'bindings-after.json')==record['dependencies']
    execution=closure.read(out/'execution.json');assert execution['ok'] is True and execution['source_unchanged'] is True
    rows=[json.loads(line) for line in (out/'native-calls.jsonl').open()];counts=validate_rows(rows,current,old)
    observed=closure.read(out/'result.json');assert observed==record['observed']
    assert all(observed[k]==v for k,v in (counts|CLAIMS|geometry(binding)).items())
    assert geometry(binding)==closure.read(out/'geometry.json');previous.godot_result(out)
    return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2))
