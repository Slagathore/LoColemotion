"""Audit original compiled-kernel outputs against retained inputs and Python FK.

This never runs a compiler, launches a world, or renews a consumed population.
The failed debug stack-overflow run remains distinct from the release result.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

import r10ai_concurrent_load_rise_closure as closure
import r10aj_hip_recenter_model as model
import r10aj_hip_recenter_probe as probe

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
OUT=EVIDENCE/'r10aj-kernel-release-beed268c41584b5386dd0f472bdd6bc0'
FAILED=EVIDENCE/'r10aj-kernel-development-47f0339676364e92a12ab6e71eb13127'
INPUTS=ROOT/'sdk/core/contracts/r10aj_retained_canonical_geometry_input_binding_v1.json'
CONTRACT=ROOT/'sdk/recovery/r10aj_hip_recenter_kernel_contract_v1.json'
RECORD=ROOT/'sdk/recovery/r10aj_hip_recenter_kernel_component_v1.json'
CLAIMS=dict(mathematical_kernel_implemented=True,native_composition_integrated=False,
    complete_safety_gate_qualified=False,new_physical_population_declared=False,
    original_result_regraded=False,physical_recovery_obtained=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def observations():
    failed=closure.read(FAILED/'execution.json')
    assert failed['returncode']==3221225725 and failed['source_unchanged'] is True
    error=(FAILED/'stderr.log').read_text()
    assert 'has overflowed its stack' in error and 'v56_public_policy_profile_and_memory_keep_v55_configuration_and_refuse_crossed_memory' in error
    execution=closure.read(OUT/'execution.json')
    assert execution['returncode']==0 and execution['source_unchanged'] is True
    assert '--release' in execution['command'] and '--locked' in execution['command'] and '--offline' in execution['command']
    assert closure.read(OUT/'source-before.json')==closure.read(OUT/'source-after.json')
    bindings=closure.read(OUT/'bindings-before.json');assert bindings==closure.read(OUT/'bindings-after.json')
    for item in bindings:assert closure.bind(item['path'])==item
    parsed=[];summaries=[]
    for line in (OUT/'stdout.log').open(encoding='utf-8'):
        _,marker,payload=line.partition('R10AJ_GEOMETRY_FIXTURE ')
        if marker:parsed.append(json.loads(payload))
        if line.startswith('test result:'):summaries.append(line.strip())
    assert len(summaries)==1 and re.fullmatch(r'test result: ok\. 478 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in [0-9.]+s',summaries[0])
    assert len(parsed)==len({p['semantic_step'] for p in parsed})==600
    manifest=closure.read(INPUTS);assert closure.bind(manifest['fixture']['path'])==manifest['fixture']
    fixture=closure.read(manifest['fixture']['path']);assert fixture['source_report']==manifest['source_report']
    assert closure.bind(manifest['source_report']['path'])==manifest['source_report']
    assert manifest['source_report']['raw_sha256']==closure.REPORT_SHA
    assert fixture['terminal_inputs']==manifest['terminal_inputs']==0
    original=[]
    for packet in closure.geometry.records(closure.CHILD/'worker_report.json','r10ai_partial_recovery','step_packets'):
        plan=packet['native_receipt']['next_load_plan']
        if plan is None:continue
        request=json.loads(packet['call']['request']['utf8_text']);o=request['step']['observation']
        assert request['collection']['descriptor']==fixture['descriptor']
        joints=[j['position_rad'] for j in o['state']['ordered_joint_observations']]
        expected=model.plan(fixture['descriptor'],o['state']['base_pose_world']['orientation_xyzw'],joints,[True]*4)
        original.append(dict(observation=o,original_plan=plan,expected_hip_recenter=expected))
    assert original==fixture['observations'] and len(original)==600
    error_max=0.;preserved=changed=0
    for compiled,row in zip(parsed,original,strict=True):
        assert compiled['semantic_step']==row['observation']['semantic_step']
        assert compiled['source_sha256']==row['original_plan']['source_observation_sha256']
        qualified=all(row['original_plan']['qualified_support'])
        expected=row['original_plan']['ordered_target_positions_rad'] if qualified else row['expected_hip_recenter']['targets']
        assert compiled['mode']==('unchanged_v25_reference' if qualified else 'weak_support_hip_recenter')
        error_max=max(error_max,max(abs(a-b) for a,b in zip(compiled['targets'],expected,strict=True)))
        preserved+=qualified;changed+=not qualified
    assert (changed,preserved)==(599,1) and error_max<1e-10
    return dict(release_core_tests_passed=478,new_kernel_tests_passed=4,python_model_tests_passed=6,
        retained_inputs=600,compiled_model_comparisons=600,source_observation_hashes_preserved=600,
        changed_weak_support_targets=599,preserved_fully_qualified_targets=1,
        support_establishment_parity_inputs=600,maximum_target_error_rad=error_max,
        retained_failed_debug_runs=1,debug_failure='STATUS_STACK_OVERFLOW in existing V56 test',
        model_initial_pose_full_alignment_within_600_updates=False,**CLAIMS)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],*record['dependencies'],*record['retained_evidence']]:
        assert closure.bind(item['path'])==item,item['path']
    assert record['observed']==observations()
    return record['observed']


def create():
    assert not RECORD.exists()
    # Recompute the complete independent probe before recording its six tests.
    probe.audit()
    value=observations()
    paths=[Path(model.__file__),Path(probe.__file__),INPUTS,CONTRACT,probe.PROTOCOL,probe.RECORD,
        ROOT/'sdk/core/src/recovery_runtime.rs',ROOT/'sdk/core/src/recovery_runtime/partial_hip_recenter_control.rs',
        ROOT/'sdk/core/src/recovery_runtime/tests/partial_hip_recenter_control_tests.rs',
        ROOT/'tests/test_r10aj_hip_recenter_model.py']
    fixture=Path(closure.read(INPUTS)['fixture']['path'])
    record=dict(schema_version='sporespore_r10aj_hip_recenter_kernel_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral',authority_mode='compiled_geometry_component',question_class='development'),
        auditor=closure.bind(__file__),dependencies=[closure.bind(p) for p in paths],
        retained_evidence=[closure.bind(p) for folder in (OUT,FAILED) for p in sorted(folder.iterdir()) if p.is_file()]+[closure.bind(fixture)],
        observed=value,claim_boundary=CLAIMS,
        next_action='Integrate a distinct native V26 composition and C/Python/Godot interfaces preserving original source, ownership, energy, task clocks and terminal refusal. Then declare a fresh candidate and diagnostic population, complete the applicable safety graph, and run one bounded physical diagnostic. Do not reuse R10AI populations, source keys or fixtures.')
    result=audit(record);closure.write_new(RECORD,record);return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(closure.read(RECORD)),indent=2))
