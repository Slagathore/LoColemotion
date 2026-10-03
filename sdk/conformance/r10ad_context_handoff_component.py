"""Read-only audit of independent runtime-context production and consumption."""
import argparse,base64,hashlib,json
from pathlib import Path
import r10ad_startup_invalid_closure as prior
ROOT,EVIDENCE=prior.ROOT,prior.EVIDENCE
RUN=EVIDENCE/'r10ad-context-handoff-15b701592d8844fd81ec9fdd6d836373'
INITIAL=EVIDENCE/'r10ad-context-handoff-1ddb2f0de51a46a589d85146d3968527'
RECORD=ROOT/'sdk/recovery/r10ad_context_handoff_component_v1.json'
CLAIMS=dict(component_only=True,production_pre_world_comparator_used=True,
    full_launch_path_proven=False,consumed_attempt_reclassified=False,
    new_population_reserved=False,world_build_count=0,solver_step_count=0,
    physical_execution_authorized=False,physical_acceptance_authority=False,release_authority=False,
    sdk1_score='14/20',full_program_score='14/25')

def require(value,code):
    if not value:raise ValueError('R10AD_HANDOFF_'+code)

def observed():
    before=prior.read(RUN/'source-before.json')
    require(before==prior.read(RUN/'source-after.json') and before['head']==prior.HEAD,'SOURCE_STABLE')
    require(before['status'] and all(row['deleted'] is False for row in before['changed_files']),'OWNED_ADDITIONS')
    for row in before['changed_files']:
        raw=base64.b64decode(row['replacement_base64'])
        require('sha256:'+hashlib.sha256(raw).hexdigest()==row['raw_sha256'],'SNAPSHOT_BYTES')
    for relative in ['sdk/conformance/r10ad_context_handoff_diagnosis.py','tests/test_r10ad_context_handoff_diagnosis.gd']:
        row=next(row for row in before['changed_files'] if row['path']==relative)
        require(prior.bind(ROOT/relative)['raw_sha256']==row['raw_sha256'],'TESTED_SOURCE')
    lock=prior.read(RUN/'operation-lock.json')
    require(lock['acquired'] is True and lock['released'] is True and lock['role']=='conformance','LOCK')
    require(prior.read(RUN/'execution.json')['exit_code']==0,'RUN_EXIT')
    produced=prior.read(RUN/'producer.json')['capture']
    original=prior.read(prior.RUN/'children/kick_passive_recovery_resume/worker_report.json')['detail']['observed_capture']
    require(produced==original,'ORIGINAL_CONTEXT_REPRODUCED')
    for name in ['producer','selected-runtime','legacy-runtime','corrupt-digest']:
        execution=prior.read(RUN/(name+'.execution.json'))
        require(execution==dict(exit_code=0,timed_out=False),'NATIVE_EXIT')
        require((RUN/(name+'.stderr.log')).read_bytes()==b'','NATIVE_STDERR')
        result=prior.read(RUN/(name+'.json'))
        require(result['capture']==produced and result['ok'] is True,'CONTEXT_STABILITY')
        require(result['world_build_count']==result['solver_step_count']==0 and result['population_reserved'] is False
            and result['production_initializer_called'] is False,'NO_WORLD')
        if name!='producer':
            comparison=result['comparison'];accepted=name=='selected-runtime'
            require(result['accepted'] is comparison['ok'] is comparison['expected_capture_binding_matched'] is accepted,'COMPARISON')
            require(comparison['failure_code']==(None if accepted else 'L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH'),'REFUSAL')
    # Keep the first test-harness failure; it never reached context production.
    require(prior.read(INITIAL/'execution.json')['exit_code']==1
        and prior.read(INITIAL/'producer.execution.json')==dict(exit_code=3,timed_out=False)
        and not (INITIAL/'producer.json').exists(),'INITIAL_FAILURE_RETAINED')
    return dict(native_processes=4,selected_runtime_context_accepted=True,legacy_context_refused=True,
        corrupt_digest_refused=True,original_observed_context_reproduced_exactly=True,
        capture_binding={k:produced[k] for k in ['raw_sha256','utf8_byte_length']},
        first_harness_failure='Missing worker entry-runtime fixture; refused before context preparation.')

def audit(record):
    require(record['claim_boundary']==CLAIMS,'CLAIMS')
    for binding in record['bindings']+[record['auditor']]:prior.verify_binding(binding)
    prior.audit(prior.read(prior.RECORD))
    require(record['observed']==observed(),'OBSERVATION')
    return dict(ok=True,**record['observed'],**CLAIMS)

def create():
    paths=[p for root in [RUN,INITIAL] for p in sorted(root.rglob('*')) if p.is_file()]
    paths += [ROOT/'sdk/conformance/r10ad_context_handoff_diagnosis.py',ROOT/'tests/test_r10ad_context_handoff_diagnosis.gd',prior.RECORD,Path(prior.__file__)]
    record=dict(schema_version='sporespore_r10ad_context_handoff_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_zero_world_runtime_context_diagnosis',question_class='development'),
        source_commit=prior.HEAD,auditor=prior.bind(__file__),bindings=[prior.bind(p) for p in paths],
        observed=observed(),claim_boundary=CLAIMS,
        limits='Synthetic fresh declaration, explicit runtime/DLL binding, original production context preparation and comparator. The test replaces the worker initializer and does not exercise campaign admission, source-key admission, launch reservation, or world construction.',
        next_action='Implement a distinct successor selected-runtime context producer and full pre-world handoff before reservation; retain the exact producer receipt as launch authority. Do not reuse the old v6 fixture or copy a failed worker observation into the expected context.')
    audit(record);prior.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--create',action='store_true');a=p.parse_args()
    print(json.dumps(create() if a.create else audit(prior.read(RECORD))))
