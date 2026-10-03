"""Compile, execute, retain and independently check the AI geometry kernel."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import traceback
import uuid

import r10ag_replay_invalid_closure as closure
import development_passive_entry_profile as source
import r10ai_geometry_reference as oracle

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10ai_concurrent_load_rise_kernel_component_v1.json'
INPUTS=ROOT/'sdk/core/contracts/r10ai_retained_canonical_geometry_input_binding_v2.json'
REJECTED=EVIDENCE/'r10ai-kernel-component-bdc752343b08468ab42cacfa603f6ce7'
REJECTED_PARSER=EVIDENCE/'r10ai-kernel-component-4e42300aa6a644e091267a7b5be5336f'
CLAIMS=dict(native_route_integrated=False,new_physical_population_declared=False,
    original_attempt_reclassified=False,complete_safety_gate_qualified=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def execute(out,label,command,timeout):
    with (out/(label+'.stdout.txt')).open('xb') as stdout,(out/(label+'.stderr.txt')).open('xb') as stderr:
        with subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try:code=process.wait(timeout=timeout);timed_out=False
            except subprocess.TimeoutExpired:
                process.kill();process.wait();code=process.returncode;timed_out=True
            closure.write_new(out/(label+'.execution.json'),dict(command=command,process_id=process.pid,
                returncode=code,timed_out=timed_out,timeout_seconds=timeout,**CLAIMS))
    assert code==0 and not timed_out,(label,code)


def inputs():
    manifest=closure.read(INPUTS);assert closure.bind(manifest['fixture']['path'])==manifest['fixture']
    assert manifest['source_report']['raw_sha256']==closure.REPORT_SHA
    assert closure.bind(manifest['source_report']['path'])==manifest['source_report']
    value=closure.read(manifest['fixture']['path'])
    assert value['source_report']==manifest['source_report']
    # Reconstruct every retained observation/plan from the immutable report.
    original=[dict(semantic_step=p['native_receipt']['collection']['observation']['semantic_step'],
        observation=json.loads(p['call']['request']['utf8_text'])['step']['observation'],source_next_phase=p['native_receipt']['step']['next_phase'],
        original_load_plan=p['native_receipt']['next_load_plan']) for k,p in closure.partial_records() if k=='packet']
    assert original==value['observations'] and len(original)==601
    return value


def measurements(out):
    value=inputs();rows=value['observations'];parsed=[]
    for line in (out/'tests.stdout.txt').read_text().splitlines():
        # libtest writes its test-name prefix without a newline before the
        # first println. Still require a complete JSON record after the marker.
        prefix,marker,payload=line.partition('R10AI_GEOMETRY_FIXTURE ')
        if marker:parsed.append(json.loads(payload))
    assert len(parsed)==601 and len({p['semantic_step'] for p in parsed})==601
    indexed={r['semantic_step']:r for r in rows};checks=[]
    for p in parsed:
        original=indexed[p['semantic_step']]
        assert p['counterfactual_terminal_input']==(original['source_next_phase']=='failed')
        checks.append(oracle.verify(original['observation'],value['descriptor'],p['plan']))
    assert sum(p['counterfactual_terminal_input'] for p in parsed)==1
    return dict(compiled_tests_passed=6,retained_inputs=601,independent_geometry_reconstructions=601,
        qualified_original_plan_parity_count=110,counterfactual_terminal_inputs=1,
        mode_counts=dict(Counter(p['plan']['mode'] for p in parsed)),
        weak_inputs_with_concurrent_pose_and_load_plan=sum(c['selected'] and c['weak_foot_count']>0 for c in checks),
        weak_inputs_with_upward_virtual_torso_plan=sum(c['selected'] and c['weak_foot_count']>0 and c.get('upward_virtual_torso_motion',False) for c in checks),
        maximum_reconstructed_endpoint_error_m=max(c['maximum_endpoint_error_m'] for c in checks),**CLAIMS)


def run():
    assert not RECORD.exists()
    out=EVIDENCE/('r10ai-kernel-component-'+uuid.uuid4().hex);out.mkdir()
    print('R10AI_KERNEL_ROOT '+str(out),flush=True)
    before=source._source_snapshot();closure.write_new(out/'source-before.json',before)
    paths=[Path(__file__),Path(oracle.__file__),Path(oracle.geometry.__file__),INPUTS,
        ROOT/'sdk/recovery/r10ai_concurrent_load_rise_kernel_contract_v1.json',
        ROOT/'sdk/core/src/recovery_runtime.rs',ROOT/'sdk/core/src/recovery_runtime/partial_concurrent_load_rise_control.rs',
        ROOT/'sdk/core/src/recovery_runtime/tests/partial_concurrent_load_rise_control_tests.rs']
    bindings=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-before.json',bindings)
    execution=dict(ok=False,**CLAIMS)
    try:
        cargo=shutil.which('cargo');assert cargo
        execute(out,'build',[cargo,'test','--manifest-path',str(ROOT/'sdk/Cargo.toml'),'--package','sporespore-locomotion-core',
            '--lib','--no-run','--locked','--offline','--message-format=json'],1200)
        artifacts=[json.loads(line) for line in (out/'build.stdout.txt').read_text().splitlines() if line.startswith('{')]
        executables=[Path(a['executable']) for a in artifacts if a.get('reason')=='compiler-artifact' and a.get('executable')
            and a.get('target',{}).get('name')=='sporespore_locomotion_core']
        assert len(executables)==1
        binary=out/'r10ai-core-tests.exe';shutil.copyfile(executables[0],binary)
        execute(out,'tests',[str(binary),'partial_concurrent_load_rise_control','--nocapture','--test-threads=1'],300)
        stdout=(out/'tests.stdout.txt').read_text();assert '6 passed; 0 failed' in stdout
        result=measurements(out);closure.write_new(out/'measurements.json',result);execution['ok']=True
    except BaseException:
        execution['error']=traceback.format_exc();raise
    finally:
        after=source._source_snapshot();closure.write_new(out/'source-after.json',after)
        ending=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-after.json',ending)
        execution['source_unchanged']=before==after and bindings==ending
        closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10ai_concurrent_load_rise_kernel_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral',authority_mode='compiled_geometry_component',question_class='development'),
        evidence_root=out.as_posix(),files=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        observed=result,claim_boundary=CLAIMS,
        retained_failed_fixture_attempt=[closure.bind(p) for p in sorted(REJECTED.iterdir()) if p.is_file()],
        retained_failed_parser_attempt=[closure.bind(p) for p in sorted(REJECTED_PARSER.iterdir()) if p.is_file()],
        fixture_correction='The intermediate collector ledger cannot deserialize as canonical observation V3. V2 fixture selects the exact original request step.observation; no ledger field was invented or original attempt reclassified.',
        limitation='Retained-input kernel tests and independent geometry reconstruction only. No new closed-loop trajectory, native controller composition, full consumer coverage, physical recovery or release qualification.')
    closure.write_new(RECORD,record);return result


def audit():
    record=closure.read(RECORD);assert record['claim_boundary']==CLAIMS
    for item in record['files']+record['retained_failed_fixture_attempt']+record['retained_failed_parser_attempt']:assert closure.bind(item['path'])==item,item['path']
    assert 'missing field `cumulative_signed_discrete_staging_exchange_j`' in (REJECTED/'tests.stderr.txt').read_text()
    assert '0 passed; 6 failed' in (REJECTED/'tests.stdout.txt').read_text()
    assert '6 passed; 0 failed' in (REJECTED_PARSER/'tests.stdout.txt').read_text()
    assert closure.read(REJECTED_PARSER/'execution.json')['ok'] is False
    out=Path(record['evidence_root']);before=closure.read(out/'bindings-before.json')
    assert before==closure.read(out/'bindings-after.json')
    for item in before:assert closure.bind(item['path'])==item,item['path']
    assert closure.read(out/'source-before.json')==closure.read(out/'source-after.json')
    assert closure.read(out/'execution.json')['source_unchanged'] is True
    for label in ('build','tests'):
        receipt=closure.read(out/(label+'.execution.json'));assert receipt['returncode']==0 and receipt['timed_out'] is False
    assert '6 passed; 0 failed' in (out/'tests.stdout.txt').read_text()
    result=measurements(out);assert result==record['observed']==closure.read(out/'measurements.json')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2))
