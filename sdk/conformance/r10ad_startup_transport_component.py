"""Retain the R10AD native helper transport reproduction and narrow repair."""
import argparse,json,re
from pathlib import Path
import r10ac_startup_invalid_closure as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
STDIO=EVIDENCE/'r10ad-helper-stdio-9a47bc908f514360ac33426ada90fe6d'
REPAIR=EVIDENCE/'r10ad-transport-repair-3699e48fa8e94e0a8425044051586900'
RECORD=ROOT/'sdk/recovery/r10ad_startup_transport_component_v1.json'
CLAIMS=dict(zero_world_transport_defect_reproduced=True,isolated_transport_repair_verified=True,
    unique_original_r10ac_refusal_recovered=False,successor_worker_integrated=False,
    complete_successor_safety_gate_passed=False,new_population_reserved=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')
SOURCES=['sdk/conformance/r10ad_startup_transport.py','tests/r10ad_startup_transport_probe.py',
    'tests/test_r10ad_startup_transport.gd','tests/test_r10ad_startup_transport.py',
    'tests/r10ad_helper_stdio.py','tests/test_r10ad_helper_stdio.gd',
    'sdk/conformance/r10ac_startup_invalid_closure.py','sdk/recovery/r10ac_startup_invalid_closure_v1.json']


def observed():
    modes=base.read(STDIO/'result.json')['modes']
    base.require([m['capture_stderr'] for m in modes]==[False,True], 'STDIO_MODES')
    results=[json.loads(m['output'][0]) for m in modes]
    base.require(all(m['exit_code']==0 for m in modes), 'STDIO_PROBE_EXIT')
    base.require(all(c['ok'] for r in results for c in r['checks'][:-1]), 'LOCAL_GIT')
    base.require(results[0]['checks'][-1]['ok'] is False and results[0]['checks'][-1]['type']=='CalledProcessError'
        and 'exit status 128' in results[0]['checks'][-1]['error'], 'INHERITED_STDERR_REFUSAL')
    base.require(results[1]['checks'][-1]['ok'] is True
        and results[1]['checks'][-1]['value']==base.HEAD+'\trefs/heads/main', 'CAPTURED_STDERR_SUCCESS')
    result=base.read(REPAIR/'native.json');base.require(result['exit_code']==0,'REPAIR_NATIVE_EXIT')
    comparisons=json.loads(result['helper_output'][0])['comparisons']
    base.require([c['mode'] for c in comparisons]==['inherited_stderr_before','explicit_pipes','inherited_stderr_after'], 'REPAIR_MODES')
    base.require(comparisons[0]['exit_code']==comparisons[2]['exit_code']==128,'BEFORE_AFTER_REFUSAL')
    fixed=comparisons[1]['receipt']
    base.require(fixed['exit_code']==0 and fixed['timed_out'] is False and fixed['stderr']==''
        and fixed['stdout'].strip()==base.HEAD+'\trefs/heads/main','FIXED_LIVE_REMOTE')
    for folder in [STDIO,REPAIR]:
        lock=base.read(folder/'operation-lock.json')
        base.require(lock['acquired'] is True and lock['released'] is True and lock['role']=='conformance','LOCK')
    base.require(all(p['exit_code']==0 for p in base.read(REPAIR/'execution.json')['processes']),'TEST_PROCESSES')
    log=(REPAIR/'unit.stderr.log').read_text()
    base.require(re.findall(r'^Ran (\d+) tests in [0-9.]+s\s*$',log,re.M)==['3']
        and len(re.findall(r'^OK\s*$',log,re.M))==1,'UNIT_POPULATION')
    base.require((REPAIR/'native.stderr.log').read_bytes()==b'','NATIVE_STDERR')
    return dict(unit_tests=3,live_remote_comparison_exit_codes=[128,0,128],
        captured_stderr_probe_succeeded=True,world_build_count=0,solver_step_count=0,
        selected_fix='DEVNULL stdin and explicit stdout/stderr pipes for helper subprocesses',
        original_root_cause_limit='The differential reproduces a failure in the original helper transport, but R10AC did not retain its helper refusal or traceback. The original attempt remains invalid and its exact failing predicate unproven.')


def audit(record):
    base.require(record['claim_boundary']==CLAIMS,'COMPONENT_CLAIMS')
    for binding in record['bindings']+[record['auditor']]:base.verify_binding(binding)
    base.require(record['observed']==observed(),'COMPONENT_OBSERVATION')
    base.audit(base.read(base.RECORD))
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    base.require(not RECORD.exists(),'COMPONENT_ALREADY_EXISTS')
    paths=[p for folder in [STDIO,REPAIR] for p in sorted(folder.rglob('*')) if p.is_file()]
    record=dict(schema_version='sporespore_r10ad_startup_transport_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_native_helper_transport_component',question_class='development'),
        predecessor_closure=base.RECORD.relative_to(ROOT).as_posix(),auditor=base.bind(__file__),
        bindings=[base.bind(p) for p in paths+[ROOT/p for p in SOURCES]],observed=observed(),claim_boundary=CLAIMS,
        next_action='Integrate explicit helper subprocess pipes and retained startup refusal diagnostics into a separately declared successor. Exercise real zero-world startup before reserving its fresh diagnostic identity; qualify the complete applicable gate before physics.')
    audit(record);base.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args();print(json.dumps(create() if args.create else audit(base.read(RECORD))))
