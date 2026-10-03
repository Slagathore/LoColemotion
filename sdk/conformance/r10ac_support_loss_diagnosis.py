"""Describe support loss after loaded commands in consumed R10AA/R10AB reports.

Offline observed-transition analysis only. Reconstructed endpoints are a rigid
kinematic model, not measured contact positions or a counterfactual simulation.
No controller, task grade, physical population or execution authority is changed.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import statistics
import uuid
import r10aa_first_support_closure as aa
import r10ab_first_support_closure as ab
from r10ab_loaded_rise_diagnosis import Model as Geometry

ROOT, EVIDENCE = ab.ROOT, ab.EVIDENCE
LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')
SOURCES = [('r10aa', aa, 'loaded_geometry_rise'), ('r10ab', ab, 'loaded_downward_rise')]


def binding(path):
    path = Path(path)
    with path.open('rb') as stream: digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256='sha256:'+digest)


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def distribution(values):
    return dict(n=len(values), minimum=min(values), median=statistics.median(values), maximum=max(values)) if values else dict(n=0)


def extract(module):
    path = module.CHILD/'worker_report.json'
    source = binding(path)
    assert source['raw_sha256'] == module.REPORT_SHA
    rows, descriptor = [], None
    for kind, packet in module.partial_records(path):
        if kind != 'packet': continue
        assert packet['ok'] is True
        request = json.loads(packet['call']['request']['utf8_text'])
        observed = request['step']['observation']
        current = request['collection']['descriptor']
        if descriptor is None: descriptor = current
        assert current == descriptor
        assert observed == packet['bound_observations']['observation_v3']
        rows.append(dict(observation=observed, plan=packet['native_receipt']['next_load_plan'],
            classification=packet['native_receipt']['step']['classification'],
            application=packet['source_application'], partial_step=packet['native_receipt']['step']['memory']['total_steps_observed']))
    assert len(rows) == 646 and binding(path) == source
    return source, descriptor, rows


def analyze(descriptor, rows, loaded_mode):
    transitions = []
    for i, row in enumerate(rows[:-1]):
        if not row['plan'] or row['plan']['mode'] != loaded_mode: continue
        nxt = rows[i+1]
        before, after = row['observation'], nxt['observation']
        assert after['semantic_step'] == before['semantic_step']+1
        assert after['state']['sample_time_s'] > before['state']['sample_time_s']
        gb, ga = Geometry(before,descriptor), Geometry(after,descriptor)
        targets = row['plan']['ordered_target_positions_rad']
        intents = nxt['application']['ordered_intents']
        assert len(intents) == len(targets) == 8
        bclear = {r['body_id']:r for r in before['ordered_body_clearance_observations']}
        aclear = {r['body_id']:r for r in after['ordered_body_clearance_observations']}
        feet = []
        for j, limb in enumerate(LIMBS):
            bc, ac = [o['state']['ordered_contact_observations'][j] for o in (before,after)]
            bb, ba = [o['ordered_foot_bearing_observations'][j] for o in (before,after)]
            body = limb+'_distal'
            feet.append(dict(limb=limb, before_presence=bc['presence'], after_presence=ac['presence'],
                before_bears_support=bc['bears_support'], after_bears_support=ac['bears_support'],
                before_foot_impulse_ns=bb['bearing_normal_impulse_ns'], after_foot_impulse_ns=ba['bearing_normal_impulse_ns'],
                before_nonfoot_distal=bclear[body], after_nonfoot_distal=aclear[body],
                before_contact_provenance=bc['provenance'], after_contact_provenance=ac['provenance'],
                planned_endpoint_delta_y_m=gb.foot(j,targets)[1]-gb.feet[j][1],
                realized_model_joint_only_delta_y_m=gb.foot(j,ga.measured)[1]-gb.feet[j][1],
                realized_model_pose_only_delta_y_m=ga.foot(j,gb.measured)[1]-gb.feet[j][1],
                realized_model_total_delta_y_m=ga.feet[j][1]-gb.feet[j][1]))
        transitions.append(dict(partial_step=row['partial_step'],semantic_step=before['semantic_step'],
            before_support_gate=row['classification']['distal_support_gate'],after_support_gate=nxt['classification']['distal_support_gate'],
            before_com_y=before['center_of_mass']['position_world_m']['y'],after_com_y=after['center_of_mass']['position_world_m']['y'],
            before_joint_positions=gb.measured,after_joint_positions=ga.measured,
            before_joint_velocities=[j['velocity_rad_s'] for j in before['state']['ordered_joint_observations']],
            after_joint_velocities=[j['velocity_rad_s'] for j in after['state']['ordered_joint_observations']],
            planned_joint_positions=targets, applied_canonical_velocities=[x['canonical_target_velocity_rad_s'] for x in intents],
            applied_joint_impulses=after['applied_actuation']['ordered_applied_impulses'],feet=feet))
    summary=[]
    for j,limb in enumerate(LIMBS):
        fs=[t['feet'][j] for t in transitions]
        lost=[f for f in fs if not f['after_bears_support']]
        summary.append(dict(limb=limb, loaded_transitions=len(fs), loses_bearing=len(lost),
            absent_after=sum(not f['after_presence'] for f in fs),
            zero_foot_impulse_after=sum(f['after_foot_impulse_ns']==0 for f in fs),
            nonfoot_distal_contact_after=sum(f['after_nonfoot_distal']['nonfoot_contact_present'] for f in fs),
            lost_foot_but_nonfoot_distal_loaded=sum(f['after_nonfoot_distal']['accumulated_nonfoot_normal_impulse_ns']>0 for f in lost),
            after_foot_impulse_ns=distribution([f['after_foot_impulse_ns'] for f in fs]),
            after_nonfoot_distal_impulse_ns=distribution([f['after_nonfoot_distal']['accumulated_nonfoot_normal_impulse_ns'] for f in fs]),
            planned_down=sum(f['planned_endpoint_delta_y_m'] < -1e-9 for f in fs),
            realized_joint_only_up=sum(f['realized_model_joint_only_delta_y_m']>1e-6 for f in fs),
            realized_total_up=sum(f['realized_model_total_delta_y_m']>1e-6 for f in fs),
            modeled_endpoint_change=distribution([f['realized_model_total_delta_y_m'] for f in fs]),
            after_contact_quality=dict(Counter(f['after_contact_provenance']['quality'] for f in fs))))
    return dict(loaded_transitions=len(transitions), support_lost_next_step=sum(not t['after_support_gate'] for t in transitions),
        feet=summary, transitions=transitions)


def run():
    out=EVIDENCE/('r10ac-support-loss-diagnosis-'+uuid.uuid4().hex)
    out.mkdir()
    result=dict(schema_version='sporespore_r10ac_support_loss_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='offline_consumed_report_transition_analysis',question_class='development'),
        sources={}, analyses={}, modeled_endpoints_are_not_measured_contact_positions=True,
        original_results_regraded=False, comparative_authority=False, causal_mechanism_proven=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    for label,module,mode in SOURCES:
        source,descriptor,rows=extract(module)
        value=analyze(descriptor,rows,mode)
        assert value['loaded_transitions']==(44 if label=='r10aa' else 34)
        write(out/(label+'-transitions.json'),value.pop('transitions'))
        result['sources'][label]=dict(report=source,closure=binding(module.RECORD),transition_artifact=binding(out/(label+'-transitions.json')))
        result['analyses'][label]=value
        print(label+' '+json.dumps(value),flush=True)
    result['analysis_source']=binding(Path(__file__))
    result['geometry_source']=binding(ROOT/'sdk/conformance/r10ab_loaded_rise_diagnosis.py')
    write(out/'result.json',result)
    print('R10AC_SUPPORT_LOSS_ROOT '+str(out),flush=True)
    return out


if __name__=='__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    run()
