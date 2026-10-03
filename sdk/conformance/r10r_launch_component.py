"""Verify R10R launcher-interface evidence before its complete smoke gate."""
import argparse
import json
import re
from pathlib import Path

from r10r_interface_component import ROOT, EVIDENCE, bind, read, verify

RECORD = ROOT/'sdk/recovery/r10r_launch_component_v1.json'
SOURCE = ROOT/'sdk/recovery/r10r_v55_walking_entry_contract_v5.json'
CONTRACT = ROOT/'sdk/development/r10r_safety_stage_contract_v1.json'
REVIEWS = [EVIDENCE/name for name in [
    'r10r-launch-interfaces-b400b462177d41a89c208b08569904b6',
    'development-r10r-launcher-a1f64220681948549e654431e3bc291f',
    'development-r10r-launch-guard-7b73e9f3f92b42cd88a0dec67cd3a539']]
CLAIMS = dict(world_build_count=0,solver_step_count=0,complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False,physical_acceptance_authority=False,release_authority=False,
    held_out_population_declared=False,sdk1_score='14/20')


def audit(record):
    assert record['schema_version'] == 'sporespore_r10r_launch_component_v1'
    assert record['claim_boundary'] == CLAIMS
    for item in record['bindings']+record['retained_evidence']+[record['auditor']]:verify(item)
    source = read(SOURCE)
    assert len(source['bound_source_files']) == 493
    for item in source['bound_source_files']:
        assert bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'],item['path']
    contract = read(CONTRACT)
    assert len(contract['stages']) == 40 and sum(s['tests'] for s in contract['stages']) == contract['total_tests'] == 190
    run = read(REVIEWS[0]/'execution.json')
    log = (REVIEWS[0]/'stderr.log').read_text(encoding='utf-8')
    assert run['exit_code'] == 0 and run['world_build_count'] == run['solver_step_count'] == 0
    assert re.findall(r'^Ran (\d+) tests in ',log,flags=re.M) == ['11'] and log.rstrip().endswith('OK')
    for root in REVIEWS[1:]:
        assert (root/'source_before.json').read_bytes() == (root/'source_after.json').read_bytes()
    selected = read(REVIEWS[1]/'selected-stages.json')
    assert selected['test_count'] == 190 and selected['world_build_count'] == selected['solver_step_count'] == 0
    for actual, expected in zip(selected['stages'],contract['stages'],strict=True):
        assert {k:actual[k] for k in ['id','pattern','tests']} == expected
    declaration = read(REVIEWS[1]/'paired-declaration.json')
    assert declaration['development_execution_mode'] == 'single_kick_controller_diagnostic_v1'
    assert declaration['r10r_development']['stage'] == 'initial_single_diagnostic'
    assert declaration['seed'] == 40946 and declaration['r10r_development']['seed']['prefix_phase'] == 246
    assert [c['role'] for c in declaration['children']] == ['kick_passive_recovery_resume']
    assert declaration['maximum_steps_per_child'] == 3512
    # Reservations produced by unit tests are nested inside their explicit test
    # root. They do not occupy the actual production consumption namespace.
    reservations = list(REVIEWS[2].rglob('r10r_first_single_consumption_v1.json'))
    assert len(reservations) == 2 and all(p.parent.parent == REVIEWS[2] for p in reservations)
    return dict(ok=True,launcher_tests=5,launch_guard_tests=6,selected_stages=40,
        selected_tests=190,source_key_files=493,**CLAIMS)


def create():
    paths=[SOURCE,CONTRACT,ROOT/'sdk/recovery/r10r_interface_component_v1.json',
        ROOT/'sdk/recovery/r10r_startup_sweep_component_v1.json',
        ROOT/'sdk/conformance/r10r_interface_component.py']
    record=dict(schema_version='sporespore_r10r_launch_component_v1',
        status='production_launcher_interfaces_passed_complete_smoke_gate_next',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='prospective_development_launcher_interfaces',question_class='development'),
        auditor=bind(__file__),bindings=[bind(p) for p in paths],
        retained_evidence=[bind(p) for root in REVIEWS for p in sorted(root.rglob('*')) if p.is_file()],
        claim_boundary=CLAIMS)
    observed=audit(record);record['observed']=observed
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return observed


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print('R10R_LAUNCH_COMPONENT '+json.dumps(create() if args.create else audit(read(RECORD))))
