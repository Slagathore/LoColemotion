"""Retain and replay two zero-world diagnostics; no successor launch authority."""
import argparse
import json
from pathlib import Path

import r10aa_support_first_workspace_probe as workspace
import r10aa_native_contact_geometry_probe as contacts
import r10z_first_support_closure as closed

RECORD = closed.ROOT/'sdk/recovery/r10aa_support_first_diagnosis_v1.json'
WORKSPACE = closed.EVIDENCE/'r10aa-support-first-workspace-d59f5425f5034db0bc9052c63e4af5d0'
CONTACTS = closed.EVIDENCE/'r10aa-native-contact-geometry-32094234db1d494b8e3b674ef31be8a0'


def observations():
    first, second = closed.read(WORKSPACE/'probe.json'), closed.read(CONTACTS/'probe.json')
    assert closed.read(WORKSPACE/'execution.json')['exit_code'] == 0
    assert closed.read(CONTACTS/'execution.json')['exit_code'] == 0
    assert first == workspace.derive()
    assert second == contacts.derive()
    # Independently check extraction provenance against the original report
    # declarations, not just the previously extracted entry JSON.
    for entry in closed.read(workspace.ENTRIES)['entries']:
        for kind, value in closed.diagnosis.read_partial(Path(entry['report']['path'])):
            if kind == 'declaration':
                passive = value['entry_request']['passive_request']
                assert passive['observation'] == entry['observation']
                assert passive['declaration']['initialization']['descriptor'] == entry['descriptor']
                break
        else:
            raise AssertionError('ORIGINAL_ENTRY_DECLARATION_MISSING')
    missing = [dict(label=r['label'],limb=s['limb'],shortfall_m=s['optimistic_unrestricted_ground_shortfall_m'])
        for r in first['rows'] for s in r['limbs'] if not s['bearing_reference']
        and s.get('optimistic_unrestricted_ground_shortfall_m',0)>1e-9]
    assert len(missing) == 27 and missing[0]['label'] == 'r10z_step_214' and missing[-1]['label'] == 'r10z_step_240'
    assert {r['limb'] for r in missing} == {'front_right'}
    by_body = second['by_body']
    return dict(workspace_summary=first['summary'], native_contact_samples=second['contact_samples'],
        maximum_torso_contact_transform_error_m=by_body['torso']['maximum_position_error_m'],
        maximum_distal_contact_vertical_error_m=max(v['maximum_absolute_vertical_error_m'] for k,v in by_body.items() if k!='torso'),
        fixed_torso_model_unreachable_limb='front_right', fixed_torso_model_unreachable_steps=[214,240],
        maximum_fixed_torso_model_ground_shortfall_m=max(r['shortfall_m'] for r in missing),
        original_entries_verified=4, independent_native_geometry_checks=239,
        world_build_count=0,solver_step_count=0,controller_implemented=False,
        support_loading_proven=False,physical_acceptance_authority=False,release_authority=False)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in (WORKSPACE,CONTACTS) for p in sorted(folder.iterdir()) if p.is_file()]
    value = dict(schema_version='sporespore_r10aa_support_first_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='offline_diagnostic_closure',question_class='development'),
        dependencies=[closed.binding(p) for p in (Path(__file__),Path(workspace.__file__),Path(contacts.__file__),closed.RECORD)],
        retained_evidence=[closed.binding(p) for p in files],observed=observed,
        interpretation=[
            'All 616 positive-gap nonbearing samples admit a bounded grid target that reduces the modeled gap; this is not proof of motor tracking or contact force.',
            'At R10Z steps 214 through 240 the ideal fixed-torso front-right workspace cannot reach the estimated plane, even without joint limits. The plane is inferred from modeled bearing feet, not an exact native terrain observation.',
            'Native local/world contact pairs agree with ideal reconstructed vertical positions within 0.000838 m; this limits but does not eliminate kinematic error as a cause.',
            'Eight nonbearing samples are already at or below the estimated plane. Upper-cap body contacts and nonzero bearing references do not establish the task-required distal loads.',
            'A support-first successor must distinguish measured loading from geometric reach and account for torso motion; simply disabling rise or increasing time is insufficiently justified.'
        ],
        finite_next_blockers=[
            'Declare a phase-specific support objective and load feedback using exact measured inputs; explicitly handle nonbearing feet at or below the inferred plane.',
            'Probe the complete proposed support controller across exposed entries and native source boundaries before a distinct bounded smoke identity.',
            'After complete diagnostic route coverage, obtain fresh paired commissioning and a prospectively qualified held-out acceptance population.'
        ],
        r10z_population_consumed=True,r10z_retry_permitted=False,held_out_worlds_opened=0,
        source_key_refresh_authorized=False,physical_acceptance_authority=False,release_authority=False)
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
    return observed


def audit():
    value = closed.read(RECORD)
    for row in value['dependencies']+value['retained_evidence']:
        assert row == closed.binding(Path(row['path']))
    observed = observations()
    assert observed == value['observed']
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    args=parser.parse_args()
    print(json.dumps(capture() if args.capture else audit()),flush=True)
