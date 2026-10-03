"""Audit the zero-world R10AF classification seam; no campaign qualification."""
import argparse
import json
from pathlib import Path

import detection_frame_contact_source_v1 as reader
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

CHECK=EVIDENCE/'r10af-contact-reader-component-7dc95638cf62410595808a0a5502d122'
RECORD=ROOT/'sdk/recovery/r10af_detection_frame_component_v1.json'
SOURCES=[
    'sdk/recovery/r10af_detection_frame_development_design_v1.json',
    'sdk/adapters/godot/gdscript/recovery_detection_frame_contacts_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
    'sdk/conformance/detection_frame_contact_source_v1.py',
    'sdk/conformance/contact_frame_replay_v2.py',
    'sdk/conformance/r10ac_contact_frame_replay.py',
    'tests/test_r10af_detection_frame_contacts.gd',
    'tests/test_r10af_detection_frame_contacts.py',
    'tests/test_r10ac_contact_frame_capture.gd',
    'tests/test_r10ac_contact_frames_zero_world.gd',
    'tests/test_r10ae_complete_report.py',
    'tests/test_sdk_qsdk_r24d75_godot_contact_source_retention_zero_world.gd',
]
CLAIMS=dict(physical_population_reserved=False,physical_attempt_started=False,
    production_dispatch_implemented=True,production_physical_dispatch_exercised=False,
    complete_report_integration_proven=False,complete_safety_gate_qualified=False,
    controller_changed=False,thresholds_changed=False,core_dll_changed=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,
    release_authority=False,sdk1_score='14/20')


def observations():
    assert read(CHECK/'source-before.json') == read(CHECK/'source-after.json')
    fixtures=read(CHECK/'fixtures.json')
    assert fixtures['ok'] is True and fixtures['negative_refusals'] == 20
    assert fixtures['empty_population_passed'] is True
    assert fixtures['world_build_count'] == fixtures['solver_step_count'] == 0
    for name in ['native','legacy-retention']:
        execution=read(CHECK/(name+'.execution.json'))
        assert execution['returncode'] == 0 and execution['timed_out'] is False
        assert execution['world_build_count'] == execution['solver_step_count'] == 0
        assert not (CHECK/(name+'.stderr.txt')).read_bytes()
    cases=fixtures['positive_cases'];assert len(cases) == 6
    independent=[]
    for case in cases:
        packet=case['legacy_packet']
        replay=reader.replay_source(case['source_receipt'],packet['callback_bodies'],packet['contact_sites_by_body'])
        assert replay['matched_loaded_floor_contacts'] == 1
        comparison=replay['comparisons'][0]
        assert comparison['classified_as_foot'] == case['detection_classified_as_foot']
        assert comparison['callback_classified_as_foot'] == case['callback_classified_as_foot']
        assert comparison['normal_impulse_ns'] == sum(replay['foot_impulses_by_body'].values())+sum(replay['nonfoot_impulses_by_body'].values())
        assert case['retained']['contact_source_receipt'] == case['source_receipt']
        independent.append(replay)
    assert independent == read(CHECK/'independent-results.json')
    assert cases[0]['callback_classified_as_foot'] is False and cases[0]['detection_classified_as_foot'] is True
    assert cases[1]['callback_classified_as_foot'] is True and cases[1]['detection_classified_as_foot'] is False
    assert cases[-1]['source_receipt']['ordered_contact_samples'][0]['body_id'] == 'torso'
    assert cases[-1]['detection_classified_as_foot'] is False
    marker='QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_ZERO_WORLD '
    rows=[json.loads(line[len(marker):]) for line in (CHECK/'legacy-retention.stdout.txt').read_text(encoding='utf-8-sig').splitlines() if line.startswith(marker)]
    assert len(rows) == 1 and rows[0]['ok'] is True and rows[0]['exact_mutation_rejection_count'] == 8
    assert rows[0]['world_build_count'] == rows[0]['solver_step_count'] == 0
    world=(ROOT/SOURCES[2]).read_text(encoding='utf-8')
    assert 'const CONTACT_CLASSIFICATION_TOLERANCE_M := 1.0e-6' in world
    return dict(native_positive_cases=6,independent_positive_cases=6,
        native_negative_refusals=20,legacy_retention_negative_refusals=8,
        both_classification_directions_checked=True,rotated_frame_checked=True,
        both_native_point_sides_checked=True,torso_callback_classification_preserved=True,
        authored_scalar_center_checked=True,empty_population_checked=True,
        impulse_partition_conserved=True,legacy_retention_preserved=True,
        source_unchanged_during_native_checks=True)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for value in record['bindings']+[record['auditor']]:assert bind(value['path']) == value
    assert record['observed'] == observations()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    paths=[ROOT/name for name in SOURCES]+[p for p in sorted(CHECK.iterdir()) if p.is_file()]
    record=dict(schema_version='sporespore_r10af_detection_frame_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='zero_world_classification_component',question_class='development'),
        auditor=bind(__file__),bindings=[bind(p) for p in paths],observed=observations(),claim_boundary=CLAIMS,
        coverage_limits=['No native world was constructed or stepped.',
            'The selected production branch is implemented but has not been exercised in a live world.',
            'Fresh worker/profile/seed dispatch, complete native and Python report replay, launcher context handoff, full applicable safety graph and clean pushed freeze remain required.',
            'This component does not renew a consumed R10AE population or prove recovery improvement.'])
    result=audit(record);write_new(RECORD,record);return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args();print(json.dumps(create() if args.create else audit(read(RECORD))))
