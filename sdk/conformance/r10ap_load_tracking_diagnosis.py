"""Describe original R10AP motor tracking and contact loss; no new physics or grading."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import struct

import r10ap_progressive_headroom_closure as C
import r10af_rise_tracking_analysis as G

RECORD = C.ROOT/'sdk/recovery/r10ap_load_tracking_diagnosis_v1.json'
SCOPE = dict(subsystem='recovery', engine_scope='godot_jolt',
    authority_mode='retained_trajectory_diagnosis', question_class='development')
CLAIMS = dict(original_result_regraded=False, physical_recovery_obtained=False,
    causal_effect_identified=False, new_controller_selected=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def rows():
    path = C.CHILD/'worker_report.json'
    assert C.bind(path)['raw_sha256'] == C.REPORT_SHA
    descriptor = C.streams.small_fields(path)['configuration']['base_descriptor']
    result = []
    for packet in G.records(path, 'r10ap_partial_recovery', 'step_packets'):
        native = packet['native_receipt']; observation = native['collection']['observation']
        row = C.streams.diagnosis.snapshot(packet)
        row.update(plan=native['next_load_plan'], position=G.vector(observation['state']['base_pose_world']['position_m']),
            com=G.vector(observation['center_of_mass']['position_world_m']),
            qualified_support=G.qualified_support(observation),
            bearing_impulses=[x['bearing_normal_impulse_ns'] for x in observation['ordered_foot_bearing_observations']],
            applied_impulses=[x['applied_angular_impulse_nms'] for x in observation['applied_actuation']['ordered_applied_impulses']],
            caps=[x['published_maximum_outer_step_impulse_nms'] for x in packet['source_application']['ordered_intents']],
            applied_command_sha256=packet['source_application']['command_sha256'],
            next_command_sha256=None if native['next_control'] is None else native['next_control']['command_sha256'])
        if row['plan'] is not None:
            assert row['qualified_support'] == row['plan']['baseline_reference']['qualified_support']
        result.append(row)
    assert len(result) == 601
    indexed = {r['semantic_step']: r for r in result}
    for record in G.records(path, 'r10af_contact_frames', 'records'):
        packet = record['packet']; step = packet['semantic_step']
        if step not in indexed: continue
        row = indexed[step]
        assert 'measured_cap_centers' not in row
        bodies = {b['body_id']: b for b in packet['callback_bodies']}
        assert G.vector(bodies['torso']['pose']['origin']) == row['position']
        feet = []
        for foot in G.FEET:
            pose = bodies[foot+'_distal']['pose']
            center = G.vector(packet['contact_sites_by_body'][foot+'_distal']['local_center_m'])
            center = [struct.unpack('<f', struct.pack('<f', x))[0] for x in center]
            columns = [G.vector(v) for v in pose['basis_columns']]; origin = G.vector(pose['origin'])
            feet.append([origin[a]+sum(columns[c][a]*center[c] for c in range(3)) for a in range(3)])
        row['measured_cap_centers'] = feet
        modeled = G.fk(descriptor, row['joint_positions_rad'])
        row['modeled_cap_centers'] = [[row['position'][a]+G.rotate(row['orientation_xyzw'], v)[a] for a in range(3)] for v in modeled]
    assert all('measured_cap_centers' in r for r in result)
    for before, after in zip(result, result[1:]):
        assert before['semantic_step']+1 == after['semantic_step']
        assert before['next_command_sha256'] == after['applied_command_sha256']
    return descriptor, result


def analyze():
    descriptor, samples = rows()
    pairs = list(zip(samples, samples[1:]))
    mapping = [b['applied_target_velocities_rad_s'][j]-max(-4.,min(4.,
        (a['next_control']['target_positions_rad'][j]-a['joint_positions_rad'][j])/G.DT))
        for a,b in pairs for j in range(8)]
    assert mapping == [0.]*4800
    joint = []
    for j in range(8):
        joint.append(dict(joint_index=j,
            target_error_rad=G.stats([b['joint_positions_rad'][j]-a['next_control']['target_positions_rad'][j] for a,b in pairs]),
            measured_velocity_minus_target_rad_s=G.stats([b['joint_velocities_rad_s'][j]-b['applied_target_velocities_rad_s'][j] for a,b in pairs]),
            applied_cap_fraction=G.stats([abs(b['applied_impulses'][j])/b['caps'][j] for a,b in pairs]),
            near_cap_count=sum(abs(b['applied_impulses'][j])/b['caps'][j] >= .99 for a,b in pairs)))
    feet = []
    for i, name in enumerate(G.FEET):
        components = [G.motion_components(descriptor,a,b,i) for a,b in pairs]
        feet.append(dict(foot=name,
            qualified_samples=sum(b['qualified_support'][i] for a,b in pairs),
            positive_bearing_samples=sum(b['bearing_impulses'][i]>0 for a,b in pairs),
            first_qualified_loss=next((b['partial_step'] for a,b in pairs if a['qualified_support'][i] and not b['qualified_support'][i]),None),
            last_positive_bearing=next((r['partial_step'] for r in reversed(samples) if r['bearing_impulses'][i]>0),None),
            bearing_impulse_ns=G.stats([b['bearing_impulses'][i] for a,b in pairs]),
            fk_error_m=G.stats([math.dist(r['measured_cap_centers'][i],r['modeled_cap_centers'][i]) for r in samples]),
            motion_component_totals_m={k:sum(r[k] for r in components) for k in components[0]},
            measured_height_start_end_m=[samples[k]['measured_cap_centers'][i][1] for k in (0,-1)]))
    phases = {}
    for mode in ('raise_with_headroom','recover_joint_headroom','explicit_v23_fallback'):
        selected = [(a,b) for a,b in pairs if a['plan']['mode']==mode]
        phases[mode]=dict(commands=len(selected),
            planned_level_blend=G.stats([a['plan']['progressive_headroom_geometry']['virtual_level_blend'] for a,b in selected]),
            planned_height_change_m=G.stats([a['plan']['progressive_headroom_geometry']['virtual_translation_world_m'][1] for a,b in selected]),
            actual_height_change_m=G.stats([b['position'][1]-a['position'][1] for a,b in selected]),
            actual_up_dot_change=G.stats([b['classification']['torso_up_dot']-a['classification']['torso_up_dot'] for a,b in selected]),
            positive_level_blend_but_up_dot_decreased=sum(a['plan']['progressive_headroom_geometry']['virtual_level_blend']>0 and b['classification']['torso_up_dot']<a['classification']['torso_up_dot'] for a,b in selected))
    snapshots=[]
    for r in samples:
        if r['partial_step'] not in (1,2,5,10,15,30,61,121,241,301,601):continue
        forward=G.rotate(r['orientation_xyzw'],[1.,0.,0.]); n=math.hypot(forward[0],forward[2]); heading=[forward[0]/n,0.,forward[2]/n]
        relative=[[sum((p[k]-r['com'][k])*heading[k] for k in range(3)),p[1]] for p in r['measured_cap_centers']]
        snapshots.append(dict(partial_step=r['partial_step'],torso_up_dot=r['classification']['torso_up_dot'],
            position_m=r['position'],com_m=r['com'],feet_forward_relative_to_com_and_world_height_m=relative,
            bearing_impulses_ns=r['bearing_impulses'],joint_positions_rad=r['joint_positions_rad'],
            qualified_support=r['qualified_support'],plan=None if not r['plan'] else r['plan']['progressive_headroom_geometry']))
    return dict(observations=len(samples),command_links=len(pairs),motor_mapping_exact_count=len(mapping),
        joint_tracking=joint,foot_tracking=feet,mode_tracking=phases,snapshots=snapshots,
        conventions=dict(foot_order=list(G.FEET),joint_order='hip then knee for each foot',
            near_cap_fraction=.99,motion_decomposition='Algebraic coordinate decomposition, not a causal attribution.',
            positive_bearing='Strictly positive measured normal impulse; not the qualified support threshold.'),
        **CLAIMS)


def dependencies():
    return [C.bind(p) for p in (C.RECORD,C.CHILD/'worker_report.json',Path(C.__file__),Path(G.__file__),
        Path(C.streams.__file__),Path(C.streams.diagnosis.__file__))]


def audit(record):
    assert record['schema_version']=='sporespore_r10ap_load_tracking_diagnosis_v1'
    assert record['ledger_scope']==SCOPE and record['claim_boundary']==CLAIMS
    assert record['analyzer']==C.bind(__file__) and record['dependencies']==dependencies()
    assert record['observed']==analyze()
    return dict(ok=True,observations=601,command_links=600,motor_mapping_exact_count=4800,**CLAIMS)


def create():
    assert not RECORD.exists()
    record=dict(schema_version='sporespore_r10ap_load_tracking_diagnosis_v1',ledger_scope=SCOPE,
        analyzer=C.bind(__file__),dependencies=dependencies(),observed=analyze(),claim_boundary=CLAIMS)
    result=audit(record);C.write_new(RECORD,record);return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args();print(json.dumps(create() if args.create else audit(C.read(RECORD)),indent=2))
