"""Execute R10AI worker/source components on synthetic inputs, without worlds.

This is not candidate admission or the complete physical-route safety gate.
Run --run under the repository native-operation lock.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import traceback
import uuid

import r10ai_native_component as native
import r10ag_gate_support as host_fixture
import development_passive_entry_profile as source

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10ai_worker_source_component_v1.json'
FAILED_RUNS = [EVIDENCE/'r10ai-worker-component-a7d46fb46d83430db2c2a4d8a237bdc3',
    EVIDENCE/'r10ai-worker-component-d0a5db35166c46a1a758acd16267aaa2',
    EVIDENCE/'r10ai-worker-component-2fe41420f0964c73ba932d9858c2efea',
    EVIDENCE/'r10ai-worker-component-d72763d95dd04168a6aee0ae3aa9ff2a']
CLAIMS = dict(synthetic_measurements_only=True, uninserted_motor_commands_only=True,
    candidate_admission_exercised=False, complete_report_consumer_exercised=False,
    complete_safety_gate_qualified=False, new_physical_population_declared=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def dependencies():
    paths = {Path(__file__), Path(native.__file__), native.RECORD, native.BINDING,
        ROOT/'sdk/conformance/r10ag_gate_support.py', ROOT/'tests/r10ag_preflight_fixture.py',
        ROOT/'sdk/conformance/r10ag_development.py', ROOT/'sdk/conformance/r10ag_host_runtime.py',
        ROOT/'sdk/conformance/development_passive_entry_profile.py'}
    pending = [ROOT/'tests/test_development_r10ai_task_source.gd', ROOT/'tests/test_development_r10ai_worker_hooks.gd']
    while pending:
        path = pending.pop()
        if path in paths: continue
        paths.add(path)
        if path.suffix != '.gd': continue
        for resource in re.findall(r'res://([^"\s]+)', path.read_text()):
            target = ROOT/resource
            if target.is_file() and target not in paths: pending.append(target)
    return sorted(paths)


def run_child(out, name, script, fixtures, engine, branch=None):
    result_path = out/(name+'.json')
    command = [engine['path'], '--headless', '--path', str(ROOT), '--script', 'res://tests/'+script,
        '--', str(fixtures), str(result_path)]
    if branch is not None: command.append(branch)
    # Reuse the existing explicitly read-only v7 image selection as a test
    # dependency. It is not AI seed/candidate admission and authorizes no world.
    environment = host_fixture.godot_environment(out, name)
    with (out/(name+'.stdout.txt')).open('xb') as stdout, (out/(name+'.stderr.txt')).open('xb') as stderr:
        with subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr,
                creationflags=subprocess.CREATE_NO_WINDOW, env=environment) as process:
            try: code=process.wait(timeout=180); timed_out=False
            except subprocess.TimeoutExpired:
                process.kill();process.wait();code=process.returncode;timed_out=True
            native.closure.write_new(out/(name+'.execution.json'),dict(command=command,process_id=process.pid,
                returncode=code,timed_out=timed_out,timeout_seconds=180,**CLAIMS))
    assert code==0 and not timed_out,(name,code,(out/(name+'.stderr.txt')).read_text())
    return validate_child(out,name,branch)


def validate_child(out,name,branch):
    execution=native.closure.read(out/(name+'.execution.json'))
    assert execution['returncode']==0 and execution['timed_out'] is False
    assert 'ERROR:' not in (out/(name+'.stderr.txt')).read_text()
    result=native.closure.read(out/(name+'.json'))
    assert result['ok'] is True and result['checks'] and all(result['checks'].values()),(name,result.get('failure'),[k for k,v in result['checks'].items() if not v])
    assert result['world_build_count']==result['solver_step_count']==0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    if branch=='partial':
        assert len(result['entry_packets'])==240 and len(result['partial_packets'])==63
        assert result['final_partial_memory']['standing_samples_observed']==60
        assert result['final_partial_memory']['phase']=='complete'
        assert result['final_state']['phase']=='fresh_selected_policy_walking_resume'
    elif branch=='prone':
        assert len(result['entry_packets'])==1 and result['partial_packets']==[]
        assert result['final_state']['confirm_prone_step_count']==12
    return dict(checks_passed=len(result['checks']),entry_packets=len(result.get('entry_packets',[])),partial_packets=len(result.get('partial_packets',[])))


def run():
    assert not RECORD.exists()
    out=EVIDENCE/('r10ai-worker-component-'+uuid.uuid4().hex);out.mkdir()
    print('R10AI_WORKER_ROOT '+out.as_posix(),flush=True)
    before=source._source_snapshot(); bindings=[native.closure.bind(p) for p in dependencies()]
    native.closure.write_new(out/'source-before.json',before)
    native.closure.write_new(out/'bindings-before.json',bindings)
    execution=dict(ok=False,**CLAIMS)
    try:
        binding,_,_,_,engine=native.inputs()
        original=native.closure.read(ROOT/'sdk/recovery/r10k_partial_fall_component_implementation_v1.json')
        fixture=native.verify(next(row for row in original['retained_evidence'] if row['path'].endswith('development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log')))
        native.closure.write_new(out/'declaration.json',dict(runtime=binding['runtime'],engine=engine,
            synthetic_pose_fixture=native.closure.bind(fixture),native_fixture=binding['compiled_fixtures'],
            scenarios=['source','partial','prone'],**CLAIMS))
        observed={}
        observed['source']=run_child(out,'source','test_development_r10ai_task_source.gd',native.verify(binding['compiled_fixtures']),engine)
        print('R10AI_SOURCE_PASS '+json.dumps(observed['source']),flush=True)
        for branch in ('partial','prone'):
            observed[branch]=run_child(out,branch,'test_development_r10ai_worker_hooks.gd',fixture,engine,branch)
            print('R10AI_WORKER_PASS '+branch+' '+json.dumps(observed[branch]),flush=True)
        native.closure.write_new(out/'result.json',dict(observed=observed,**CLAIMS))
        execution['ok']=True
    except BaseException:
        execution['error']=traceback.format_exc();raise
    finally:
        after=source._source_snapshot();ending=[native.closure.bind(p) for p in dependencies()]
        native.closure.write_new(out/'source-after.json',after)
        native.closure.write_new(out/'bindings-after.json',ending)
        execution['source_unchanged']=before==after and bindings==ending
        native.closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10ai_worker_source_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_worker_and_measurement_source_component',question_class='development'),
        evidence_root=out.as_posix(),dependencies=bindings,
        evidence=[native.closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],observed=observed,claim_boundary=CLAIMS,
        retained_failed_attempts=[native.closure.bind(p) for directory in FAILED_RUNS for p in sorted(directory.iterdir()) if p.is_file()],
        next_action='Declare the distinct candidate schedule, source key and worker/reader dispatch. Exercise complete production report consumption including positive hold and walking, then finish the full applicable safety graph before one fresh declared diagnostic.')
    native.closure.write_new(RECORD,record);return observed


def audit():
    record=native.closure.read(RECORD);assert record['claim_boundary']==CLAIMS
    for row in record['dependencies']+record['evidence']+record['retained_failed_attempts']:native.verify(row)
    out=Path(record['evidence_root'])
    assert native.closure.read(out/'source-before.json')==native.closure.read(out/'source-after.json')
    assert native.closure.read(out/'bindings-before.json')==native.closure.read(out/'bindings-after.json')==record['dependencies']
    execution=native.closure.read(out/'execution.json');assert execution['ok'] and execution['source_unchanged']
    observed={name:validate_child(out,name,None if name=='source' else name) for name in ('source','partial','prone')}
    assert record['observed']==observed==native.closure.read(out/'result.json')['observed']
    return dict(observed=observed,**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2))
