"""Retain actual R10O route, declaration and launcher checks before physics."""
import argparse
from functools import lru_cache
import re
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

from development_passive_entry_profile import _source_snapshot
from v52_extended_support_transfer import read, verify

ROOT = Path(__file__).resolve().parents[2]
PROFILE = 'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json'
STAGES = ['candidate_recovery_route', 'candidate_profile', 'r10o_declaration', 'candidate_schedule']


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def binding(path):
    path = Path(path); raw = path.read_bytes()
    return dict(path=path.as_posix(), byte_length=len(raw), raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest())


def run():
    # The caller owns the repository operation mutex. Library mode has no launch.
    out = ROOT.parent / 'SporeSpore_Evidence' / ('development-r10o-route-integration-' + uuid.uuid4().hex)
    out.mkdir()
    print('R10O_ROUTE_INTEGRATION_EVIDENCE ' + str(out), flush=True)
    before = _source_snapshot(); write(out / 'source_before.json', before)
    copies = []
    for item in before['changed_files']:
        if item['deleted']:
            raise ValueError('R10O_INTEGRATION_UNEXPECTED_DELETION')
        source = ROOT / item['path']; target = out / 'source_files' / item['path']
        target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(source.read_bytes())
        copied = binding(target); copied['path'] = item['path']; copies.append(copied)
    write(out / 'source_files_manifest.json', dict(source_head=before['head'], files=copies))
    env = dict(os.environ, SPORE_R10O_INTEGRATION_ROOT=str(out))
    command = ['pwsh', '-NoProfile', '-NonInteractive', '-Command', r'''
$ErrorActionPreference = 'Stop'
. ./sdk/run_development_recovery_smoke.ps1 -Library -ProfileSteps -ReuseContextChecks -CandidateProfile 'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json'
$taskRoot = $env:SPORE_R10O_INTEGRATION_ROOT
$selected = @($stages | ForEach-Object { [ordered]@{id=$_.id;pattern=$_.pattern;tests=$_.tests;timeout_seconds=$(if ($_.ContainsKey('timeout_seconds')) {$_.timeout_seconds} else {180})} })
[IO.File]::WriteAllText((Join-Path $taskRoot 'selected-stages.json'), (ConvertTo-SporeSporeExactJson -Value $selected), [Text.UTF8Encoding]::new($false))
$completed = [Collections.Generic.List[object]]::new()
foreach ($taskId in @('candidate_recovery_route','candidate_profile','r10o_declaration','candidate_schedule')) {
    $taskStage = @($stages | Where-Object { $_.id -ceq $taskId })
    if ($taskStage.Count -ne 1) { throw ('R10O_STAGE_POPULATION:' + $taskId) }
    $result = Invoke-DevelopmentStage -Stage $taskStage[0] -RunRoot $taskRoot
    $completed.Add($result)
    [IO.File]::WriteAllText((Join-Path $taskRoot 'stages.json'), (ConvertTo-SporeSporeExactJson -Value $completed.ToArray()), [Text.UTF8Encoding]::new($false))
    if (-not $result.passed) { throw ('R10O_STAGE_FAILED:' + $taskId) }
}
''']
    started = time.monotonic()
    try:
        with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                timeout=900, creationflags=subprocess.CREATE_NO_WINDOW)
        write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
    except subprocess.TimeoutExpired:
        write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
        raise
    finally:
        after = _source_snapshot(); write(out / 'source_after.json', after)
        write(out / 'source-stability.json', dict(source_unchanged=before == after))
    return dict(evidence_root=out.as_posix(), exit_code=process.returncode, source_unchanged=before == after)


