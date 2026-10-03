"""Retained multi-step fixtures for the diagnostic reader and capture linkage."""
import argparse
import copy
import json
from pathlib import Path

import r10ac_development as identity
import r10ac_development_identity_check as identity_check
import r10ac_contact_frame_replay as capture
import r10ac_contact_frame_report as reader

SOURCE = identity.EVIDENCE / 'r10ac-capture-check-6025ba78de6f44de9b2e8218b3caacce/fixtures.json'


def make_report(declaration, indices):
    base = json.loads(SOURCE.read_text())['fixtures']
    report = copy.deepcopy(identity_check.fixture()['expected_report'])
    report.update(arm_id=identity.ROLE, source_commit=declaration['source_snapshot']['head'],
        child_attempt_id=declaration['children'][0]['child_attempt_id'], parent_attempt_id=declaration['attempt_id'],
        r10ac_development=copy.deepcopy(declaration['r10ac_development']), solver_step_count=len(indices))
    model, population = 'r10ac-synthetic-no-world', 'sha256:'+'a'*64
    arm = dict(model_instance_id=model, body_population_instance_sha256=population, trace_rows=[])
    records, links = [], []
    for step, index in enumerate(indices,1):
        packet = copy.deepcopy(base[index]['packet'])
        packet['semantic_step'] = step
        for key in ('direct_state_source','contact_source_receipt','source_component_binding'):
            packet[key]['semantic_step'] = step
        packet['contact_source_receipt']['native_space_step_sequence'] = step+10
        for body in packet['callback_bodies']+packet['direct_state_source']['ordered_body_states']:
            body['callback_sequence'] = step
        for key in ('capture_space_step_sequence','read_space_step_sequence'):
            packet['native_snapshot'][key] = step+10
        component = packet['source_component_binding']
        component['direct_state_source_sha256'] = capture.sha(packet['direct_state_source'])
        component['contact_source_sha256'] = capture.sha(packet['contact_source_receipt'])
        source = dict(schema_version='sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_source_trace_v1',
            semantic_step=step, direct_state_callback_sequence=step, native_space_step_sequence=step+10,
            host_step_before=step-1, host_step_after=step, source_measurement=True,
            direct_state_source_sha256=component['direct_state_source_sha256'],contact_source_sha256=component['contact_source_sha256'])
        observation = dict(engine_step_identity=dict(schema_version='sporespore_recovery_engine_step_identity_v1',
            semantic_step=step, host_step_before=step-1,host_step_after=step,native_solver_substep_count=1,
            post_step_observation=True, source_trace_sha256=capture.sha(source)))
        arm['trace_rows'].append(dict(arm_id=identity.ROLE, global_semantic_step=step,
            body_population_instance_sha256=population, observation_sha256=capture.sha(observation)))
        links.append(dict(ok=True, semantic_step=step, source_trace=source, global_observation=observation))
        records.append(dict(ok=True,packet=packet,packet_sha256=capture.sha(packet),
            replay=capture.replay(packet,step,model,population),controller_observation_changed=False,
            world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))
    report['retained_arm'] = arm
    report['r10ac_contact_frames'] = dict(schema_version='sporespore_r10ac_contact_frame_retention_v1',
        records=records,record_count=len(records),controller_observation_changed=False,
        physical_acceptance_authority=False,release_authority=False)
    report['r10ac_contact_frame_links'] = dict(schema_version='sporespore_r10ac_contact_frame_observation_links_v1',
        records=links,record_count=len(links),controller_observation_changed=False,
        physical_acceptance_authority=False,release_authority=False)
    return report


