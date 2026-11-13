"""Read live handoff sources and replay exact compiled control calls, without physics."""
import argparse
import copy
import json
from pathlib import Path

from audit_live_recovery_energy import (LocomotionCore, audit_rows as energy_rows,
    bound, digest, require, sha, transport_value, vec)
from audit_live_godot import controls_valid, kicks_valid
from showcase_model import StreamIdentity


def replay(core, call):
    require(call['ok'] is True and call['compiled_call_count'] == 1, 'Compiled call missing')
    request, response = transport_value(call['request']), transport_value(call['response'])
    name = call['method']
    require(name in {'recovery_r10ap_partial_entry_control_v1_json', 'recovery_r10ap_partial_step_control_v1_json',
        'recovery_r10r_upright_step_control_v1_json', 'recovery_collect_native_v3_json',
        'recovery_step_v5_json', 'recovery_plan_control_v3_json', 'recovery_plan_stance_control_v4_json'}, 'Unexpected control call')
    actual = getattr(core, name.removesuffix('_json'))(request)
    require(response['ok'] is True and actual == response['value'] == call['value'], 'Exact compiled control replay')
    return request, actual


def audit_bound(core, value):
    bound(core, value)
    require(value['schema_version'] == 'sporespore_live_recovery_bound_observation_v1' and value['ok'] is True, 'Bound observation schema')
    c = value['source_component_receipts']
    epoch, energy, sources = c['epoch_transition'], c['energy_transition'], c['energy_sources']
    for item in (epoch, energy, sources): bound(core, item)
    frame = epoch['state_after']['latest']; step = frame['completed_boundary']['boundary_sequence']
    app = c['application']; two, three = value['observation_v2'], value['observation_v3']
    require(two['schema_version'] == 'sporespore_recovery_observation_v2' and three['schema_version'] == 'sporespore_recovery_observation_v3', 'Observation versions')
    require(three['semantic_step'] == app['semantic_step'] == sources['global_step'] == step and app['source_control_semantic_step'] == step-1, 'Application clock')
    require(app['no_actuation_requested'] is sources['raw']['no_actuation_requested'], 'Motor ownership policy')
    require(three['energy_balance'] == energy['state_after']['ledger'] and value['energy_increment'] == energy['energy_increment'], 'Energy observation join')
    require(energy['state_after']['epoch_state_sha256'] == epoch['state_after']['payload_sha256'] and
        energy['measured_sources_sha256'] == sources['payload_sha256'] and sources['frame_sha256'] == frame['payload_sha256'], 'Energy source join')
    projected = copy.deepcopy(three['energy_balance'])
    projected.update(schema_version='sporespore_recovery_energy_balance_ledger_v2',
        equation_id='current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2',
        component_partition_id='sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2')
    projected.pop('cumulative_signed_discrete_staging_exchange_j')
    require(two['energy_balance'] == projected, 'V2 energy projection')
    base = {k:v for k,v in two.items() if k not in ('schema_version','energy_balance')}
    require(base == {k:v for k,v in three.items() if k not in ('schema_version','energy_balance')}, 'Crossed observation versions')
    binding = value['source_binding']; trace = value['source_trace']
    for key, source in [('source_component_receipts_sha256',c), ('observation_base_sha256',base),
        ('ledger_sha256',two['energy_balance']), ('portable_observation_sha256',two)]:
        require(binding[key] == digest(core,source), 'Observation source digest: '+key)
    require(binding['source_chain_sha256'] == digest(core,{k:v for k,v in binding.items() if k!='source_chain_sha256'}), 'Observation binding chain')
    require(binding['mapping_receipt_sha256'] == energy['payload_sha256'] and trace['source_component_receipts_sha256'] == digest(core,c), 'Mapping provenance')
    require(trace['global_semantic_step'] == step and trace['native_space_step_sequence'] == frame['native_space_step_sequence'] and
        trace['epoch_id'] == epoch['state_after']['epoch_id'] and trace['unobserved_history_claimed'] is False, 'Live trace identity')
    require(three['engine_step_identity']['source_trace_sha256'] == digest(core,trace), 'Engine trace binding')
    applied = three['applied_actuation']
    require(applied['adapter_receipt_sha256'] == digest(core,app) and applied['source_semantic_step'] == step, 'Applied source binding')
    for key in ('command_id','command_sha256','zero_command'): require(applied[key] == app[key], 'Applied command identity')
    require(len(applied['ordered_applied_impulses']) == len(sources['motor_receipts']) == 8, 'Applied motor population')
    for impulse, motor in zip(applied['ordered_applied_impulses'],sources['motor_receipts'],strict=True):
        require(impulse == dict(actuator_id=motor['actuator_id'], applied_angular_impulse_nms=motor['signed_motor_impulse_nms'], host_clamped=False), 'Measured motor impulse projection')
    ownership = dict(owner=app.get('canonical_controller_owner',app['controller_owner']),
        recovery_controller_id=app['recovery_controller_id'], stance_controller_id=app['stance_controller_id'],
        handoff_event_count=app['handoff_event_count'], fallback_controller_active=app['fallback_controller_active'], source_measurement=True)
    require(three['controller_ownership'] == ownership, 'Observation ownership')
    task = c['task_source']
    require(task['ok'] is True and three['task_id'] == task['task_id'] and three['semantics_id'] == task['semantics_id'], 'Task source identity')
    for key in ('r10ap_partial_task_source','r10r_upright_task_source'):
        if key in app:
            tag = app[key]
            require(task['binding_sha256'] == tag['binding_sha256'] == digest(core,{k:v for k,v in tag.items() if k!='binding_sha256'}), 'Task producer binding')
            require(tag['application_sha256'] == digest(core,{k:v for k,v in app.items() if k!=key}), 'Task application binding')
    direct = c['state_source']['direct_state_source_receipt']; contact = c['contact_source']
    require(direct['semantic_step'] == contact['contact_source_receipt']['semantic_step'] == step, 'State/contact clocks')
    require(contact['contact_source_sha256'] == digest(core,contact['contact_source_receipt']) and
        contact['contact_source_receipt']['native_space_step_sequence'] == frame['native_space_step_sequence'], 'Contact source identity')
    require(len(direct['ordered_body_states']) == len(frame['ordered_body_sources']) == 9, 'State body population')
    for measured, raw in zip(direct['ordered_body_states'],frame['ordered_body_sources'],strict=True):
        require(measured['body_id'] == raw['body_id'] and measured['callback_sequence'] == raw['callback_sequence'] == step and
            measured['mass_kg'] == raw['mass_kg'], 'Direct state body identity')
        for key in ('position_world_m','linear_velocity_world_m_s','angular_velocity_world_rad_s'):
            require(vec(measured[key]) == vec(raw[key]), 'Direct body projection')
        x,y,z,w = (measured['orientation_xyzw'][k] for k in ('x','y','z','w'))
        columns = [[1-2*y*y-2*z*z,2*x*y+2*w*z,2*x*z-2*w*y],
            [2*x*y-2*w*z,1-2*x*x-2*z*z,2*y*z+2*w*x], [2*x*z+2*w*y,2*y*z-2*w*x,1-2*x*x-2*y*y]]
        require(abs(x*x+y*y+z*z+w*w-1) <= 1e-6 and all(abs(a-b) <= 1e-6
            for left,right in zip(columns,raw['orientation_basis'],strict=True) for a,b in zip(left,vec(right),strict=True)), 'Body orientation projection')
    torso = direct['ordered_body_states'][0]
    require(three['state']['base_pose_world'] == dict(position_m=torso['position_world_m'],orientation_xyzw=torso['orientation_xyzw']), 'Torso pose source')
    require(three['state']['base_twist_world'] == dict(linear_velocity_m_s=torso['linear_velocity_world_m_s'],angular_velocity_rad_s=torso['angular_velocity_world_rad_s']), 'Torso velocity source')
    for key in ('world_build_count','solver_step_count'): require(value[key] == 0, 'Observation constructed physics')
    for key in ('physics_state_modified','physical_acceptance_authority','release_authority'): require(value[key] is False, 'Observation overclaim')