RECORD = ROOT / 'sdk/recovery/r10o_route_integration_v1.json'
CLAIMS = dict(full_route_implemented=True, complete_safety_gate_passed=False,
    physical_attempt_started=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def require(ok, code):
    if not ok:
        raise ValueError('R10O_INTEGRATION_' + code)


@lru_cache(maxsize=None)
def committed_digest(head, name):
    raw = subprocess.check_output(['git', 'show', head + ':' + name], cwd=ROOT)
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def source_population(root, entry_path):
    before = read(root / 'source_before.json')
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(), 'SOURCE_STABILITY')
    manifest = read(root / 'source_files_manifest.json')
    copied = {item['path']: item for item in manifest['files']}
    require(manifest['source_head'] == before['head']
        and len(copied) == len(manifest['files']) == len(before['changed_files']), 'SOURCE_POPULATION')
    for item in before['changed_files']:
        actual = binding(root / 'source_files' / item['path'])
        require(item['deleted'] is False and actual['raw_sha256'] == item['raw_sha256']
            == copied[item['path']]['raw_sha256'] and actual['byte_length'] == copied[item['path']]['byte_length'], 'SOURCE_COPY')
    entry = read(root / 'source_files' / entry_path)
    for item in entry['bound_source_files']:
        actual = copied[item['path']]['raw_sha256'] if item['path'] in copied else committed_digest(before['head'], item['path'])
        require(actual == item['raw_sha256'], 'OBSERVED_SOURCE:' + item['path'])
    return len(entry['bound_source_files'])


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10o_route_integration_v1'
        and record['claim_boundary'] == CLAIMS, 'IDENTITY_OR_CLAIMS')
    for key in ['auditor', 'entry_contract', 'candidate_profile', 'stage_contract', 'task_contract', 'runtime_binding', 'native_component']:
        verify(record[key])
    runtime = read(verify(record['runtime_binding'])); verify(runtime['runtime'])
    task = read(verify(record['task_contract']))
    previous = read(verify(record['predecessor_task']))
    for key in ['native_interaction', 'limits', 'finite_walking_observable', 'settled_tail', 'whole_walking_envelope', 'partial_recovery', 'prone_recovery']:
        require(task[key] == previous[key], 'TASK_REQUIREMENT_CHANGED:' + key)
    require(task['controller_composition']['native_runtime_sha256'] == runtime['runtime']['raw_sha256']
        and task['controller_composition']['post_interaction_walking'] == 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1', 'NATIVE_IDENTITY')
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE'); seen.add(item['path']); verify(item)
    require(len(record['attempts']) == 2, 'ATTEMPTS')
    counts = []
    for index, attempt in enumerate(record['attempts']):
        root = Path(attempt['root']); counts.append(source_population(root, attempt['entry_contract']))
        stages = read(root / 'stages.json')
        require([stage['id'] for stage in stages] == (STAGES if index == 1 else STAGES[:1]), 'STAGES')
        for stage in stages:
            require(stage['timed_out'] is False and stage['test_count'] == stage['expected_test_count']
                and stage['passed'] is (index == 1) and stage['exit_code'] == (0 if index == 1 else 1), 'STAGE_RESULT')
            for label in ['stdout', 'stderr']:
                raw = (root / stage[label]).read_bytes()
                require(hashlib.sha256(raw).hexdigest() == stage[label + '_sha256'], 'STAGE_LOG')
            log = (root / stage['stderr']).read_text(encoding='utf-8-sig')
            require(re.findall(r'^Ran ([0-9]+) tests? in [0-9.]+s$', log, re.MULTILINE) == [str(stage['expected_test_count'])], 'TEST_COUNT')
            require(bool(re.search(r'\nOK\s*$', log)) if index == 1 else 'FAILED (failures=1)' in log, 'TEST_TERMINAL')
    failed = read(Path(record['refused_route_root']) / 'result.json')
    require({k:v for k,v in failed['checks'].items() if v is not True} == {'old_seed_modulo_preserved': False}
        and len(failed['checks']) == 48 and failed['world_build_count'] == failed['solver_step_count'] == 0, 'ORIGINAL_REFUSAL')
    route = read(Path(record['corrected_route_root']) / 'result.json')
    require(route['ok'] is True and len(route['checks']) == 48 and all(v is True for v in route['checks'].values()), 'ACTUAL_ROUTE')
    for label in ['resume', 'matched', 'ramp', 'hold']:
        ledger = route['result'][label]['ledger']
        require(ledger['ok'] is True and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['world_build_count'] == ledger['scene_tree_insertion_count'] == ledger['solver_step_count'] == 0, 'MOTOR_LEDGER')
    launcher = Path(record['launcher_root']); selected = read(launcher / 'selected-stages.json')
    contract = read(verify(record['stage_contract']))
    require([{k:s[k] for k in ['id','pattern','tests']} for s in selected['stages']] == contract['stages']
        and len(contract['stages']) == 41 and selected['test_count'] == contract['total_tests'] == 201
        and sum(selected['discovered_test_counts'].values()) == 201, 'COMPLETE_STAGE_GRAPH')
    for stage in selected['stages']:
        require(stage.get('timeout_seconds', 180) == contract['stage_timeout_overrides_seconds'].get(stage['id'], 180), 'TIMEOUT_BINDING')
    paired = read(launcher / 'paired-declaration.json')
    require(paired['seed'] == 40741 and paired['r10o_development']['seed']['prefix_phase'] == 241
        and paired['r10o_development']['prerequisite_pair'] is None, 'PAIR_DECLARATION')
    for label in ['missing','wrong_count','false_pass','untyped_pass','timeout','missing_first_stage','crossed_pattern','missing_preparation','crossed_preparation_timeout']:
        require(read(launcher / ('prelaunch-' + label + '.execution.json'))['returncode'] == 1
            and 'R10O_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING' in (launcher / ('prelaunch-' + label + '.stderr.txt')).read_text(encoding='utf-8'), 'PRELAUNCH_REFUSAL:' + label)
    require(read(launcher / 'prelaunch-complete.execution.json')['returncode'] == 0, 'COMPLETE_PRELAUNCH')
    for label in ['timeout-zero','timeout-boolean','timeout-too-long','registered-too-long','crossed-long-pattern','crossed-long-count']:
        require(read(launcher / (label + '.execution.json'))['returncode'] == 1
            and 'DEVELOPMENT_STAGE_TIMEOUT_INVALID' in (launcher / (label + '.stderr.txt')).read_text(encoding='utf-8'), 'TIMEOUT_CONTROL')
    require(read(launcher / 'single-without-pair.execution.json')['returncode'] == 1
        and 'SINGLE_REQUIRES_POSITIVE_PAIR' in (launcher / 'single-without-pair.stderr.txt').read_text(encoding='utf-8'), 'PRONE_PREREQUISITE')
    guard = read(Path(record['declaration_root']) / 'godot-result.json')
    require(guard['ok'] is True and len(guard['checks']) == 32 and all(v is True for v in guard['checks'].values())
        and guard['world_build_count'] == guard['solver_step_count'] == guard['sdk_instantiation_count'] == 0, 'NATIVE_SEED_GUARD')
    final = Path(record['attempts'][1]['root'])
    require(binding(final / 'source_files' / record['entry_contract']['path'])['raw_sha256'] == record['entry_contract']['raw_sha256'], 'FINAL_ENTRY_BINDING')
    if current_sources:
        for item in read(verify(record['entry_contract']))['bound_source_files']:
            require(binding(item['path'])['raw_sha256'] == item['raw_sha256'], 'CURRENT_SOURCE:' + item['path'])
        import development_recovery_candidate as candidate
        chosen = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(chosen['diagnostic_schedule']['walking_policy_id'] == 'r10o_v55_partial_fall_recovery_route_v1', 'CURRENT_SELECTION')
    return dict(ok=True, retained_files=len(seen), observed_source_counts=counts, focused_tests_passed=18,
        actual_route_checks=48, actual_seed_guard_checks=32, selected_safety_stages=41, selected_safety_tests=201, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    result = run() if args.run else audit(args.current_sources)
    print('R10O_ROUTE_INTEGRATION ' + json.dumps(result, separators=(',', ':')))
    if args.run:
        raise SystemExit(result['exit_code'])
