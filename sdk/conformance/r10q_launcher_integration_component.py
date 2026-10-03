"""Verify R10Q launcher integration and retained refusals, without physical claims."""
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10q_launcher_integration_component_v1.json'
def read(path): return json.loads(Path(path).read_bytes())
def sha(path): return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()
def require(value, code):
    if not value: raise ValueError('R10Q_LAUNCHER_INTEGRATION_' + code)
def verify(item):
    p = Path(item['path'])
    if not p.is_absolute(): p = ROOT / p
    require(p.is_file() and sha(p) == item['raw_sha256'], 'BYTES:' + item['path'])
    return p
def check_streams(root, stage):
    for stream in ('stdout', 'stderr'):
        require(stage[stream] == stage['id'] + '.' + stream + '.log' and
                sha(root / stage[stream]) == 'sha256:' + stage[stream + '_sha256'], 'STAGE_STREAM')
def audit(record):
    require(record['schema_version'] == 'sporespore_r10q_launcher_integration_component_v1', 'SCHEMA')
    for item in record['bindings'].values(): verify(item)
    for item in record['retained_files']: verify(item)
    contract = read(verify(record['bindings']['source_contract']))
    for item in contract['bound_source_files']: verify(item)
    runtime = read(verify(record['bindings']['runtime_binding']))
    for item in runtime['source_files']: verify(item)
    verify(runtime['runtime']); verify(runtime['compiled_fixtures'])
    stage_contract = read(verify(record['bindings']['stage_contract']))
    require(stage_contract['schema_version'] == 'sporespore_r10q_safety_stage_contract_v3' and
            len(stage_contract['stages']) == 39 and sum(s['tests'] for s in stage_contract['stages']) == 184, 'DECLARED_POPULATION')
    for name, failure in [('runtime_gate', 'candidate_runtime'), ('frame_gate', 'candidate_walking_frame')]:
        root = Path(record['runs'][name])
        result = read(root / 'supervisor_result.json')
        require(result['ok'] is False and result['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:' + failure and
                result['physical_attempt_started'] is False and result['children'] == [], 'ORIGINAL_REFUSAL')
        for stage in result['safety_stages']: check_streams(root, stage)
    frame = read(Path(record['runs']['frame_gate']) / 'supervisor_result.json')
    require(len(frame['safety_stages']) == 37 and all(s['passed'] is True for s in frame['safety_stages'][:36]) and
            frame['safety_stages'][-1]['passed'] is False, 'FRAME_GATE_POPULATION')
    completed = []
    for name in ('focused_initial', 'focused_boundaries', 'focused_contacts', 'focused_final'):
        root = Path(record['runs'][name])
        require(read(root / 'source_before.json') == read(root / 'source_after.json'), 'DIAGNOSTIC_SOURCE_DRIFT')
        for path in root.glob('*.result.json'):
            stage = read(path); check_streams(root, stage)
            if name == 'focused_initial' and stage['id'] == 'candidate_schedule':
                require(stage['passed'] is False and stage['test_count'] == 4, 'ORIGINAL_SCHEDULE_REFUSAL')
            else:
                require(stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0 and
                        stage['test_count'] == stage['expected_test_count'], 'FOCUSED_RESULT')
            if name == 'focused_final': completed.append((stage['id'], stage['test_count']))
    require(sorted(completed) == [('candidate_profile', 5), ('candidate_walking_frame', 4)], 'FINAL_POPULATION')
    for archive in record['source_archives']:
        inventory = read(verify(archive['inventory']))
        for item in inventory['files']:
            require(sha(Path(archive['root']) / item['path']) == item['raw_sha256'], 'SOURCE_ARCHIVE')
    claims = record['claim_boundary']
    require(claims == dict(world_build_count=0, solver_step_count=0, launcher_integrated=True,
        complete_current_safety_gate_passed=False, successor_physics_observed=False,
        physical_acceptance_authority=False, release_authority=False, original_results_regraded=False,
        sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, declared_safety_stages=39, declared_tests=184, final_launcher_and_frame_tests=9,
        bound_route_sources=len(contract['bound_source_files']), compiled_sources=len(runtime['source_files']),
        retained_refusals_and_source_archives_verified=True, **claims)
if __name__ == '__main__':
    print('R10Q_LAUNCHER_INTEGRATION_COMPONENT ' + json.dumps(audit(read(RECORD)), separators=(',', ':')))
