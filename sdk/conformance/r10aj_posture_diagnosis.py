"""Diagnose the consumed R10AJ trajectory using original retained samples only.

This decomposes measured foot motion; it cannot identify contact-force causality
or predict a successor's physics. No replay process, controller or world runs.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import struct

import r10aj_hip_recenter_closure as closure
import r10aj_hip_recenter_model as model

G = closure.geometry
RECORD = closure.ROOT/'sdk/recovery/r10aj_posture_diagnosis_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, original_result_regraded=False,
    controller_changed=False, physical_execution_authorized=False,
    physical_acceptance_authority=False, release_authority=False)


def rows():
    path = closure.CHILD/'worker_report.json'
    assert closure.bind(path)['raw_sha256'] == closure.REPORT_SHA
    descriptor = closure.streams.small_fields(path)['configuration']['base_descriptor']
    samples = []
    for packet in G.records(path, 'r10aj_partial_recovery', 'step_packets'):
        native = packet['native_receipt']; observation = native['collection']['observation']
        row = closure.streams.diagnosis.snapshot(packet)
        row.update(plan=native['next_load_plan'], position=G.vector(observation['state']['base_pose_world']['position_m']),
            qualified_support=G.qualified_support(observation),
            applied_impulses=[x['applied_angular_impulse_nms'] for x in observation['applied_actuation']['ordered_applied_impulses']],
            caps=[x['published_maximum_outer_step_impulse_nms'] for x in packet['source_application']['ordered_intents']],
            applied_command=packet['source_application']['command_sha256'],
            next_command=None if native['next_control'] is None else native['next_control']['command_sha256'])
        if row['plan'] is not None:
            assert row['qualified_support'] == row['plan']['qualified_support']
            assert max(abs(a-b) for a,b in zip(row['next_control']['target_positions_rad'],
                row['plan']['ordered_target_positions_rad'],strict=True)) < 1e-12
        samples.append(row)
    assert len(samples) == 601
    indexed = {r['semantic_step']:r for r in samples}
    for record in G.records(path, 'r10af_contact_frames', 'records'):
        packet = record['packet']; step = packet['semantic_step']
        if step not in indexed: continue
        row = indexed[step]; bodies = {b['body_id']:b for b in packet['callback_bodies']}
        assert G.vector(bodies['torso']['pose']['origin']) == row['position']
        feet = []
        for foot in G.FEET:
            pose = bodies[foot+'_distal']['pose']
            center = G.vector(packet['contact_sites_by_body'][foot+'_distal']['local_center_m'])
            center = [struct.unpack('<f',struct.pack('<f',x))[0] for x in center]
            columns = [G.vector(v) for v in pose['basis_columns']]; origin = G.vector(pose['origin'])
            feet.append([origin[a]+sum(columns[c][a]*center[c] for c in range(3)) for a in range(3)])
        row['measured_cap_centers'] = feet
        row['modeled_cap_centers'] = [[row['position'][a]+G.rotate(row['orientation_xyzw'],v)[a]
            for a in range(3)] for v in G.fk(descriptor,row['joint_positions_rad'])]
    assert all('measured_cap_centers' in r for r in samples)
    return descriptor,samples


def derive():
    descriptor,samples = rows(); pairs=list(zip(samples,samples[1:]))
    errors=[]; parity=[]; commands=[]
    for before,after in pairs:
        assert before['semantic_step']+1 == after['semantic_step']
        assert before['next_command'] == after['applied_command']
        target = before['next_control']['target_positions_rad']
        for j in range(8):
            errors.append(after['applied_target_velocities_rad_s'][j]-max(-4.,min(4.,
                (target[j]-before['joint_positions_rad'][j])/G.DT)))
        if before['plan']['mode'] != 'weak_support_hip_recenter': continue
        rebuilt=model.plan(descriptor,before['orientation_xyzw'],before['joint_positions_rad'],[True]*4)
        parity.extend(abs(a-b) for a,b in zip(target,rebuilt['targets'],strict=True))
        geometry=before['plan']['hip_recenter_geometry']
        assert rebuilt['hold_reason'] == geometry['hold_reason']
        assert geometry['explicit_limit_return_joints'] == []
        assert all(before['plan']['ordered_target_positions_rad'][j] == before['joint_positions_rad'][j] for j in (1,3,5,7))
        displacement=model.displacement(descriptor,before['orientation_xyzw'],before['joint_positions_rad'],target)
        components=[G.motion_components(descriptor,before,after,i) for i in range(4)]
        commands.append(dict(partial_step=before['partial_step'],
            qualified_before=before['qualified_support'],qualified_after=after['qualified_support'],
            hip_delta_rad=[target[j]-before['joint_positions_rad'][j] for j in (0,2,4,6)],
            target_error_rad=[after['joint_positions_rad'][j]-target[j] for j in range(8)],
            applied_cap_fraction=[abs(after['applied_impulses'][j])/after['caps'][j] for j in range(8)],
            fixed_torso_commanded_foot_dy_m=[v[1] for v in displacement],
            torso_up_before=before['classification']['torso_up_dot'],
            torso_up_after=after['classification']['torso_up_dot'],foot_motion=components))
    assert errors == [0.]*4800 and len(commands) == 599 and max(parity)<1e-10
    aggregate=[]
    for i in range(4):
        aggregate.append(dict(foot=G.FEET[i],qualified_before=sum(c['qualified_before'][i] for c in commands),
            qualified_after=sum(c['qualified_after'][i] for c in commands),
            negative_hip_commands=sum(c['hip_delta_rad'][i]<0 for c in commands),
            fixed_torso_downward_commands=sum(c['fixed_torso_commanded_foot_dy_m'][i]<0 for c in commands),
            actual_upward_steps=sum(c['foot_motion'][i]['actual_world_dy_m']>0 for c in commands),
            accumulated_motion_m={k:sum(c['foot_motion'][i][k] for c in commands) for k in commands[0]['foot_motion'][i]},
            target_error_rad=G.stats([c['target_error_rad'][2*i] for c in commands]),
            cap_fraction=G.stats([c['applied_cap_fraction'][2*i] for c in commands])))
    paths=[Path(__file__),closure.RECORD,Path(closure.__file__),Path(model.__file__),
        Path(G.__file__),Path(closure.streams.diagnosis.__file__),Path(model.vectors.__file__)]
    return dict(schema_version='sporespore_r10aj_posture_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_retained_data',
            authority_mode='retained_input_offline_diagnosis',question_class='development'),
        bindings=[closure.bind(p) for p in paths],source_report=closure.bind(closure.CHILD/'worker_report.json'),
        original_source_commit=closure.HEAD,original_outcome='valid_development_negative',
        command_links=600,canonical_motor_velocity_mapping_errors=0,
        independently_reconstructed_hip_plans=599,maximum_target_model_error_rad=max(parity),
        all_599_geometric_hip_plans_preserve_measured_knees=True,
        canonical_command_rounding_error_bound_rad=1e-12,foot_analysis=aggregate,
        pose_trend=dict(first_up=samples[0]['classification']['torso_up_dot'],
            final_up=samples[-1]['classification']['torso_up_dot'],
            first_negative_up_partial_step=next(r['partial_step'] for r in samples if r['classification']['torso_up_dot']<0),
            torso_translation_gain_m=samples[-1]['position'][1]-samples[0]['position'][1]),
        commands=commands,
        inference='Hip targets and canonical velocity mapping match their declared models. '
            'Rear feet carry most qualified support while the torso pitches past horizontal. '
            'A fixed-torso downward foot target is not a guarantee of downward world foot motion or load acquisition. '
            'Before another physical candidate, evaluate coordinated posture and foot placement, explicitly separating '
            'loaded-foot constraints from unqualified-foot acquisition. Do not extend this exhausted budget.',
        limitations=['Algebraic motion decomposition is order dependent and is not contact-force causality.',
            'No matched baseline, held-out evidence or counterfactual physical outcome.',
            'Model reconstruction verifies implementation and geometry only; it does not prove a successor.'],**CLAIMS)


def audit():
    assert closure.read(RECORD) == derive()
    return dict(ok=True,command_links=600,reconstructed_hip_plans=599,
        canonical_motor_velocity_mapping_errors=0,**CLAIMS)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    if args.create: closure.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))