def audit_transition(core, before, observation, transition):
    bound(core,before); audit_bound(core,observation); bound(core,transition)
    after = transition['state_after']; bound(core,after)
    require(transition['ok'] is True and transition['state_before_sha256'] == before['payload_sha256'] and
        transition['bound_sha256'] == observation['payload_sha256'], 'Controller source join')
    require(before['terminal'] is False and after['last_global_step'] == before['last_global_step']+1 == observation['observation_v3']['semantic_step'], 'Controller clock')
    for key in ('epoch_id','origin_global_step','context_sha256','entry_declaration','prone_context'):
        require(before[key] == after[key], 'Controller declaration changed: '+key)
    calls = [replay(core,call) for call in transition['calls']]
    require(bool(calls), 'Controller did not enter compiled code')
    request, result = calls[0]
    if before['route'] == 'entry':
        require(len(calls) == 1, 'Entry call population')
        passive = request['entry']['original_request']['passive_request']
        require(passive['declaration'] == before['entry_declaration'] and passive.get('native_global_energy') is None and
            passive['observation'] == observation['observation_v3'] and passive['energy_increment'] == observation['energy_increment'], 'Fresh passive request')
        retained = result['original_entry_control']; selected = retained['entry']['memory']['route']
        require(after['selector_memory'] == retained['entry']['memory'] and after['route'] == (selected if selected in ('prone','partial','upright') else 'entry'), 'Entry selection state')
        expected = result['initial_partial_control'] if selected == 'partial' else retained['initial_upright_control'] if selected == 'upright' else None
        require(transition['control'] == expected, 'Selected initial control')
    elif before['route'] in ('partial','upright'):
        step = request['step']
        require(len(calls) == 1 and step['memory'] == before['memory'] and step['declaration'] == before['declaration'] and
            step['observation'] == observation['observation_v3'] and step['energy_increment'] == observation['energy_increment'] and
            step.get('native_global_energy') is None, 'Recovery step source')
        require(after['memory'] == result['step']['memory'] and transition['control'] == result['next_control'], 'Recovery output state')
    else:
        require(len(calls) in (2,3) and calls[1][0]['memory'] == before['memory'] and
            calls[1][0]['observation'] == observation['observation_v3'], 'Prone step sources')
        require(after['memory'] == calls[1][1]['step']['memory'], 'Prone memory')
    require(transition['no_actuation_requested'] is (transition['control'] is None), 'Controller intent')
    return len(calls)


