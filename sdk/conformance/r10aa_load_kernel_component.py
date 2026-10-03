"""Audit the finite R10AA kernel checkpoint; this is not native qualification."""
import argparse
import json
from pathlib import Path
import subprocess

import r10z_first_support_closure as closed

ROOT, EVIDENCE = closed.ROOT, closed.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10aa_load_kernel_component_v1.json'
FULL = EVIDENCE/'r10aa-core-full-17eed301c7964f15a4a017f9caca5795'
FAIL = EVIDENCE/'r10aa-load-kernel-c942984e2bdd4320a522daed531cbc36'
INTERMEDIATE = EVIDENCE/'r10aa-load-kernel-d8a67080f73b4f43adfb141a9636c83c'
STACK = EVIDENCE/'r10aa-core-full-a1f1a9c5f34b459da752f8c255fa7790'
FIXTURE = ROOT/'sdk/core/contracts/r10aa_retained_support_observations_v2.json'
BASE = '38ffd89de93f621f918893b84bf0b13d1d4b60f2'
OWN = ('sdk/core/src/recovery_runtime/partial_load_seeking_control.rs',
       'sdk/core/src/recovery_runtime/tests/partial_load_seeking_control_tests.rs',
       'sdk/core/contracts/r10aa_retained_support_observations_v2.json',
       'sdk/recovery/r10aa_load_seeking_kernel_contract_v1.json')


def observations():
    assert closed.read(FULL/'execution.json')['exit_code'] == 0
    host=closed.read(FULL/'host.json')
    assert host['rust_min_stack_bytes']==16777216 and host['test_threads']==2
    log=(FULL/'stdout.log').read_text(encoding='utf-8-sig')
    assert 'test result: ok. 441 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out;' in log
    rows=[line for line in log.splitlines() if line.startswith('test recovery_runtime::partial_load_seeking_control::tests::')]
    assert len(rows)==9 and all(line.endswith(' ... ok') for line in rows)
    summary=json.loads(next(line.removeprefix('R10AA_EXPOSED_INPUTS ') for line in log.splitlines() if line.startswith('R10AA_EXPOSED_INPUTS ')))
    assert summary==dict(active=243,held=1,inputs=244,virtual_body_lowering=2)
    assert 'R10AA_ENDPOINT_CHECKS 240' in log
    assert closed.read(FAIL/'execution.json')['exit_code'] != 0
    assert '4 passed; 3 failed;' in (FAIL/'stdout.log').read_text(encoding='utf-8-sig')
    assert closed.read(INTERMEDIATE/'execution.json')['exit_code']==0
    assert closed.read(STACK/'execution.json')['exit_code'] == -1073741571
    capture=closed.read(FULL/'source_capture.json');assert capture['base_head']==BASE
    archive=FULL/'source_snapshot'
    for name in OWN:
        assert (ROOT/name).read_bytes()==(archive/name).read_bytes()
    name='sdk/core/src/recovery_runtime.rs'
    original=subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT).decode('utf-8').replace('\r\n','\n')
    expected=original.replace('pub mod partial_pose_geometry_composition;\n',
        'pub mod partial_pose_geometry_composition;\npub mod partial_load_seeking_control;\n')
    assert (archive/name).read_text(encoding='utf-8')==expected
    fixture=closed.read(FIXTURE)
    assert fixture['report']==closed.binding(closed.CHILD/'worker_report.json')
    observed=[]
    for kind,packet in closed.partial_records(closed.CHILD/'worker_report.json'):
        if kind!='packet': continue
        raw=packet['call']['request']['utf8_text'].encode('utf-8')
        assert closed.diagnosis.digest(raw)==packet['call']['request']['raw_sha256']
        observation=json.loads(raw)['step']['observation']
        assert observation==packet['bound_observations']['observation_v3']
        observed.append(observation)
    assert fixture['observations']==observed and len(observed)==240
    return dict(kernel_implemented=True,core_tests=441,new_kernel_tests=9,existing_core_tests=432,
        exposed_input_count=244,active_references=243,held_references=1,
        reconstructed_endpoint_samples=240,original_v3_requests_verified=240,
        native_composition_integrated=False,native_api_integrated=False,worker_integrated=False,
        successor_physics_observed=False,complete_smoke_safety_gate_passed=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def run(capture=False):
    observed=observations()
    if capture:
        assert not RECORD.exists()
        files=[p for folder in (FULL,FAIL,INTERMEDIATE,STACK) for p in sorted(folder.rglob('*')) if p.is_file()]
        value=dict(schema_version='sporespore_r10aa_load_kernel_component_v1',
            ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral',authority_mode='zero_world_kernel_component',question_class='development'),
            dependencies=[closed.binding(p) for p in [Path(__file__),*(ROOT/name for name in OWN)]],
            retained_evidence=[closed.binding(p) for p in files],observed=observed,
            failed_fixture_preserved=True,default_stack_failure_preserved=True,
            validation_host='Full core suite used a 16 MiB Rust test-thread stack and two test threads. No controller or physical deadline changed.',
            next_action='Integrate a distinct validated partial composition, C ABI and Godot forwarders; verify actual native source and emitted motor commands before worker and smoke qualification.',
            r10z_retry_permitted=False,physical_acceptance_authority=False,release_authority=False)
        with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
            stream.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
    else:
        value=closed.read(RECORD)
        for row in value['dependencies']+value['retained_evidence']:
            assert row==closed.binding(Path(row['path']))
        assert value['observed']==observed
    return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    args=parser.parse_args()
    print('R10AA_LOAD_KERNEL_COMPONENT '+json.dumps(run(args.capture)),flush=True)
