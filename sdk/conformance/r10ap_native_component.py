"""Verify R10AP native composition through actual C/Python/Godot interfaces.

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
import r10am_support_anchored_closure as closure
import r10am_native_component as previous
import r10ag_native_interface as mutations
import r10aa_native_component as builds
import r10ap_progressive_headroom_kernel_component as kernel
import r10ao_progressive_headroom_study as model
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10ap_progressive_headroom_native_component_v1.json'
BINDING=ROOT/'sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json'
EXTENSION=ROOT/'sdk/adapters/godot/development_candidate_runtimes/r10ap-progressive-headroom-core-v1.gdextension'
SCRIPT=ROOT/'tests/test_r10ap_native_api.gd'
KERNEL_HEAD='6602d30265b4479a7702831b80063a31a0e97e3c'
CONTRACT=ROOT/'sdk/recovery/r10ap_progressive_headroom_native_contract_v1.json'
IDS=previous.IDS
CLAIMS=dict(native_controller_composition_integrated=True,physical_worker_integrated=False,
    positive_hold_walking_consumer_coverage_complete=False,complete_safety_gate_qualified=False,
    new_physical_population_declared=False,original_result_regraded=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def historical_kernel():
    observed=kernel.audit()
    assert observed['release_core_tests_passed']==503 and observed['compiled_model_comparisons']==600
    declaration=closure.read(CONTRACT)
    assert declaration['source_parent_commit']==KERNEL_HEAD
    for item in declaration['dependencies']:builds.verify(item)
    return dict(commit=KERNEL_HEAD,component=closure.bind(kernel.RECORD),original_bindings_authenticated=True)


def fixtures(binding,marker):
    return previous.fixtures(binding,marker)


def inputs():
    binding=closure.read(BINDING);builds.verify_frozen_build(binding)
    assert binding['core_test_count']==510
    for item in [*binding['build_evidence_files'],binding['runtime'],binding['compiled_fixtures']]:builds.verify(item)
    assert closure.bind(ROOT/binding['local_build_path'])['raw_sha256']==binding['runtime']['raw_sha256']
    current=fixtures(binding,'R10AP_PARTIAL_FIXTURE ');assert [r['id'] for r in current]==IDS
    assert '14 passed; 0 failed' in builds.verify(binding['compiled_fixtures']).read_text()
    old_binding=closure.read(previous.BINDING)
    old=fixtures(old_binding,'R10AM_PARTIAL_FIXTURE ');assert [r['id'] for r in old]==IDS
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
                    method=symbol.removeprefix('ss_').removesuffix('_json').replace('r10aa','r10ap'),request=request,expected=None)
        wrong_owner=copy.deepcopy(current[1]['request'])
        wrong_owner['collection']['observation']['controller_ownership']['recovery_controller_id']='sporespore_exact_s169_partial_support_anchored_controller_v27'
        wrong_owner['step']['observation']['controller_ownership']=copy.deepcopy(wrong_owner['collection']['observation']['controller_ownership'])
        yield dict(id=transport+'_v27_owner_refused',transport=transport,runtime='new',method=current[1]['method'],request=wrong_owner,expected=None)
        wrong_api=copy.deepcopy(current[1]['request'])
        wrong_api['schema_version']='sporespore_r10am_partial_support_anchored_step_control_request_v1'
        yield dict(id=transport+'_old_api_v28_owner_refused',transport=transport,runtime='new',method=old[1]['method'],request=wrong_api,expected=None)
    for runtime in ('new','old'):
        for row in old:
            yield dict(id='compatibility_'+runtime+'_'+row['id'],transport='abi',runtime=runtime,method=row['method'],request=row['request'],expected=row['expected'])
    for row,code in zip(current[:2],('R10AP_ENTRY_RUNTIME_UNAVAILABLE','R10AP_STEP_RUNTIME_UNAVAILABLE')):
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
        _,marker,payload=line.partition('R10AP_KERNEL_FIXTURE ')
        if marker:parsed.append(json.loads(payload))
    assert len(parsed)==len(value['observations'])==600
    largest=0.;modes={};increased=0
    for result,row in zip(parsed,value['observations'],strict=True):
        o=row['observation'];assert result['semantic_step']==o['semantic_step']
        assert result['source_sha256']==row['source_observation_sha256']
        expected=model.search(model.M.G.Model(o,value['descriptor']))
        assert expected==row['expected']
        g=result['geometry']
        for key,field in [('candidates','candidate_count'),('geometric','feasible_candidate_count'),
                ('nonworsening','nonworsening_headroom_candidate_count'),('progress','headroom_progress_candidate_count')]:
            assert expected[key]==g[field]
        modes[result['mode']]=modes.get(result['mode'],0)+1
        if expected['selected'] is None:
            assert result['mode']=='explicit_v23_fallback' and g['hold_reason']==expected['refusal']
            assert g['selected_deficits_rad'] is None
            targets=row['v23_fallback_targets']
        else:
            selected=expected['selected'];assert result['mode']==selected['mode']
            assert g['selected_scale']==selected['scale'] and g['virtual_level_blend']==selected['blend']
            assert abs(g['selected_cost']-selected['cost'])<1e-12
            assert max(abs(a-b) for a,b in zip(g['virtual_translation_world_m'],selected['translation'],strict=True))<1e-12
            for key,values in [('initial_deficits_rad',expected['deficits_before_rad']),
                    ('selected_deficits_rad',selected['verification']['deficits_after_rad'])]:
                assert max(abs(a-b) for a,b in zip(g[key],values,strict=True))<1e-12
            targets=selected['targets'];increased+=g['geometry_cost_increased']
        largest=max(largest,max(abs(a-b) for a,b in zip(result['targets'],targets,strict=True)))
    assert modes==dict(recover_joint_headroom=593,raise_with_headroom=4,explicit_v23_fallback=3)
    assert increased==492 and largest<1e-10
    return dict(compiled_geometry_comparisons=600,source_observation_hashes_preserved=600,
        bounded_command_forwarding_inputs_per_phase=600,modes=modes,geometry_cost_increases=increased,
        maximum_target_error_rad=largest)


def godot_result(out):
    value=closure.read(out/'godot-result.json')
    assert value['ok'] and value['checks'] and all(value['checks'].values())
    for identity in IDS:
        for suffix in ('method','native_success','exact_value','crossed_schema_refused'):
            assert value['checks'][identity+'_'+suffix] is True
    assert value['new_fixture_calls']==value['negative_calls']==7
    assert value['world_build_count']==value['solver_step_count']==0
    assert not value['physical_acceptance_authority'] and not value['release_authority']
    receipt=closure.read(out/'godot.execution.json')
    assert receipt['returncode']==0 and receipt['timed_out'] is False
    return value


def run_godot(out,binding,engine):
    command=[engine['path'],'--headless','--path',str(ROOT),'--script','res://tests/test_r10ap_native_api.gd','--',binding['compiled_fixtures']['path'],str(out/'godot-result.json')]
    environment={k:v for k,v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_','SPORE_R10AG_'))}
    with (out/'godot.stdout.txt').open('xb') as stdout,(out/'godot.stderr.txt').open('xb') as stderr:
        with subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr,env=environment,creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try:code=process.wait(timeout=180);timed_out=False
            except subprocess.TimeoutExpired:process.kill();process.wait();code=process.returncode;timed_out=True
            closure.write_new(out/'godot.execution.json',dict(command=command,process_id=process.pid,returncode=code,timed_out=timed_out,timeout_seconds=180,**CLAIMS))
    assert code==0 and not timed_out and (out/'godot.stderr.txt').read_bytes()==b''
    return godot_result(out)


def dependencies():
    return [Path(__file__),CONTRACT,BINDING,EXTENSION,SCRIPT,kernel.RECORD,Path(model.__file__),Path(builds.__file__),
        Path(previous.__file__),Path(previous.previous.__file__),Path(mutations.__file__),previous.BINDING,kernel.INPUTS,
        Path(closure.__file__),Path(source.__file__),Path(model.M.G.__file__),Path(kernel.__file__),
        ROOT/'sdk/python/sporespore_locomotion.py',ROOT/'sdk/include/sporespore_locomotion.h',
        ROOT/'sdk/conformance/development_recovery_refusal.py',ROOT/'sdk/development/r10ag_host_runtime_contract_v1.json']


def run():
    assert not RECORD.exists();out=EVIDENCE/('r10ap-native-component-'+uuid.uuid4().hex);out.mkdir()
    print('R10AP_NATIVE_ROOT '+out.as_posix(),flush=True)
    before=source._source_snapshot();bindings=[closure.bind(p) for p in dependencies()]
    closure.write_new(out/'source-before.json',before);closure.write_new(out/'bindings-before.json',bindings)
    execution=dict(ok=False,**CLAIMS)
    try:
        binding,current,old_binding,old,engine=inputs();history=historical_kernel()
        for item in binding['source_files']:builds.verify(item)
        closure.write_new(out/'declaration.json',dict(contract=closure.bind(CONTRACT),runtime=binding['runtime'],engine=engine,historical_kernel=history,
            covered='Original selector, V28 ownership, source, phase, energy, 600-command raise timeout, 60-sample synthetic standing, actual C ABI/Python/Godot, old V27 compatibility and two-way identity refusal.',
            not_covered='Physical stepping, worker schedule, complete report consumption, launch safety or acceptance.',**CLAIMS))
        observed=run_native(out,binding,current,old_binding,old);godot=run_godot(out,binding,engine)
        measured=geometry(binding);closure.write_new(out/'geometry.json',measured)
        observed.update(core_tests_passed=510,composition_tests_passed=7,kernel_tests_passed=7,
            godot_fixture_calls=godot['new_fixture_calls'],godot_crossed_schema_refusals=godot['negative_calls'],
            historical_kernel_commit=KERNEL_HEAD,**measured,**CLAIMS)
        closure.write_new(out/'result.json',observed);execution['ok']=True
    except BaseException:execution['error']=traceback.format_exc();raise
    finally:
        after=source._source_snapshot();ending=[closure.bind(p) for p in dependencies()]
        closure.write_new(out/'source-after.json',after);closure.write_new(out/'bindings-after.json',ending)
        execution['source_unchanged']=before==after and bindings==ending;closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10ap_progressive_headroom_native_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='core_godot_c_abi_python',authority_mode='zero_world_native_composition_component',question_class='development'),
        evidence_root=out.as_posix(),dependencies=bindings,retained_evidence=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        observed=observed,historical_kernel=history,claim_boundary=CLAIMS,
        next_action='Declare a fresh R10AP candidate/worker and full production report consumer selecting this exact V28 runtime. Complete the applicable safety gate before a fresh bounded diagnostic. Paired commissioning, official held-out acceptance and M07 adoption remain before 15/20.')
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
    measured=geometry(binding);assert measured==closure.read(out/'geometry.json')
    assert all(observed[k]==v for k,v in (counts|CLAIMS|measured).items())
    godot_result(out)
    return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2))
