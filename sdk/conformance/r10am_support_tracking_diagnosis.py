"""Diagnose retained R10AM support and joint tracking without a new world.

Reconstruct each native geometry choice, connect each command to its next
observation, and separate ideal endpoint motion from actual callback cap motion.
These are descriptive measurements, not a causal comparison or a new controller.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import struct

import r10am_support_anchored_closure as closed
import r10al_support_anchored_model as model

G = closed.geometry
RECORD = closed.ROOT/'sdk/recovery/r10am_support_tracking_diagnosis_v1.json'
LIMITS = [1.6,1.1]*4
CLAIMS = dict(world_build_count=0, solver_step_count=0, original_result_regraded=False,
    controller_changed=False, causal_repair_proven=False, physical_execution_authorized=False,
    physical_acceptance_authority=False, release_authority=False)


def rows():
    path=closed.CHILD/'worker_report.json'
    assert closed.bind(path)['raw_sha256']==closed.REPORT_SHA
    descriptor=closed.streams.small_fields(path)['configuration']['base_descriptor']
    samples=[];parity=[];cost_error=[];fallbacks=Counter()
    for packet in G.records(path,'r10am_partial_recovery','step_packets'):
        native=packet['native_receipt'];o=native['collection']['observation']
        row=closed.streams.diagnosis.snapshot(packet);plan=native['next_load_plan']
        m=model.G.Model(o,descriptor)
        row.update(position=m.p, com=m.com, qualified_support=m.qualified, positive_bearing=m.bearing,
            bearing_impulses=m.impulses, plan=plan,
            joint_ids=[j['joint_id'] for j in o['state']['ordered_joint_observations']],
            applied_impulses=[v['applied_angular_impulse_nms'] for v in o['applied_actuation']['ordered_applied_impulses']],
            caps=[v['published_maximum_outer_step_impulse_nms'] for v in packet['source_application']['ordered_intents']],
            applied_command=packet['source_application']['command_sha256'],
            next_command=None if native['next_control'] is None else native['next_control']['command_sha256'])
        assert all(abs(q)<=limit for q,limit in zip(m.measured,LIMITS))==row['classification']['joint_limits_respected']
        if plan is not None:
            assert m.qualified==plan['baseline_reference']['qualified_support']
            rebuilt=model.search(m);selected=rebuilt['selected'];geometry=plan['support_anchored_geometry']
            assert geometry['positive_bearing']==m.bearing
            assert rebuilt['candidates']==geometry['candidate_count']
            assert rebuilt['feasible']==geometry['feasible_candidate_count']
            if selected is None:
                assert plan['mode']=='explicit_v23_fallback' and rebuilt['refusal']==geometry['hold_reason']
                assert plan['ordered_target_positions_rad']==plan['baseline_reference']['baseline_reference']['ordered_target_positions_rad']
                fallbacks[rebuilt['refusal']]+=1
            else:
                assert plan['mode']=='support_anchored_leveling'
                assert selected['scale']==geometry['selected_scale'] and selected['blend']==geometry['virtual_level_blend']
                parity.extend(abs(a-b) for a,b in zip(selected['targets'],plan['ordered_target_positions_rad'],strict=True))
                cost_error.append(abs(selected['cost']-geometry['selected_cost']))
            assert max(abs(a-b) for a,b in zip(plan['ordered_target_positions_rad'],row['next_control']['target_positions_rad'],strict=True))<=5.01e-13
        samples.append(row)
    assert len(samples)==601 and len(parity)==597*8 and dict(fallbacks)=={'no_positive_bearing_plane':3}
    assert max(parity)<1e-10 and max(cost_error)<1e-12
    indexed={r['semantic_step']:r for r in samples}
    for record in G.records(path,'r10af_contact_frames','records'):
        packet=record['packet'];row=indexed.get(packet['semantic_step'])
        if row is None:continue
        bodies={v['body_id']:v for v in packet['callback_bodies']}
        assert G.vector(bodies['torso']['pose']['origin'])==row['position']
        feet=[]
        for foot in G.FEET:
            pose=bodies[foot+'_distal']['pose'];origin=G.vector(pose['origin'])
            center=G.vector(packet['contact_sites_by_body'][foot+'_distal']['local_center_m'])
            center=[struct.unpack('<f',struct.pack('<f',v))[0] for v in center]
            columns=[G.vector(v) for v in pose['basis_columns']]
            feet.append([origin[a]+sum(columns[c][a]*center[c] for c in range(3)) for a in range(3)])
        row['measured_cap_centers']=feet
        row['modeled_cap_centers']=[model.G.add(row['position'],G.rotate(row['orientation_xyzw'],f))
            for f in G.fk(descriptor,row['joint_positions_rad'])]
    assert all('measured_cap_centers' in row for row in samples)
    return descriptor,samples,dict(reconstructed_plans=597, explicit_fallbacks=dict(fallbacks),
        maximum_target_error_rad=max(parity), maximum_cost_error=max(cost_error))


def derive():
    descriptor,samples,parity=rows();pairs=list(zip(samples,samples[1:]))
    mapping=[];joint=[[] for _ in range(8)];feet=[[] for _ in range(4)];commands=[]
    for before,after in pairs:
        assert before['next_command']==after['applied_command']
        assert before['semantic_step']+1==after['semantic_step']
        target=before['next_control']['target_positions_rad'];plan=before['plan'];geo=plan['support_anchored_geometry']
        for j,limit in enumerate(LIMITS):
            q=before['joint_positions_rad'][j];next_q=after['joint_positions_rad'][j];delta=target[j]-q
            velocity=max(-4.,min(4.,delta/G.DT));mapping.append(after['applied_target_velocities_rad_s'][j]-velocity)
            joint[j].append(dict(command_margin_rad=limit-abs(target[j]), measured_excess_rad=max(0.,abs(next_q)-limit),
                next_target_error_rad=next_q-target[j], actual_delta_rad=next_q-q, requested_delta_rad=delta,
                opposite_motion=(next_q-q)*delta<0 if abs(delta)>1e-8 else False,
                applied_cap_fraction=abs(after['applied_impulses'][j])/after['caps'][j],
                inward_command_at_limit=abs(q)>limit and q*delta<0))
        commanded_fk=G.fk(descriptor,target);measured_fk=G.fk(descriptor,before['joint_positions_rad'])
        if plan['mode']=='support_anchored_leveling':
            virtual_p=model.G.add(before['position'],geo['virtual_translation_world_m'])
            forward=G.rotate(before['orientation_xyzw'],[1.,0.,0.]);yaw=math.atan2(-forward[2],forward[0])
            flat=dict(x=0.,y=math.sin(.5*yaw),z=0.,w=math.cos(.5*yaw))
            virtual_q=model.G.blend(before['orientation_xyzw'],flat,geo['virtual_level_blend'])
        else:virtual_p=before['position'];virtual_q=before['orientation_xyzw']
        for i in range(4):
            mode='qualified_anchor' if before['qualified_support'][i] else 'weak_anchor' if before['positive_bearing'][i] else 'free_foot'
            predicted=model.G.add(virtual_p,G.rotate(virtual_q,commanded_fk[i]))
            decomposition=G.motion_components(descriptor,before,after,i)
            feet[i].append(dict(mode=mode, qualified_after=after['qualified_support'][i],
                positive_after=after['positive_bearing'][i],
                commanded_fixed_torso_dy_m=G.rotate(before['orientation_xyzw'],model.G.sub(commanded_fk[i],measured_fk[i]))[1],
                virtual_predicted_dy_m=predicted[1]-before['modeled_cap_centers'][i][1],
                impulse_before_ns=before['bearing_impulses'][i],impulse_after_ns=after['bearing_impulses'][i],
                **decomposition))
        commands.append(dict(partial_step=before['partial_step'],mode=plan['mode'],
            qualified_before=before['qualified_support'],qualified_after=after['qualified_support'],
            positive_bearing=before['positive_bearing'],
            selected_virtual_translation_world_m=geo['virtual_translation_world_m'],
            actual_torso_translation_world_m=model.G.sub(after['position'],before['position']),
            virtual_level_blend=geo['virtual_level_blend'],
            joint_limit_failure_after=not after['classification']['joint_limits_respected']))
    assert mapping==[0.]*4800
    joint_summary=[]
    for j,events in enumerate(joint):
        outside=[(a,b,e) for (a,b),e in zip(pairs,events) if e['measured_excess_rad']>0]
        joint_summary.append(dict(joint=samples[0]['joint_ids'][j],command_limit_rad=LIMITS[j],
            measured_limit_failure_samples=len(outside),first_failure_partial_step=outside[0][1]['partial_step'] if outside else None,
            maximum_measured_excess_rad=max(e['measured_excess_rad'] for e in events),
            commands_within_0_005_rad_of_limit=sum(e['command_margin_rad']<=.005 for e in events),
            commands_within_0_02_rad_of_limit=sum(e['command_margin_rad']<=.02 for e in events),
            inward_commands_while_measured_outside=sum(e['inward_command_at_limit'] for e in events),
            opposite_motion_samples=sum(e['opposite_motion'] for e in events),
            cap_fraction_at_least_0_99=sum(e['applied_cap_fraction']>=.99 for e in events),
            statistics={k:G.stats([e[k] for e in events]) for k in ('command_margin_rad','next_target_error_rad','actual_delta_rad','requested_delta_rad','applied_cap_fraction')}))
    foot_summary=[]
    for i,events in enumerate(feet):
        grouped={}
        for name in ('qualified_anchor','weak_anchor','free_foot'):
            selected=[e for e in events if e['mode']==name]
            grouped[name]=dict(commands=len(selected),qualified_next=sum(e['qualified_after'] for e in selected),
                positive_next=sum(e['positive_after'] for e in selected),
                statistics={k:G.stats([e[k] for e in selected]) for k in ('commanded_fixed_torso_dy_m','virtual_predicted_dy_m','actual_world_dy_m','impulse_before_ns','impulse_after_ns')})
        foot_summary.append(dict(foot=G.FEET[i],groups=grouped,
            measured_cap_height_first_m=samples[0]['measured_cap_centers'][i][1],
            measured_cap_height_final_m=samples[-1]['measured_cap_centers'][i][1],
            accumulated_motion_m={k:sum(e[k] for e in events) for k in G.motion_components(descriptor,*pairs[0],i)},
            fk_position_error_m=G.stats([math.dist(r['modeled_cap_centers'][i],r['measured_cap_centers'][i]) for r in samples])))
    paths=[Path(__file__),closed.RECORD,Path(closed.__file__),Path(model.__file__),Path(model.G.__file__),
        Path(G.__file__),Path(closed.streams.__file__),Path(closed.streams.diagnosis.__file__),
        closed.ROOT/'sdk/core/src/recovery.rs',closed.ROOT/'sdk/core/src/recovery_runtime/partial_support_anchored_control.rs']
    return dict(schema_version='sporespore_r10am_support_tracking_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_retained_data',authority_mode='retained_input_offline_diagnosis',question_class='development'),
        bindings=[closed.bind(p) for p in paths],source_report=closed.bind(closed.CHILD/'worker_report.json'),
        original_source_commit=closed.HEAD,original_outcome='valid_development_negative',command_links=600,
        canonical_motor_mapping_errors=0, native_geometry_reconstruction=parity,
        joint_analysis=joint_summary,foot_analysis=foot_summary,commands=commands,
        interpretation='All measurements describe the original consumed trajectory. Positive bearing and qualified support are distinct. '
            'Near-limit targets, measured limit crossings and load imbalance are associations, not proof of a repair. '
            'The virtual torso move is only a geometric proposal; actual motion must be measured separately. '
            'A successor must address support acquisition and tracking without changing acceptance thresholds.', **CLAIMS)


def audit():
    record=closed.read(RECORD)
    for binding in [record['source_report'],*record['bindings']]:assert closed.bind(binding['path'])==binding
    assert record==derive()
    return dict(ok=True,command_links=record['command_links'],native_geometry_reconstruction=record['native_geometry_reconstruction'],
        joint_limit_failures={r['joint']:r['measured_limit_failure_samples'] for r in record['joint_analysis']},**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    if args.create:closed.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))
