"""Audit R10AB segment reader, native route bindings and upright worker coverage.

--run performs pure native replays and requires the operation lock. This record
is explicitly incomplete for full report, launcher and smoke qualification.
"""
import argparse
import json
from pathlib import Path
import uuid
import r10ab_worker_component as worker
native=worker.native
ROOT,EVIDENCE=worker.ROOT,worker.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10ab_route_component_v1.json'
READER=EVIDENCE/'r10ab-segment-reader-192ceda2183144c48f143a7dabdec5c9'
POLICIES=EVIDENCE/'r10ab-route-bindings-ac3c193baa5042bbace357926aacefc9'
UPRIGHT=EVIDENCE/'r10ab-upright-worker-eafebc7829de4376a579575ce130c620'
WRAPPERS=[EVIDENCE/'r10ab-route-check-22d651fab5124099bb493f165907bd3b']
AUDIT_WRAPPER=EVIDENCE/'r10ab-route-native-check-8d3166e59e894653ae6363f7c0b1eff5'
PATHS=[
 'sdk/adapters/godot/gdscript/r10ab_recovery_replay_v1.gd',
 'sdk/adapters/godot/gdscript/r10ab_recovery_route_v1.gd',
 'sdk/adapters/godot/gdscript/r10ab_route_worker_v1.gd',
 'sdk/adapters/godot/gdscript/recovery_stance_entry_route_v1.gd',
 'tests/test_development_r10ab_segment_reader.gd','tests/test_development_r10ab_segment_reader.py',
 'tests/test_development_r10ab_route_bindings.gd','tests/test_development_r10ab_route_bindings.py',
 'tests/test_development_r10ab_upright_worker.gd','tests/test_development_r10ab_upright_worker.py',
 'tests/test_development_r10v_worker_hooks.gd','sdk/conformance/r10ab_route_component.py']
CONTRACTS=['r10ab_joint_pose_entry_policy_contract_v1.json','r10ab_v50_hold_policy_contract_v1.json',
 'r10ab_v50_post_recovery_hold_policy_contract_v1.json','r10ab_v56_walking_route_contract_v1.json',
 'r10ab_v56_walking_start_contract_v1.json','r10ab_partial_downward_rise_finite_cycle_contract_v1.json']
PATHS += ['sdk/recovery/'+name for name in CONTRACTS]
PATHS += ['sdk/recovery/r10ab_partial_downward_rise_development_design_v1.json']
UNCHANGED=['limits','finite_walking_observable','settled_tail','whole_walking_envelope','partial_recovery',
 'prone_recovery','upright_recovery','native_interaction','post_recovery_hold']

