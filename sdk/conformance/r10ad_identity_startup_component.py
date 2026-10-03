"""Audit retained R10AD identity and read-only native startup preflight evidence."""
import argparse,json,re,subprocess
from pathlib import Path
import r10ac_startup_invalid_closure as base
import r10ad_development as identity
import r10ad_host_runtime as host
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
DIRTY=EVIDENCE/'r10ad-startup-preflight-5384e9720af641b788223b88ad95b31a'
FAILED=EVIDENCE/'r10ad-startup-preflight-a6a0f744f41e4366ac30e4f3e3771383'
CONTROLS=EVIDENCE/'r10ad-preflight-controls-523e652a0b704df6afb0cfaafe4d1dcb'
RECORD=ROOT/'sdk/recovery/r10ad_identity_startup_component_v1.json'
CLAIMS=dict(identity_and_host_preflight_verified=True,candidate_source_key_checked=False,
    complete_safety_gate_checked=False,production_worker_integrated=False,
    new_population_reserved=False,physical_execution_authorized=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')
SOURCES=['sdk/conformance/r10ad_development.py','sdk/conformance/r10ad_host_runtime.py',
    'sdk/conformance/r10ad_startup_transport.py','sdk/conformance/r10ad_startup_preflight.py',
    'sdk/conformance/r10ad_startup_check.py','sdk/check_r10ad_startup_preflight.ps1','sdk/r10ad_host_runtime.ps1',
    'sdk/adapters/godot/gdscript/r10ad_development_seed_v1.gd','sdk/adapters/godot/gdscript/r10ad_native_startup_v1.gd',
    'sdk/development/r10ad_host_runtime_contract_v1.json','sdk/recovery/r10ad_contact_frame_development_design_v1.json',
    'sdk/development/recovery_candidates/r10ad-contact-frame-diagnostic-v1.json',
    'sdk/development/recovery_schedules/r10ad-contact-frame-diagnostic-v1.json',
    'tests/r10ad_preflight_fixture.py','tests/test_r10ad_startup_preflight.py','tests/test_r10ad_startup_preflight.gd']


def observed(positive):
    positive=Path(positive)
    base.require(positive.parent==EVIDENCE and positive.name.startswith('r10ad-startup-preflight-'),'PREFLIGHT_ROOT')
    result=base.read(positive/'result.json');native=base.read(positive/'native.json');preflight=native['preflight'];receipt=preflight['helper_receipt']
    base.require(result['ok'] is True and result['source_clean'] is True and result['native_preflight_passed'] is True,'CLEAN_PREFLIGHT')
    base.require(preflight['ok'] is True and preflight['helper_exit_code']==0 and receipt['ok'] is True and receipt['stage']=='complete','NATIVE_PREFLIGHT')
    base.require(all(v is True for v in native['identity_checks'].values()) and len(native['identity_checks'])==8,'IDENTITY_CHECKS')
    base.require(receipt['freeze']['head']==result['source_commit'] and receipt['freeze']['clean'] is True,'PREFLIGHT_FREEZE')
    commands=receipt['command_receipts']
    base.require(len(commands)==7 and all(r['exit_code']==0 and r['timed_out'] is False and type(r['stdout']) is str and type(r['stderr']) is str for r in commands),'CAPTURED_GIT')
    base.require(commands[-1]['command']==['git','ls-remote','origin','refs/heads/main']
        and commands[-1]['stdout'].strip()==result['source_commit']+'\trefs/heads/main','LIVE_REMOTE')
    base.require(receipt['worker_image']==host.expected_binding()['images']['godot_engine'],'NATIVE_OWNER')
    for field in ['candidate_source_key_checked','complete_safety_gate_checked','physical_execution_authorized','physical_acceptance_authority','release_authority','launch_reservation_created','native_world_claim_created']:
        base.require(receipt[field] is False,'PREFLIGHT_SCOPE:'+field)
    for folder in [positive,DIRTY]:
        base.require(base.read(folder/'source-before.json')==base.read(folder/'source-after.json'),'SOURCE_STABILITY')
        lock=base.read(folder/'operation-lock.json');base.require(lock['acquired'] is True and lock['released'] is True,'OPERATION_LOCK')
        base.require(base.read(folder/'execution.json')==dict(exit_code=0,timed_out=False),'NATIVE_EXECUTION')
        base.require((folder/'stderr.log').read_bytes()==b'','NATIVE_STDERR')
        declaration=base.read(folder/'fixture.json');identity.validate_declaration(declaration)
        base.require(not (EVIDENCE/('development-recovery-smoke-'+declaration['attempt_id'])).exists(),'NO_CAMPAIGN_ROOT')
    dirty=base.read(DIRTY/'native.json')['preflight']['helper_receipt']
    base.require(dirty['ok'] is False and dirty['stage']=='source_freeze' and dirty['failure_code']=='R10AD_STARTUP_SOURCE_NOT_CLEAN','DIRTY_REFUSAL')
    base.require("KeyError: 'dirty'" in (FAILED/'driver.stderr.log').read_text(encoding='utf-8'),'RETAINED_DRIVER_FAILURE')
    unit=(CONTROLS/'unit.stderr.log').read_text(encoding='utf-8')
    base.require(re.findall(r'^Ran (\d+) tests in [0-9.]+s\s*$',unit,re.M)==['4'] and len(re.findall(r'^OK\s*$',unit,re.M))==1,'CONTROL_POPULATION')
    base.require(base.read(CONTROLS/'powershell-runtime.json')['binding']==host.expected_binding(),'POWERSHELL_HOST')
    return dict(source_commit=result['source_commit'],seed=62248,prefix_phase=248,
        unit_tests=4,native_identity_checks=8,clean_native_preflight_passed=True,
        dirty_source_refusal_retained=True,live_remote_checked_through_native_helper=True,
        original_driver_fixture_error_preserved=True,world_build_count=0,solver_step_count=0)


def audit(record):
    base.require(record['claim_boundary']==CLAIMS,'IDENTITY_STARTUP_CLAIMS')
    for binding in record['bindings']+[record['auditor']]:base.verify_binding(binding)
    base.require(record['observed']==observed(record['positive_root']),'IDENTITY_STARTUP_OBSERVATION')
    return dict(ok=True,**record['observed'],**CLAIMS)


def create(positive):
    base.require(not RECORD.exists(),'IDENTITY_STARTUP_ALREADY_CLOSED')
    paths=[p for folder in [Path(positive),DIRTY,FAILED,CONTROLS] for p in sorted(folder.rglob('*')) if p.is_file()]
    record=dict(schema_version='sporespore_r10ad_identity_startup_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_identity_runtime_source_preflight_component',question_class='development'),
        positive_root=Path(positive).as_posix(),auditor=base.bind(__file__),
        bindings=[base.bind(p) for p in paths+[ROOT/p for p in SOURCES]],observed=observed(positive),claim_boundary=CLAIMS,
        next_action='Integrate the unchanged controller/capture worker and reader under the fresh R10AD source key, add retained startup diagnostics to its separate single-use launch authority, and qualify the complete applicable safety gate before the diagnostic world.')
    audit(record);base.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',type=Path);args=parser.parse_args()
    print(json.dumps(create(args.create) if args.create else audit(base.read(RECORD))))