def fixtures():
    identity_check.check_declarations()
    assert identity.sha(SOURCE) == 'sha256:3888a35569cc2fac500f83c48d2893ef428540c19d8e9a839e2ca107361946e3'
    declaration = identity_check.fixture()['cases'][0]['declaration']
    report = make_report(declaration,[0,1,2,3])
    positives = [dict(name='four_steps_all_fixtures',report=report),
        dict(name='complete_empty_contacts',report=make_report(declaration,[3])),
        dict(name='single_boundary_change',report=make_report(declaration,[0]))]
    for row in positives: row['expected'] = reader.replay_report(row['report'],declaration)
    cases=[]
    def change(name,path,value):
        bad=copy.deepcopy(report); at=bad
        for key in path[:-1]: at=at[key]
        at[path[-1]]=value
        cases.append(dict(name=name,report=bad))
    change('wrong_campaign',['r10ac_development','stage'],'first_support_diagnostic')
    change('wrong_child',['child_attempt_id'],declaration['attempt_id'])
    change('held_out_claim',['held_out'],True)
    change('zero_steps',['solver_step_count'],0)
    change('too_many_steps',['solver_step_count'],3753)
    change('numeric_step_bool',['solver_step_count'],True)
    for root in ('r10ac_contact_frames','r10ac_contact_frame_links'):
        change(root+'_missing',[root],{})
        change(root+'_schema',[root,'schema_version'],'crossed')
        change(root+'_count',[root,'record_count'],3)
        change(root+'_truncated',[root,'records'],report[root]['records'][:-1])
        change(root+'_duplicate',[root,'records'],[report[root]['records'][0]]*4)
        change(root+'_reordered',[root,'records'],list(reversed(report[root]['records'])))
        for key in ('physical_acceptance_authority','release_authority','controller_observation_changed'):
            change(root+'_'+key,[root,key],True)
    change('trace_truncated',['retained_arm','trace_rows'],report['retained_arm']['trace_rows'][:-1])
    change('model_crossed',['retained_arm','model_instance_id'],'another-model')
    change('population_crossed',['retained_arm','body_population_instance_sha256'],'sha256:'+'b'*64)
    for key,value in [('arm_id','another-child'),('global_semantic_step',3),('observation_sha256','sha256:'+'0'*64)]:
        change('trace_'+key,['retained_arm','trace_rows',1,key],value)
    for key,value in [('ok',False),('packet_sha256','sha256:'+'0'*64),('controller_observation_changed',True),('world_build_count',1)]:
        change('capture_'+key,['r10ac_contact_frames','records',1,key],value)
    change('forged_replay',['r10ac_contact_frames','records',0,'replay','matched_source_contacts'],0)
    change('link_failed',['r10ac_contact_frame_links','records',0,'ok'],False)
    change('stale_packet',['r10ac_contact_frames','records',1,'packet','semantic_step'],1)
    change('source_hash',['r10ac_contact_frame_links','records',1,'source_trace','contact_source_sha256'],'sha256:'+'0'*64)
    # Repair the observation hash around a crossed source. The independent
    # packet-to-original-source check must still reject the otherwise valid chain.
    bad=copy.deepcopy(report)
    link=bad['r10ac_contact_frame_links']['records'][1]
    link['source_trace']['contact_source_sha256']='sha256:'+'b'*64
    link['global_observation']['engine_step_identity']['source_trace_sha256']=capture.sha(link['source_trace'])
    bad['retained_arm']['trace_rows'][1]['observation_sha256']=capture.sha(link['global_observation'])
    cases.append(dict(name='internally_rehashed_crossed_source',report=bad))
    # Body replacement with a valid packet and recalculated packet replay.
    bad=copy.deepcopy(report); record=bad['r10ac_contact_frames']['records'][1]; packet=record['packet']
    old=packet['callback_bodies'][0]['instance_id']; new=old+10000
    packet['callback_bodies'][0]['instance_id']=new
    for point in packet['native_snapshot']['points']:
        for side in ('1','2'):
            if point['body'+side+'_instance_id']==old: point['body'+side+'_instance_id']=new
    record['packet_sha256']=capture.sha(packet)
    record['replay']=capture.replay(packet,2,bad['retained_arm']['model_instance_id'],bad['retained_arm']['body_population_instance_sha256'])
    cases.append(dict(name='internally_valid_body_replacement',report=bad))
    for row in cases:
        try: reader.replay_report(row['report'],declaration)
        except (ValueError,KeyError,TypeError,IndexError,OverflowError) as error: row['python_refusal']=str(error)
        else: raise AssertionError('Mutation admitted: '+row['name'])
    return dict(declaration=declaration,positives=positives,negatives=cases,
        scope='Synthetic diagnostic sidecar and hash-chain fixtures; these are not complete valid controller reports or physical observations.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare',type=Path)
    parser.add_argument('--verify',type=Path)
    args=parser.parse_args()
    if args.prepare:
        result=fixtures()
        with args.prepare.open('x',encoding='utf-8',newline='\n') as stream:
            json.dump(result,stream,indent=2);stream.write('\n')
        print(json.dumps(dict(positive_cases=len(result['positives']),negative_cases=len(result['negatives']))))
    elif args.verify:
        value=json.loads(args.verify.read_text(encoding='utf-8-sig'))
        assert value['ok'] is True and all(value['checks'].values())
        fixture=json.loads((args.verify.parent/'fixture.json').read_text())
        for row in fixture['positives']:
            assert value['replays'][row['name']]==reader.replay_report(row['report'],fixture['declaration'])==row['expected']
        assert set(value['refusals'])=={row['name'] for row in fixture['negatives']}
        assert all(row.get('ok') is False for row in value['refusals'].values())
        print(json.dumps(dict(ok=True,positive_cases=len(fixture['positives']),negative_cases=len(fixture['negatives']),
            world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)))
    else: parser.error('--prepare or --verify required')
