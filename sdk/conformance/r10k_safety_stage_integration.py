"""Read-only audit of the assembled R10K zero-world stage run; no physical authority."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_safety_stage_integration_v1.json'

def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_safety_stage_integration_v1', 'SAFETY_SCHEMA')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        selected_safety_stages_passed=True, preparation_to_walking_report_verified=False,
        complete_production_route_qualified=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20'), 'SAFETY_CLAIMS')
    for key in ['predecessor_record','candidate_profile','entry_contract','runtime_binding',
                'consumed_r10j_closure','auditor','supervisor']:
        verify(record[key])
    verify(read(verify(record['runtime_binding']))['runtime'])
    evidence=set()
    for item in record['retained_evidence']:
        require(item['path'] not in evidence, 'SAFETY_DUPLICATE_EVIDENCE')
        evidence.add(item['path'])
        verify(item)
    supervisor=read(verify(record['supervisor']))
    require(supervisor['ok'] is True and supervisor['failure_code'] == ''
        and supervisor['run_smoke_requested'] is False and supervisor['physical_attempt_started'] is False
        and supervisor['children'] == [] and supervisor['independent_audit'] is None
        and supervisor['complete_route_proven'] is False and supervisor['official_qualification_passed'] is False
        and supervisor['physical_acceptance_authority'] is False and supervisor['release_authority'] is False, 'SAFETY_NO_WORLD')
    base=Path(supervisor['output_root'])
    stages=supervisor['safety_stages']
    selected=read(record['selected_stages_path'])
    declared={stage['id']:stage for stage in selected['stages']}
    require(len(stages) == len(declared) == record['stage_count'] == 37
        and set(declared) == {stage['id'] for stage in stages}, 'SAFETY_STAGE_POPULATION')
    tests=0
    for stage in stages:
        declaration=declared[stage['id']]
        require(stage['passed'] is True and stage['exit_code'] == 0 and stage['timed_out'] is False
            and stage['test_count'] == stage['expected_test_count'] == declaration['tests'], 'SAFETY_STAGE_RESULT:'+stage['id'])
        if 'candidate_profile' in declaration:
            require(declaration['candidate_profile'] == record['candidate_profile']['path'], 'SAFETY_STAGE_CANDIDATE')
        for kind in ['stdout','stderr']:
            path=base/stage[kind]
            require(path.as_posix() in evidence and hashlib.sha256(path.read_bytes()).hexdigest() == stage[kind+'_sha256'], 'SAFETY_STAGE_LOG')
        log=(base/stage['stderr']).read_text(encoding='utf-8')
        require(re.search(r'Ran '+str(stage['test_count'])+r' tests? in .*\n\nOK\s*$',log) is not None, 'SAFETY_STAGE_COUNT')
        tests+=stage['test_count']
    require(tests == selected['test_count'] == record['test_count'] == 184, 'SAFETY_TOTAL')
    for name in ['candidate_reader','r10k_worker','r10k_recovery_reader']:
        require(declared[name]['timeout_seconds'] == 600, 'SAFETY_TEST_BUDGET')
    source=supervisor['source_snapshot']
    require(source['head'] == record['source_parent_commit'], 'SAFETY_SOURCE_PARENT')
    changes={row['path']:row for row in source['changed_file_bindings']}
    contract=read(verify(record['entry_contract']))
    for item in contract['bound_source_files']:
        name=item['path']
        digest=('sha256:'+changes[name]['sha256'] if name in changes else 'sha256:'+hashlib.sha256(
            subprocess.check_output(['git','show',source['head']+':'+name],cwd=ROOT)).hexdigest())
        require(digest == item['raw_sha256'], 'SAFETY_OBSERVED_SOURCE:'+name)
        if current_sources:
            require('sha256:'+hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest, 'SAFETY_CURRENT_SOURCE:'+name)
    for directory in record['stable_source_roots']:
        root=Path(directory)
        require((root/'source_before.json').read_bytes() == (root/'source_after.json').read_bytes(), 'SAFETY_SOURCE_STABILITY:'+root.name)
    require(len(record['measured_body_result_paths']) == 2, 'SAFETY_BOTH_V51_ROLES')
    for name in record['measured_body_result_paths']:
        values=[json.loads(line.split(' ',1)[1]) for line in Path(name).read_text().splitlines()
            if line.startswith('V50_MEASURED_BODY_ADAPTER ')]
        require(len(values) == 1 and values[0]['ok'] is True and all(values[0]['checks'].values())
            and values[0]['world_build_count'] == values[0]['solver_step_count'] == 0, 'SAFETY_V51_RESULT')
        require(values[0]['candidate_profile']['resource'] == 'res://'+record['candidate_profile']['path'], 'SAFETY_V51_SELECTION')
    launcher=Path(record['launcher_root'])
    require('R10K_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING' in (launcher/'physical-gate-refusal.stderr.txt').read_text()
        and read(launcher/'physical-gate-refusal.execution.json')['returncode'] != 0, 'SAFETY_LAUNCH_STILL_CLOSED')
    for branch in ['prone','partial']:
        root=Path(record['complete_report_root'])
        result=read(root/(branch+'.results.json'))
        for role in ['active','baseline']:
            require(result[role]['ok'] is True and result[role]['complete_report_timeline_replayed'] is True
                and result[role]['world_build_count'] == result[role]['solver_step_count'] == 0
                and result[role]['physical_acceptance_authority'] is False, 'SAFETY_COMPLETE_RECOVERY_REPORT')
    for item in record['preserved_stopped_runs']:
        value=read(verify(item['result']))
        require(value['ok'] is False, 'SAFETY_STOPPED_RESULT_REWRITTEN')
    return dict(ok=True, tests_passed=tests, stages_passed=len(stages),
        bound_sources=len(contract['bound_source_files']), retained_files=len(evidence),
        complete_serialized_recovery_reports=4, preparation_to_walking_report_verified=False,
        world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--current-sources',action='store_true')
    args=parser.parse_args()
    print(json.dumps(audit(args.current_sources),sort_keys=True))
