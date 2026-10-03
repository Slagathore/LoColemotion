"""V42 stance-reference latch sketch on every original V41 input.

Reference memory and four latch bits may change; saved body state, contacts,
gait clocks and waves never do. This is not a native or physical rollout.
"""
import argparse
import json
import math
from pathlib import Path

import development_recovery_v41_contact_loss_diagnosis as data

pre = data.precheck
require, digest = data.require, data.digest
ANALYSIS_PATHS = (*data.ANALYSIS_PATHS,
    'sdk/conformance/development_recovery_stance_latch_precheck.py',
    'tests/test_development_stance_latch_precheck.py')


def select(active, phase, presence, bearing, previous_active, previous_phase, latched):
    """No contact smoothing: latch the reference CHOICE, never contact truth."""
    require(all(type(v) is bool for v in (active,presence,bearing,previous_active,latched))
            and not (bearing and not presence), 'STANCE_LATCH_BOOLEAN_DOMAIN')
    require(type(phase) in (int,float) and math.isfinite(phase)
            and phase==int(phase) and 0<=phase<360, 'STANCE_LATCH_PHASE_DOMAIN')
    require(previous_phase is None or (type(previous_phase) in (int,float)
            and math.isfinite(previous_phase) and previous_phase==int(previous_phase)
            and 0<=previous_phase<360), 'STANCE_LATCH_PREVIOUS_PHASE_DOMAIN')
    require(not previous_active or previous_phase is not None, 'STANCE_LATCH_PREVIOUS_WAVE_REQUIRED')
    carry = latched and previous_active and previous_phase>72 and phase>=previous_phase
    return active and phase>72 and (carry or (presence and bearing))


