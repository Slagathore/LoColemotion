"""Audit the isolated R10T scheduler/orchestrator; never authorize a worker."""
import argparse
import base64
import hashlib
import json

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
from recovery_post_completion_hold_probe import write

RECORD = ROOT/'sdk/recovery/r10t_settling_orchestration_component_v1.json'
RUNS = [(EVIDENCE/'r10t-settling-scheduler-d5dd93e605e24580ad25ca21940f1520', 'scheduler', 41),
        (EVIDENCE/'r10t-settling-orchestrator-8b37b87eb6574f789f128035963ffa54', 'orchestrator', 45)]
SOURCES = ['sdk/adapters/godot/gdscript/r10t_post_recovery_settling_v1.gd',
           'sdk/adapters/godot/gdscript/r10t_recovery_orchestrator_v1.gd',
           'tests/test_r10t_post_recovery_settling.gd', 'tests/test_r10t_post_recovery_settling.py',
           'tests/test_r10t_settling_orchestrator.gd', 'tests/test_r10t_settling_orchestrator.py']
CLAIMS = dict(native_policy_calls=0, world_build_count=0, solver_step_count=0,
    complete_worker_route_implemented=False, complete_worker_route_qualified=False,
    original_results_reclassified=False, physical_acceptance_authority=False,
    release_authority=False, held_out_population_declared=False, sdk1_score='14/20')


def observed():
    rows = []
    for run, label, expected in RUNS:
        execution = read(run/(label+'.execution.json'))
        assert execution['returncode']==0 and not execution['timed_out'] and execution['source_unchanged']
        assert not (run/(label+'.stderr.txt')).read_bytes()
        source = read(run/(label+'.source_snapshot.json'))
        assert source['head']=='c62f89dccf175cdb218f7567ca13b583ff20c135'
        assert source['remote']=='https://github.com/Slagathore/sporespore.git'
        for changed in source['changed_files']:
            assert not changed['deleted']
            raw = base64.b64decode(changed['replacement_base64'], validate=True)
            assert 'sha256:'+hashlib.sha256(raw).hexdigest()==changed['raw_sha256']
            assert bind(ROOT/changed['path'])['raw_sha256']==changed['raw_sha256']
        result = read(run/'result.json')
        markers = [json.loads(line.split(' ',1)[1]) for line in (run/(label+'.stdout.txt')).read_text(encoding='utf-8').splitlines()
                   if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
        assert markers==[result] and result['ok'] and result['check_count']==expected
        assert len(result['checks'])==expected and all(result['checks'].values())
        assert result['native_policy_calls']==result['world_build_count']==result['solver_step_count']==0
        assert not result['physical_route_qualified'] and not result['physical_acceptance_authority'] and not result['release_authority']
        input_name = 'synthetic_input.json' if label=='scheduler' else 'retained_terminal_inputs.json'
        assert result['input_raw_sha256']==bind(run/input_name)['raw_sha256']
        if label=='orchestrator':
            for item in read(run/'original_report_bindings.json'): verify(item)
            assert result['retained_terminal_events_copied_with_new_orchestrator_identities']
            assert result['post_recovery_hold_events_are_synthetic'] and not result['original_results_reclassified']
        rows.append(dict(suite=label, unittest_groups=5, executable_checks=expected,
            result=bind(run/'result.json'), execution=bind(run/(label+'.execution.json'))))
    return dict(ok=True, suites=rows, unittest_groups=10, executable_checks=86,
        next_permitted_stage='integrate_r10t_worker_reader_and_launcher_then_complete_safety_qualification', **CLAIMS)


def create():
    assert not RECORD.exists()
    result = observed()
    value = dict(schema_version='sporespore_r10t_settling_orchestration_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='isolated_development_orchestration_component', question_class='development'),
        source_commit='c62f89dccf175cdb218f7567ca13b583ff20c135',
        auditor=bind(__file__), source_files=[bind(ROOT/path) for path in SOURCES],
        design=bind(ROOT/'sdk/recovery/r10t_post_recovery_settling_design_v1.json'),
        retained_files=[bind(path) for run,_,_ in RUNS for path in sorted(run.iterdir()) if path.is_file()],
        source_retention='Both original pre-execution snapshots retain exact changed-file bytes as base64 on the pushed source commit. Original terminal reports are separately digest-bound.',
        pre_native_fixture_correction='The first Python fixture extraction used a guessed prone phase name and found no event; corrected to the actual offset_bound_recovery_epoch constant before launching the native test process. No physical or native policy call occurred in that fixture error.',
        observed=result, claim_boundary=CLAIMS)
    write(RECORD,value)
    return audit()


def audit():
    record=read(RECORD)
    assert record['claim_boundary']==CLAIMS
    for item in record['source_files']+record['retained_files']+[record['auditor'],record['design']]: verify(item)
    assert observed()==record['observed']
    return dict(ok=True, record=bind(RECORD), unittest_groups=10, executable_checks=86, **CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    print('R10T_SETTLING_ORCHESTRATION_COMPONENT '+json.dumps(create() if args.create else audit()))
