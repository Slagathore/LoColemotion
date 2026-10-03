"""Read-only audit of the V52 native component on retained, exposed inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/v52_extended_support_transfer_component_v1.json'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def require(ok, code):
    if not ok:
        raise ValueError('V52_COMPONENT_' + code)


def binding(path):
    path = Path(path)
    actual = path if path.is_absolute() else ROOT / path
    raw = actual.read_bytes()
    return dict(path=path.as_posix(), byte_length=len(raw), raw_sha256='sha256:' + hashlib.sha256(raw).hexdigest())


def verify(item):
    require(binding(item['path']) == item, 'FILE_DRIFT:' + item['path'])
    path = Path(item['path'])
    return path if path.is_absolute() else ROOT / path


def fixture_rows(item):
    text = verify(item).read_text(encoding='utf-8')
    marker = 'CANDIDATE_RECOVERY_CONTROL_FIXTURE '
    return sorted(line.split(marker, 1)[1] for line in text.splitlines() if marker in line)


def audit(current_sources=False):
    r = read(RECORD)
    require(r['schema_version'] == 'sporespore_v52_extended_support_transfer_component_v1', 'SCHEMA')
    require(r['status'] == 'native_component_verified_full_route_pending', 'STATUS')
    require(r['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        production_route_integrated=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'CLAIMS')
    design = read(verify(r['design']))
    require(design['sdk1_milestone_id'] == 'SDK1-M07', 'DESIGN')
    build = read(verify(r['runtime_binding']))
    verify(r['runtime'])
    require(build['runtime'] == r['runtime'] and build['core_test_count'] == 385
        and len(build['source_files']) == 92 and all(v['exit_code'] == 0 for v in build['build_stages']), 'BUILD')
    for item in build['build_evidence_files']:
        verify(item)
    previous = read(verify(r['predecessor_runtime_binding']))
    old_rows, new_rows = fixture_rows(previous['compiled_fixtures']), fixture_rows(build['compiled_fixtures'])
    require(len(new_rows) == 6 and new_rows == old_rows, 'RECOVERY_FIXTURE_BYTES')
    if current_sources:
        for item in r['source_files'] + build['source_files']:
            verify(item)
    paths = set()
    for item in r['retained_evidence']:
        require(item['path'] not in paths, 'DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    evidence = verify(r['execution']).parent
    completion = read(evidence / 'execution.json')
    require(completion['exit_code'] == 0 and 'sha256:' + completion['runtime_sha256'] == r['runtime']['raw_sha256'], 'EXECUTION')
    test_source = next(v for v in r['source_files'] if v['path'] == 'tests/test_development_v52_extended_support_transfer.py')
    require(test_source['raw_sha256'] == 'sha256:' + completion['test_source_sha256'], 'TEST_SOURCE')
    require(re.search(r'Ran 6 tests in .*\n\nOK\s*$', (evidence / 'stderr.log').read_text(encoding='utf-8')) is not None, 'TEST_COUNT')
    identity = read(evidence / 'policy-identity.json')
    parent, profile = identity['parent'], identity['profile']
    require(profile['policy_id'] == 'sporespore_balanced_wave_recovery_extended_support_transfer_v1'
        and profile['schema_version'] == 'sporespore_balanced_wave_recovery_extended_support_transfer_profile_v1'
        and {k:v for k,v in parent.items() if k not in ('policy_id','schema_version')}
        == {k:v for k,v in profile.items() if k not in ('policy_id','schema_version')}, 'PROFILE')
    compat = read(evidence / 'v51-byte-compatibility.json')
    verify(compat['source'])
    require(compat['completed_commands'] == 839 and compat['original_refusal_reproduced'] is True
        and compat['original_attempt_reclassified'] is False, 'PREDECESSOR_BYTES')
    chain = read(evidence / 'counterfactual-native-chain.json')
    require(chain['commands'] == 839 and chain['stateless_session_equal'] is True
        and chain['minimum_bias_rad'] == -0.30 and chain['minimum_height_correction_m'] == -0.01375
        and chain['final_memory']['measured_support_transfer']['preparation_commands'] == 240
        and chain['world_build_count'] == chain['solver_step_count'] == 0
        and chain['physical_acceptance_authority'] is False and chain['release_authority'] is False, 'COPIED_INPUT_CHAIN')
    for name in ['predeadline-reference.json', 'unchanged-deadline.json']:
        row = read(evidence / name)
        require('sha256:' + hashlib.sha256(row['raw_response_utf8'].encode()).hexdigest() == row['raw_response_sha256'], 'RAW_RESPONSE')
        response = json.loads(row['raw_response_utf8'])['value']
        memory = row['request']['memory']
        require(row['world_build_count'] == row['solver_step_count'] == 0, 'NO_WORLD')
        if name == 'unchanged-deadline.json':
            actuation = response['actuation']
            require(memory['measured_support_transfer']['preparation_commands'] == 240
                and response['next_memory'] == memory and actuation['safe_no_actuation'] is True
                and all(v['target_velocity_rad_s'] == 0 for v in actuation['ordered_commands'])
                and actuation['receipt']['controller_error'] == 'FRAME_INVALID:measured_support_transfer_preparation_timeout', 'DEADLINE')
        else:
            plane = response['actuation']['receipt']['recovery_support_plane']
            transfer = plane['measured_support_transfer']
            height = plane['anchored_body_pose']['joint_feasible_height']
            require(response['actuation']['safe_no_actuation'] is False
                and memory['measured_support_transfer']['preparation_commands'] < 240
                and transfer['maximum_absolute_reference_bias_rad'] == 0.30
                and -0.30 <= transfer['next_memory']['hip_bias_rad'] < -0.25
                and transfer['next_memory']['preparation_commands'] == memory['measured_support_transfer']['preparation_commands'] + 1
                and transfer['preparation_released_this_command'] is False
                and all(v >= height['required_reach_reserve_m'] for v in height['ordered_reach_reserves_m']), 'EXTENDED_REFERENCE')
    controls = read(evidence / 'negative-controls.json')['controls']
    require([v['mutation'] for v in controls] == ['parent_memory','bias_low','bias_high','clock','height','geometry','parent_range']
        and all(v['error'] for v in controls), 'NEGATIVE_CONTROLS')
    return dict(ok=True, core_tests_passed=385, native_component_tests_passed=6,
        predecessor_walking_responses_byte_exact=840, original_recovery_fixture_rows_byte_exact=6,
        copied_input_chain_commands=839, negative_controls=7, current_sources_verified=current_sources,
        retained_evidence_files=len(paths), **r['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('V52_EXTENDED_SUPPORT_TRANSFER ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