def command(entry, references, dimensions, mask):
    """Same V41 algebra and caps; only the explicit goal-selection mask differs."""
    pose,wave=pre.cold.algebra.inputs(entry)
    support=entry['native_output']['actuation']['receipt']['recovery_support_plane']
    prior=support['wave_velocity']['previous_wave']
    active=prior is not None and prior['active'] and wave['active']
    goals=pre.goals(pose,wave,dimensions,mask)[0]
    comparison_goals=pre.goals(pose,pre.snapshot(prior),dimensions,mask)[0] if active else goals
    dt=support['reference_step_duration_s']
    original=entry['native_output']['actuation']['ordered_commands']
    caps=[c['maximum_target_speed_rad_s'] for c in original]
    target=pre.cold.algebra.bounded_targets(goals,references,caps,dt)
    comparison=pre.cold.algebra.bounded_targets(comparison_goals,references,caps,dt) if active else target
    motors=[]
    for i,c in enumerate(original):
        joint=entry['request']['state']['ordered_joint_observations'][i]
        contact=entry['request']['state']['ordered_contact_observations'][i//2]
        absent=not contact['presence'] and not contact['bears_support'];cap=caps[i]
        numerator=target[i]-references[i] if absent else target[i]-comparison[i]
        rate=pre.cold.algebra.clamp(numerator/dt,-cap,cap) if active and dt>0 else 0.
        raw=8*(target[i]-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
        velocity=-pre.cold.algebra.clamp(raw,-cap,cap)
        bound=(-.72,.72) if i%2==0 else (0.,1.1)
        require(bound[0]<=goals[i]<=bound[1] and bound[0]<=target[i]<=bound[1]
                and abs(target[i]-references[i])<=cap*dt+1e-14 and abs(velocity)<=cap, 'STANCE_LATCH_BOUNDS')
        motors.append(dict(goal_rad=goals[i],target_rad=target[i],reference_rate_rad_s=rate,
            host_motor_velocity_rad_s=velocity,saturated=abs(raw)>cap))
    return dict(targets_rad=target,motors=motors)


def summarize(report):
    # This validates every original command before doing substitutions.
    original=data.summarize(report)
    d=report['configuration']['base_descriptor'];upper=.35*d['upper_length_fraction']
    dims=(upper,.35-upper,.04*d['foot_radius_scale'],d['hip_span_scale'])
    latch=[False]*4; last=None; chain=None; timeline=[]
    baseline_error=0.; unselected_error=0.
    for entry in report['development_walking_entry']['rows']:
        support=entry['native_output']['actuation']['receipt']['recovery_support_plane']
        wave=support['wave_velocity']['current_wave'];prior=support['wave_velocity']['previous_wave']
        contacts=entry['request']['state']['ordered_contact_observations']
        mask=[select(wave['active'],w['scheduled_phase_step'],c['presence'],c['bears_support'],
            prior['active'] if prior is not None else False,
            prior['ordered_limbs'][i]['scheduled_phase_step'] if prior is not None else None,latch[i])
            for i,(w,c) in enumerate(zip(wave['ordered_limbs'],contacts))]
        native_mask=[r['upright_reference_selected'] for r in support['upright_stance']['ordered_limbs']]
        references=entry['request']['memory']['support_reference']['ordered_target_positions_rad']
        baseline=command(entry,references,dims,native_mask)
        one=command(entry,references,dims,mask)
        chained=command(entry,references if chain is None else chain,dims,mask)
        for i,(a,b) in enumerate(zip(baseline['motors'],entry['native_output']['actuation']['ordered_commands'])):
            baseline_error=max(baseline_error,abs(a['host_motor_velocity_rad_s']-b['target_velocity_rad_s']))
            require(abs(a['host_motor_velocity_rad_s']-b['target_velocity_rad_s'])<1e-10
                    and abs(a['target_rad']-b['requested_target_position_rad'])<1e-12
                    and a['saturated']==b['velocity_saturated'], 'STANCE_LATCH_ORIGINAL_RECONSTRUCTION')
            if mask[i//2]==native_mask[i//2]:
                unselected_error=max(unselected_error,abs(a['host_motor_velocity_rad_s']-one['motors'][i]['host_motor_velocity_rad_s']))
        timeline.append(dict(command_local=entry['session_local_step'],original_mask=native_mask,
            proposed_mask=mask,previous_latch=latch,
            selector_changes=0 if last is None else sum(a!=b for a,b in zip(last,mask)),
            baseline=baseline,one_command_substitution=one,chained_reference_memory=chained))
        latch=mask;last=mask;chain=chained['targets_rad']
    def counts(name):
        return dict(saturated_joint_commands=sum(m['saturated'] for r in timeline for m in r[name]['motors']),
            changed_joint_commands=sum(abs(a['host_motor_velocity_rad_s']-b['host_motor_velocity_rad_s'])>1e-10
                for r in timeline for a,b in zip(r['baseline']['motors'],r[name]['motors'])))
    return dict(command_count=len(timeline),joint_command_count=8*len(timeline),
        original_walking_evaluation=original['original_walking_evaluation'],
        original_selector_transitions=original['selector_limb_transition_count'],
        proposed_selector_transitions=sum(r['selector_changes'] for r in timeline),
        proposed_selected_limb_inputs=sum(sum(r['proposed_mask']) for r in timeline),
        additional_selected_limb_inputs=sum(a and not b for r in timeline for a,b in zip(r['proposed_mask'],r['original_mask'])),
        original=counts('baseline'),one_command_substitution=counts('one_command_substitution'),
        chained_reference_memory=counts('chained_reference_memory'),
        baseline_motor_reconstruction_maximum_error_rad_s=baseline_error,
        identical_mask_same_memory_motor_maximum_error_rad_s=unselected_error,
        all_reference_slew_and_joint_and_motor_bounds_preserved=True,
        all_command_comparisons=timeline)


def observe():
    path=data.ROOT/'sdk/development/recovery_attempts'/(data.ATTEMPT+'.json');raw=path.read_bytes()
    require(digest(raw)==data.CLOSURE_SHA,'STANCE_LATCH_CLOSURE_DRIFT')
    closure=json.loads(raw);identity=closure['kicked_report'];report_raw=Path(identity['path']).read_bytes()
    require(digest(report_raw)==identity['raw_sha256']==data.REPORT_SHA
            and len(report_raw)==identity['byte_length'],'STANCE_LATCH_REPORT_DRIFT')
    return dict(schema_version='sporespore_development_stance_latch_precheck_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_retained_inputs',authority_mode='non_native_controller_precheck',question_class='development'),
        source_closure=dict(path=path.relative_to(data.ROOT).as_posix(),raw_sha256=digest(raw)),source_report=identity,
        analysis_sources=[dict(path=p,raw_sha256=digest((data.ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        observation=summarize(json.loads(report_raw)),
        proposal_rule='Latch each upright reference choice after actual supporting contact during active phase 73..359. Clear on inactive wave or phase 0..72; never carry across a phase wrap or absent/inactive previous wave. Current explicit supporting contact may establish a fresh latch. Keep the same current mask in both wave comparisons. Keep actual contact truth and V41 contact-selected reference rates unchanged.',
        limits='Original V41 body, contact and wave inputs remain fixed. One-command substitution uses original reference memory; chained arithmetic carries proposed reference positions and four latch bits, not a simulated body or modified upstream gait. Fewer selector changes do not establish better anchoring, recontact, relocation or recovery. Retaining the upright reference after contact loss may delay or prevent recontact. Speed clipping and all original failures remain; no new physics or force-aware recovery.',
        native_component_implemented=False,route_integrated=False,physical_attempt_selected=False,
        original_evaluation_changed=False,physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def compact(full,output):
    raw=output.read_bytes()
    return dict(full,observation={k:v for k,v in full['observation'].items() if k!='all_command_comparisons'},
        complete_precheck=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=digest(raw)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    require(output.is_relative_to(data.EVIDENCE.resolve()),'STANCE_LATCH_DURABLE_OUTPUT_REQUIRED')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
