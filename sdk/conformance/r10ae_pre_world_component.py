"""Retained R10AE pre-world path component; never launch qualification."""
import argparse,base64,hashlib,json,re,subprocess
from pathlib import Path
import r10ad_startup_invalid_closure as shared
ROOT,EVIDENCE=shared.ROOT,shared.EVIDENCE
HEAD='c9ab2b050dd8c019ee1f6789959fc02fca7211b1'
RUN=EVIDENCE/'r10ae-pre-world-60ef60cb563f4b04b572cae51ecc646e'
INITIAL=EVIDENCE/'r10ae-pre-world-4b1bb733e99747e690ff99276f3a8029'
CONTROLS=EVIDENCE/'r10ae-foundation-controls-ab86238240134b6ab7f2d04df3ec7f5a'
RECORD=ROOT/'sdk/recovery/r10ae_pre_world_component_v1.json'
CLAIMS=dict(selected_runtime_context_component_verified=True,inherited_pre_world_sequence_exercised=True,
    campaign_admission_doubled=True,full_launch_path_proven=False,complete_safety_gate_qualified=False,
    new_population_reserved=False,physical_execution_authorized=False,physical_acceptance_authority=False,
    release_authority=False,sdk1_score='14/20',full_program_score='14/25')
BASE_INPUTS=['tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd',
    'sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd',
    'sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd',
    'sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd',
    'sdk/adapters/godot/gdscript/r10ac_linked_capture_worker_v1.gd',
    'sdk/adapters/godot/gdscript/recovery_native_route_v1.gd']

def require(value,code):
    if not value:raise ValueError('R10AE_PRE_WORLD_COMPONENT_'+code)

def observed():
    before=shared.read(RUN/'source-before.json')
    require(before==shared.read(RUN/'source-after.json') and before['head']==HEAD,'SOURCE_STABILITY')
    require(before['status'] and before['remote']=='https://github.com/Slagathore/sporespore.git','SOURCE_IDENTITY')
    for row in before['changed_files']:
        raw=base64.b64decode(row['replacement_base64'])
        require(row['deleted'] is False and 'sha256:'+hashlib.sha256(raw).hexdigest()==row['raw_sha256'],'SNAPSHOT_BYTES')
        require((ROOT/row['path']).read_bytes()==raw,'TESTED_SOURCE:'+row['path'])
    for path in BASE_INPUTS:
        raw=subprocess.check_output(['git','show',HEAD+':'+path],cwd=ROOT)
        require((ROOT/path).read_bytes()==raw or (ROOT/path).read_bytes()==raw.replace(b'\n',b'\r\n'),'BASE_SOURCE:'+path)
    lock=shared.read(RUN/'operation-lock.json')
    require(lock['acquired'] is True and lock['released'] is True and lock['role']=='conformance','LOCK')
    require(shared.read(RUN/'execution.json')['exit_code']==0,'RUN_EXIT')
    produced=shared.read(RUN/'producer.json')['capture']
    captured=json.loads(produced['utf8_text'])
    context=json.loads(captured['source_context']['utf8_text'])
    identity=context['runtime_profile_receipt']['runtime_identity']
    require(identity['r10ae_diagnostic_only'] is True
        and identity['engine_binary']['raw_sha256']=='491663b2f41147938b45eeb0863d68a0bb14ec18c6349d94402df846f29f9347','SELECTED_RUNTIME')
    for name in ['producer','selected-runtime','legacy-runtime','corrupt-digest','crossed-runtime']:
        execution=shared.read(RUN/(name+'.execution.json'))
        require(execution==dict(exit_code=0,timed_out=False),'EXECUTION')
        require((RUN/(name+'.stderr.log')).read_bytes()==b'','STDERR')
        result=shared.read(RUN/(name+'.json'))
        require(result['ok'] is True and result['campaign_admission_doubled'] is True,'PROBE_SCOPE')
        for field in ['world_build_count','solver_step_count','world_attempt_count','model_construction_count']:
            require(type(result[field]) is int and result[field]==0,'ZERO_WORLD')
        require(all(result[k] is False for k in ['population_reserved','physical_acceptance_authority','release_authority']),'CLAIMS')
        if name=='crossed-runtime':
            require(result['terminal_code']=='QSDK_R10F_EXTENSION_UNAVAILABLE'
                and result['construction_boundary_reached'] is False and result['capture']=={},'CROSSED_RUNTIME')
            continue
        require(result['capture']==produced,'FRESH_CONTEXT_STABILITY')
        if name=='selected-runtime':
            require(result['comparison']['ok'] is True and result['configuration']['ok'] is True
                and result['runtime_preflight']['ok'] is True and result['construction_boundary_reached'] is True,'PRE_WORLD_SEQUENCE')
            require(result['construction_guard']['failure_code']=='R10AE_NATIVE_WORLD_QUALIFICATION_PENDING'
                and result['construction_guard']['world_build_count']==0,'CONSTRUCTION_GUARD')
        elif name!='producer':
            require(result['comparison']['ok'] is False and result['construction_boundary_reached'] is False
                and result['terminal_code']=='QSDK_R10F_L15_PRE_WORLD_CONTEXT_INVALID'
                and result['comparison']['failure_code']=='L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH','CONTEXT_REFUSAL')
    require(shared.read(INITIAL/'producer.execution.json')==dict(exit_code=1,timed_out=False)
        and 'must be called with' in (INITIAL/'producer.stderr.log').read_text(),'PARSER_FAILURE_RETAINED')
    tests=(CONTROLS/'stderr.log').read_text(encoding='utf-8-sig')
    require(shared.read(CONTROLS/'execution.json')['exit_code']==0
        and re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$',tests,re.M)==['4']
        and len(re.findall(r'^OK\s*$',tests,re.M))==1,'FOUNDATION_TESTS')
    return dict(native_processes=5,foundation_tests=4,diagnostic_seed=63248,exposed_prefix_phase=248,
        selected_runtime_context_accepted=True,legacy_context_refused=True,corrupt_digest_refused=True,
        crossed_runtime_refused=True,unqualified_construction_refused=True,
        capture_binding={k:produced[k] for k in ['raw_sha256','utf8_byte_length']},
        world_build_count=0,solver_step_count=0,
        retained_initial_failure='Test probe omitted await on the coroutine world guard; parser refused before runtime preparation.')