def observations():
    assert worker.audit()['ok']
    values={}
    for folder,name,count in [(READER,'partial-segment',13),(POLICIES,'policy-bindings',28),(UPRIGHT,'upright-worker',21)]:
        assert native.read(folder/'source_before.json') == native.read(folder/'source_after.json')
        assert native.read(folder/(name+'.execution.json'))['exit_code'] == 0
        assert (folder/(name+'.stderr.log')).read_bytes() == b''
        value=native.read(folder/(name+'.json'))
        assert value['ok'] is True and len(value['checks']) == count and all(v is True for v in value['checks'].values())
        assert value['world_build_count'] == value['solver_step_count'] == 0
        assert value['physical_acceptance_authority'] is value['release_authority'] is False
        values[name]=value
    replay=values['partial-segment']['replay']
    assert (replay['transition_count'],replay['entry_observation_count'],replay['partial_observation_count']) == (303,240,63)
    assert replay['complete_route_proven'] is False and values['partial-segment']['full_report_checked'] is False
    upright=values['upright-worker']
    assert (len(upright['entry_packets']),len(upright['upright_packets'])) == (240,63)
    assert upright['final_upright_memory']['standing_samples_observed'] == 60
    assert upright['final_state']['phase'] == 'fresh_selected_policy_walking_resume'
    assert upright['final_state']['schema_version'] == 'sporespore_r10ab_recovery_orchestrator_state_v1'
    assert upright['selector_and_launcher_validation_exercised'] is False
    for folder in WRAPPERS:
        assert native.read(folder/'execution.json')['exit_code'] == 0
        lock=native.read(folder/'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    old=native.read(ROOT/'sdk/recovery/r10v_post_recovery_settling_finite_cycle_contract_v2.json')
    new=native.read(ROOT/'sdk/recovery/r10ab_partial_downward_rise_finite_cycle_contract_v1.json')
    for key in UNCHANGED: assert old[key] == new[key],key

    design=native.read(ROOT/'sdk/recovery/r10ab_partial_downward_rise_development_design_v1.json')
    for item in design['dependencies']:
        path=ROOT/item['path']
        assert path.stat().st_size == item['byte_length'] and native.diagnosis.digest(path.read_bytes()) == item['sha256']
    assert design['first_probe'] == new['prospective_populations']['development']['first_probe']
    for name in CONTRACTS:
        value=native.read(ROOT/'sdk/recovery'/name)
        for key in ('predecessor_contract','native_component_record','runtime_binding','task_contract','parent_start_contract'):
            if key in value:
                assert native.diagnosis.digest((ROOT/value[key]).read_bytes()) == value[key+'_sha256'],(name,key)
    assert new['controller_composition']['partial_support_raise_controller'] == 'sporespore_exact_s169_partial_downward_rise_controller_v24'
    assert new['controller_composition']['partial_control_composition_id'] == 'sporespore_r10ab_partial_downward_rise_v24_v7_composition_v1'

    probe=new['prospective_populations']['development']['first_probe']
    assert (probe['seed'],probe['prefix_phase'],probe['attempt_limit']) == (51008,248,1)
    assert probe['roles'] == ['kick_passive_recovery_resume'] and probe['baseline_reuse'] is False
    assert new['physical_execution_authorized'] is new['sdk1_m07_satisfied'] is False
    assert new['prospective_populations']['held_out']['declared'] is False
    return values


def run():
    values=observations()
    bound,_=native.runtime()
    core=native.ExactInputCore(bound['runtime']['path'])
    out=EVIDENCE/('r10ab-route-native-audit-'+uuid.uuid4().hex)
    out.mkdir()
    before=worker._source_snapshot()
    native.write(out/'source_before.json',before)
    print('R10AB_ROUTE_NATIVE_AUDIT_ROOT '+str(out),flush=True)
    count=0
    with (out/'compiled_replay.jsonl').open('x',encoding='utf-8',newline='\n') as trace:
        for group in ('entry_packets','upright_packets'):
            for index,packet in enumerate(values['upright-worker'][group]):
                call=packet['call']
                assert call['ok'] is True and call['compiled_call_count'] == 1 and packet['native_receipt'] == call['value']
                for field in ('request','response'):
                    raw=call[field]['utf8_text'].encode('utf-8')
                    assert len(raw) == call[field]['utf8_byte_length'] and native.diagnosis.digest(raw) == call[field]['raw_sha256']
                result=core._call_json_input('ss_'+call['method'],call['request']['utf8_text'].encode('utf-8'))
                assert result == call['value'] and core.raw_response == call['response']['utf8_text'].encode('utf-8')
                trace.write(json.dumps(dict(group=group,index=index,request_sha256=call['request']['raw_sha256'],response_sha256=call['response']['raw_sha256'],exact_replay=True))+'\n')
                count+=1
        for call in values['policy-bindings']['calls']:
            result=core._call_json_input('ss_balanced_wave_policy_profile_json',call['request'])
            assert result == json.loads(call['response_raw'])['value']
            assert core.raw_response == call['response_raw'].encode('utf-8')
            trace.write(json.dumps(dict(group='policy_bindings',identity=call['id'],profile_sha256=call['profile_sha256'],exact_replay=True))+'\n')
            count+=1
    after=worker._source_snapshot()
    native.write(out/'source_after.json',after)
    assert before == after and count == 307
    result=dict(ok=True,compiled_calls=count,world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
    native.write(out/'receipt.json',result)
    return result


def reconstruct(out):
    values=observations()
    assert native.read(AUDIT_WRAPPER/'execution.json')['exit_code']==0
    assert native.read(AUDIT_WRAPPER/'lock.json')['acquired'] is True
    assert native.read(out/'source_before.json') == native.read(out/'source_after.json')
    receipt=native.read(out/'receipt.json')
    assert receipt['ok'] is True and receipt['compiled_calls'] == 307
    rows=[json.loads(line) for line in (out/'compiled_replay.jsonl').read_text(encoding='utf-8').splitlines()]
    assert len(rows) == 307 and all(row['exact_replay'] is True for row in rows)
    return dict(ok=True,tests=3,checks={name:len(value['checks']) for name,value in values.items()},total_checks=62,
        partial_reader_transitions=303,upright_worker_commands=63,upright_entry_samples=240,upright_standing_samples=60,
        native_policy_bindings=4,compiled_replay_calls=307,unchanged_task_sections=UNCHANGED,
        declared_development_seed=51008,declared_prefix_phase=248,
        full_report_reader_checked=False,launcher_integrated=False,complete_smoke_safety_gate_passed=False,
        successor_physics_observed=False,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


def capture(out):
    assert not RECORD.exists()
    result=reconstruct(out)
    files=[p for folder in (READER,POLICIES,UPRIGHT,*WRAPPERS,AUDIT_WRAPPER,out) for p in sorted(folder.iterdir()) if p.is_file()]
    native.write(RECORD,dict(schema_version='sporespore_r10ab_route_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_partial_reader_and_route_binding',question_class='development'),
        native_audit_root=out.as_posix(),worker_component=native.diagnosis.binding(worker.RECORD),
        source_bindings=[native.diagnosis.binding(ROOT/p) for p in PATHS],
        retained_evidence=[native.diagnosis.binding(p) for p in files],observed=result))
    return result


def audit():
    record=native.read(RECORD)
    for item in record['source_bindings']+record['retained_evidence']+[record['worker_component']]: native.verify(item)
    result=reconstruct(Path(record['native_audit_root']))
    assert result == record['observed']
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--capture',type=Path)
    args=parser.parse_args()
    print('R10AB_ROUTE_COMPONENT '+json.dumps(run() if args.run else capture(args.capture) if args.capture else audit()),flush=True)
