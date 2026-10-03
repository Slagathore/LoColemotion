"""Authenticate retained R10AM compiled tests and independent geometry parity.

This audit never compiles, loads a native library or opens a world.
"""
import argparse
import json
from pathlib import Path
import re

import r10aj_hip_recenter_closure as closure
import r10al_support_anchored_model as model

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
OUT=EVIDENCE/'r10am-kernel-release-d1893480d5394c1ebd6c9093d3059e53'
FAILED=EVIDENCE/'r10am-kernel-release-e6663ddf76bd4e34a5869fc99311b451'
INPUTS=ROOT/'sdk/core/contracts/r10am_retained_canonical_geometry_input_binding_v1.json'
CONTRACT=ROOT/'sdk/recovery/r10am_support_anchored_kernel_contract_v1.json'
RECORD=ROOT/'sdk/recovery/r10am_support_anchored_kernel_component_v1.json'
CLAIMS=dict(mathematical_kernel_implemented=True,native_composition_integrated=False,
    complete_safety_gate_qualified=False,new_physical_population_declared=False,
    original_result_regraded=False,physical_recovery_obtained=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def observations():
    failed=closure.read(FAILED/'execution.json')
    assert failed['cargo_started'] is False and failed['stage']=='source_binding_before_cargo'
    execution=closure.read(OUT/'execution.json')
    assert execution['returncode']==0 and execution['source_unchanged'] is True
    assert all(x in execution['command'] for x in ('--release','--locked','--offline','--lib'))
    bound=closure.read(OUT/'bindings-before.json');assert bound==closure.read(OUT/'bindings-after.json')
    for item in bound:assert closure.bind(item['path'])==item
    outputs=[];summaries=[]
    for line in (OUT/'stdout.log').open():
        _,marker,payload=line.partition('R10AM_GEOMETRY_FIXTURE ')
        if marker:outputs.append(json.loads(payload))
        if line.startswith('test result:'):summaries.append(line.strip())
    assert len(summaries)==1 and re.fullmatch(r'test result: ok\. 489 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in [0-9.]+s',summaries[0])
    manifest=closure.read(INPUTS)
    for key in ('fixture','source_report','independent_model'):assert closure.bind(manifest[key]['path'])==manifest[key]
    fixture=closure.read(manifest['fixture']['path']);assert fixture['source_report']==manifest['source_report']
    assert fixture['terminal_inputs']==manifest['terminal_inputs']==0
    rows=fixture['observations'];assert len(rows)==len(outputs)==600
    original=[]
    for packet in closure.geometry.records(closure.CHILD/'worker_report.json','r10aj_partial_recovery','step_packets'):
        plan=packet['native_receipt']['next_load_plan']
        if plan is None:continue
        request=json.loads(packet['call']['request']['utf8_text']);o=request['step']['observation']
        assert request['collection']['descriptor']==fixture['descriptor']
        original.append(dict(observation=o,original_plan=plan,expected=model.search(model.G.Model(o,fixture['descriptor']))))
    assert original==rows
    selected=fallback=0;error=0.
    for compiled,row in zip(outputs,rows,strict=True):
        assert compiled['semantic_step']==row['observation']['semantic_step']
        assert compiled['source_sha256']==row['original_plan']['source_observation_sha256']
        expected=row['expected'];g=compiled['geometry'];assert g['candidate_count']==expected['candidates']
        assert g['feasible_candidate_count']==expected['feasible']
        if expected['selected'] is None:
            fallback+=1;assert compiled['mode']=='explicit_v23_fallback'
            assert g['hold_reason']==expected['refusal']
            targets=row['original_plan']['baseline_reference']['baseline_reference']['ordered_target_positions_rad']
        else:
            selected+=1;assert compiled['mode']=='support_anchored_leveling'
            targets=expected['selected']['targets'];assert g['selected_scale']==expected['selected']['scale']
            assert g['virtual_level_blend']==expected['selected']['blend']
        error=max(error,max(abs(a-b) for a,b in zip(compiled['targets'],targets,strict=True)))
    assert (selected,fallback)==(585,15) and error<1e-10
    return dict(release_core_tests_passed=489,new_kernel_tests_passed=4,
        canonical_inputs=600,compiled_model_comparisons=600,support_establishment_parity_inputs=600,
        source_observation_hashes_preserved=600,selected_anchored_plans=585,explicit_v23_fallbacks=15,
        maximum_target_error_rad=error,retained_pre_cargo_wrapper_failures=1,**CLAIMS)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],*record['dependencies'],*record['retained_evidence']]:assert closure.bind(item['path'])==item
    assert record['observed']==observations()
    return record['observed']


def create():
    assert not RECORD.exists();observed=observations()
    paths=[Path(model.__file__),Path(model.G.__file__),INPUTS,CONTRACT,
        ROOT/'sdk/core/src/recovery_runtime.rs',ROOT/'sdk/core/src/recovery_runtime/partial_support_anchored_control.rs',
        ROOT/'sdk/core/src/recovery_runtime/tests/partial_support_anchored_control_tests.rs',
        ROOT/'sdk/recovery/r10al_support_anchored_leveling_result_v1.json',
        ROOT/'sdk/recovery/r10al_support_anchored_propagation_result_v1.json']
    fixture=Path(closure.read(INPUTS)['fixture']['path'])
    value=dict(schema_version='sporespore_r10am_support_anchored_kernel_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral',authority_mode='compiled_geometry_component',question_class='development'),
        auditor=closure.bind(__file__),dependencies=[closure.bind(p) for p in paths],
        retained_evidence=[closure.bind(p) for folder in (OUT,FAILED) for p in sorted(folder.iterdir()) if p.is_file()]+[closure.bind(fixture)],
        observed=observed,claim_boundary=CLAIMS,
        next_action='Integrate distinct native V27 composition and C/Python/Godot interfaces preserving source, ownership, energy, phase clocks and terminal refusal. Then declare a fresh development candidate, complete applicable safety coverage, and run one bounded diagnostic. No R10AJ population or source key may be renewed.')
    closure.write_new(RECORD,value);return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(closure.read(RECORD)),indent=2))