def audit(record):
    require(record['claim_boundary']==CLAIMS,'RECORD_CLAIMS')
    for binding in record['bindings']+[record['auditor']]:shared.verify_binding(binding)
    require(record['observed']==observed(),'OBSERVATION_CHANGED')
    return dict(ok=True,**record['observed'],**CLAIMS)

def create():
    paths=[p for folder in [RUN,INITIAL,CONTROLS] for p in sorted(folder.rglob('*')) if p.is_file()]
    paths += [ROOT/row['path'] for row in shared.read(RUN/'source-before.json')['changed_files']]
    paths += [ROOT/p for p in BASE_INPUTS]+[Path(shared.__file__),ROOT/'tests/test_r10ae_foundation.py']
    record=dict(schema_version='sporespore_r10ae_pre_world_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='selected_runtime_pre_world_component',question_class='development'),
        source_commit=HEAD,auditor=shared.bind(__file__),bindings=[shared.bind(p) for p in paths],
        observed=observed(),claim_boundary=CLAIMS,
        limits='Pure input binding and exact DLL/runtime loading produce a fresh expected context. An independent process runs the inherited worker startup through its real pre-world comparator and configuration. Campaign admission is explicitly replaced by identity admission; construction is intercepted and the actual unqualified native guard is invoked. No launch reservation or source-key qualification is exercised.',
        next_action='Integrate the selected-runtime producer receipt and independent consumer into the real prospective launcher before reservation; then finish source-key, reader, qualification and single-use authority integration. This component does not authorize a world.')
    audit(record);shared.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--create',action='store_true');a=p.parse_args()
    print(json.dumps(create() if a.create else audit(shared.read(RECORD))))