def audit_fixture(core, fixture):
    f = fixture; prone = f['prone']
    epochs = [dict(capture=f['origin'],transition=f['epoch_begin']),
        dict(capture=f['epoch']['state_after']['latest'],transition=f['epoch']),dict(capture=prone['frame'],transition=prone['epoch'])]
    energies = [dict(begin=f['energy_begin']),dict(sources=f['sources'],transition=f['energy']),dict(sources=prone['sources'],transition=prone['energy'])]
    energy = energy_rows(core,epochs,energies)
    total = audit_transition(core,f['controller_begin']['state'],f['bound'],f['controller'])
    total += audit_transition(core,f['controller']['state_after'],prone['bound'],prone['controller'])
    for kind, branch in f['branches'].items():
        require(kind in ('partial','upright') and branch['ok'] is True and len(branch['calls']) == 241, 'Branch fixture population')
        previous = None
        for index, call in enumerate(branch['calls']):
            request, result = replay(core,call); total += 1
            if index < 240:
                entry = request['entry']; passive = entry['original_request']['passive_request']
                selector = result['original_entry_control']['entry']['memory']
                require(passive['observation']['semantic_step'] == 301+index and entry['prior'] == previous and
                    selector['route'] == (kind if index == 239 else 'waiting'), 'Contiguous branch entry')
                require('native_global_energy' not in passive and 'native_global_energy_at_boundary' not in passive['declaration'], 'Invented pre-epoch history')
                previous = selector
            else:
                require(request['step']['memory'] == branch['entry']['state_after']['memory'] and
                    result['step']['memory'] == branch['step']['state_after']['memory'], 'Branch first active step')
    return dict(ok=True,compiled_calls_replayed=total,entry_routes=['prone','partial','upright'],energy=energy,
        source_orientation_matrix_tolerance=1e-6,reader_world_build_count=0,physical_acceptance_authority=False,release_authority=False)


def controls(core, fixture):
    positive = audit_fixture(core,fixture)
    refused = 0
    for mutate in [lambda x:x['controller_begin']['state'].__setitem__('last_global_step',0),
        lambda x:x['bound']['observation_v3']['state']['base_pose_world']['position_m'].__setitem__('y',1),
        lambda x:x['bound']['source_component_receipts']['application'].__setitem__('source_control_semantic_step',0),
        lambda x:x['controller']['calls'][0]['response'].__setitem__('utf8_text','{}'),
        lambda x:x['branches']['partial']['calls'].pop(),lambda x:x['branches']['upright']['calls'].reverse()]:
        changed = copy.deepcopy(fixture); mutate(changed)
        def reseal(value):
            if isinstance(value,dict):
                for child in value.values(): reseal(child)
                if 'payload_sha256' in value: value['payload_sha256']=digest(core,value)
            elif isinstance(value,list):
                for child in value: reseal(child)
        reseal(changed)
        try: audit_fixture(core,changed)
        except (ValueError,KeyError,TypeError): refused += 1
        else: raise ValueError('Handoff reader accepted a corruption control')
    return dict(ok=True,positive=positive,negative_controls_refused=refused)


def audit_native(core, folder, physical, declaration):
    """Require the whole declared episode; a partial route remains a failure."""
    directory = (folder/'physical').resolve()
    stream = directory/'stream.jsonl'
    require(sha(stream) == physical['stream_sha256'], 'Native stream binding')
    rows = [json.loads(line) for line in stream.read_text().splitlines()]
    guard = StreamIdentity(rows[0]['session_id'],'godot_jolt',rows[0]['source_commit'],False)
    frames = []; kicks = []
    for row in rows:
        kind = guard.accept(row)
        if kind == 'frame':
            require(row['frame_index'] == len(frames)+1 and len(row['ordered_bodies']) == 9, 'Native frame population')
            require(abs(row['simulation_time_s']-row['frame_index']/120) < 1e-10, 'Native simulation clock')
            for body in row['ordered_bodies']: vec(body['position_m'])
            frames.append(row); kicks.extend(row['applied_impulses'])
    require(rows[-1] == physical['completed'] and rows[-1]['ok'] is True and len(frames) == declaration['maximum_outer_steps'], 'Native terminal outcome')
    summary = rows[-1]['summary']; live = summary['live_handoff']; walking = summary['studio_live_walking']
    require(live['episodes'] == 1 and live['mode'] == 'walking_resume' and live['resume_commands'] >= 120, 'Full recovery and one-second resume required')
    def reopen(binding):
        path=Path(binding['path']).resolve()
        require(path.is_relative_to(directory) and sha(path)==binding['sha256'], 'Retained artifact binding')
        return json.loads(path.read_text())
    retained = reopen(live['retained']); transitions = retained['transitions']
    beginnings = [r for r in transitions if r['kind']=='begin']; steps = [r for r in transitions if r['kind']=='recovery_step']
    require(len(beginnings)==1 and len(steps)>0 and len(transitions)==len(steps)+1, 'Native handoff transition population')
    origin = beginnings[0]; start = origin['global_step']
    require(origin['trigger']['state_after']['triggered'] is True and origin['walking_completion']['ok'] is True and
        origin['walking_completion']['adapter_shutdown_receipt']['ok'] is True and origin['motor_disable']['ok'] is True and
        origin['motor_disable']['motor_enabled'] is False, 'Exclusive motor handoff')
    detector = {}; detected = []
    for sample in retained['fall_samples']:
        raw = sample['sample']; g = raw['global_step']; up = vec(raw['torso_up_world'])
        require(sample['ok'] is True and raw['callback_sequence']==g and raw['source_measurement'] is True, 'Fall source clock')
        if detector and g != detector['last_global_step']+1:
            require(detector['triggered'] is True and g == live['resume_completed_step']+1, 'Fall observer gap')
            detector={}
        abnormal=up[1] < declaration['live_handoff']['fall_up_dot_min'] or raw['torso_nonfoot_contact']
        count=detector.get('consecutive',0)+1 if abnormal else 0
        expected=dict(last_global_step=g,consecutive=count,triggered=count==3)
        require(sample['state_after']==expected and sample['abnormal']==abnormal, 'Fall hysteresis reconstruction')
        detector=expected
        if expected['triggered']: detected.append(g)
    require(detected==[start], 'Declared fall trigger')
    epochs=[dict(capture=origin['capture'],transition=origin['epoch'])]+[dict(capture=r['capture'],transition=r['epoch']) for r in steps]
    energies=[dict(begin=origin['energy'])]+[dict(sources=r['sources'],transition=r['energy']) for r in steps]
    energy=energy_rows(core,epochs,energies,start=start,expected_count=len(epochs))
    previous=origin['controller']['state']; application=origin['application']; calls=0
    for index, row in enumerate(steps,1):
        require(row['global_step']==start+index and row['application']==application, 'Recovery application continuity')
        c=row['bound']['source_component_receipts']
        for name,key in [('epoch','epoch_transition'),('energy','energy_transition'),('sources','energy_sources'),('application','application')]:
            require(c[key]==row[name], 'Recovery collector source join')
        calls += audit_transition(core,previous,row['bound'],row['controller'])
        previous=row['controller']['state_after']
        if index < len(steps): application=row['next_application']
    require(previous['terminal'] is True and previous['terminal_phase']=='complete', 'Measured recovery completion')
    resume=steps[-1]['resume']; resume_at=live['resume_completed_step']
    require(resume['ok'] is True and resume_at==steps[-1]['global_step']==resume['global_step'], 'Walking resume clock')
    require(resume['same_body']['body_population_instance_sha256']==resume['previous_body_identity']['body_population_instance_sha256'], 'Body replacement during resume')
    for receipt in (resume['start'],resume['handoff']):
        require(receipt['ok'] is True and receipt['body_transform_write_count']==receipt['body_velocity_write_count']==receipt['solver_reset_count']==0, 'Walking restart changed native body state')
    controls=reopen(walking['controller_rows'])
    prefix=[r for r in controls if r['segment']=='walking_prefix']; resumed=[r for r in controls if r['segment']=='walking_resume']
    require(len(controls)==len(prefix)+len(resumed), 'Walking control segments')
    require(live['prefix_commands']==start-walking['handoff_completed_step'] and live['resume_commands']==len(frames)-resume_at, 'Walking segment counts')
    controls_valid(prefix,walking['handoff_completed_step'],live['prefix_commands'])
    controls_valid(resumed,resume_at,live['resume_commands'],first_local=1)
    require(summary['walking_shutdown']['ok'] is True and physical['applied_impulses']==kicks==walking['impulses'], 'Walking shutdown or impulse join')
    kicks_valid(physical['sent_impulses'],kicks)
    return dict(ok=True,native_worlds=1,native_steps=len(frames),fall_at=start,recovery_steps=len(steps),
        recovery_route=previous['route'],resumed_walking_steps=len(resumed),compiled_control_calls_replayed=calls,
        energy=energy,same_body_resume_verified=True,reader_world_build_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture',type=Path); parser.add_argument('--core',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(controls(LocomotionCore(args.core),json.loads(args.fixture.read_text()))))
