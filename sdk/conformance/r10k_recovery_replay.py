"""Read-only audit of cold R10K recovery replay; grants no world authority."""
import argparse
import hashlib
import json
import subprocess

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_recovery_replay_integration_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_recovery_replay_integration_v1', 'REPLAY_SCHEMA')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        recovery_segment_replay_verified=True, complete_report_replay_verified=False,
        complete_production_route_qualified=False, sdk1_score='14/20'), 'REPLAY_CLAIMS')
    verify(record['predecessor_route_record'])
    verify(record['candidate_profile'])
    entry = read(verify(record['entry_contract']))
    binding = read(verify(record['runtime_binding']))
    verify(binding['runtime'])
    paths = set()
    for item in record['retained_evidence']:
        require(item['path'] not in paths, 'REPLAY_DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    base = verify(record['final_source_snapshot']).parent
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes(), 'REPLAY_SOURCE_DRIFT')
    snapshot = read(base / 'source_before.json')
    changed = {item['path']: item for item in snapshot['changed_files']}
    require(snapshot['head'] == record['source_parent_commit'], 'REPLAY_SOURCE_PARENT')
    for item in entry['bound_source_files']:
        relative = item['path']
        if relative in changed:
            digest = changed[relative]['raw_sha256']
        else:
            original = subprocess.check_output(['git', 'show', snapshot['head'] + ':' + relative], cwd=ROOT)
            digest = 'sha256:' + hashlib.sha256(original).hexdigest()
        require(digest == item['raw_sha256'], 'REPLAY_OBSERVED_SOURCE_BINDING:' + relative)
        if current_sources:
            require('sha256:' + hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest, 'REPLAY_CURRENT_SOURCE:' + relative)
    reader_checks = 0
    producer_checks = 0
    for label, counts, checks in [('partial', (240, 0, 63), 17), ('prone', (1, 13, 0), 7), ('legacy', (1, 13, 0), 5)]:
        result = read(base / (label + '.result.json'))
        fixture = read(base / (label + '.fixture.json'))
        require(result['ok'] is True and len(result['checks']) == checks and all(result['checks'].values()), 'REPLAY_CHECKS:' + label)
        require(fixture['ok'] is True and fixture['synthetic_measurements_only'] is True
            and fixture['complete_report_exercised'] is False and all(fixture['checks'].values()), 'REPLAY_PRODUCER:' + label)
        reader_checks += len(result['checks'])
        producer_checks += len(fixture['checks'])
        replay = result['replay']
        require((replay['entry_observation_count'], replay['canonical_observation_count'], replay.get('partial_observation_count', 0)) == counts, 'REPLAY_POPULATION:' + label)
        require(replay['world_build_count'] == replay['native_physics_read_count'] == replay['solver_step_count'] == 0
            and not replay['physical_acceptance_authority'] and not replay['release_authority'], 'REPLAY_AUTHORITY:' + label)
        for side in ['producer', 'reader']:
            execution = read(base / (label + '-' + side + '.execution.json'))
            require(execution['exit_code'] == 0 and 'ERROR:' not in (base / (label + '-' + side + '.stderr.log')).read_text(encoding='utf-8'), 'REPLAY_EXECUTION:' + label + ':' + side)
        if label == 'partial':
            retained = fixture['input']['partial_retention']
            state = fixture['input']['final_state']
            require(replay['canonical_initialization_count'] == 0 and replay['partial_initialization_count'] == 1
                and retained['final_memory']['standing_samples_observed'] == 60 and state['canonical_start_global_step'] is None
                and state['epoch_start_global_step'] == 272 and state['confirm_prone_step_count'] == 0, 'REPLAY_PARTIAL_HISTORY')
        elif label == 'prone':
            state = fixture['input']['final_state']
            require(replay['canonical_initialization_count'] == 1 and replay['partial_initialization_count'] == 0
                and state['confirm_prone_step_count'] == 12 and state['post_kick_recovery_step_count'] == 2, 'REPLAY_PRONE_HISTORY')
    route_file = verify(record['route_result'])
    route = read(route_file)
    route_base = route_file.parent
    require(route['ok'] is True and len(route['checks']) == 45 and all(route['checks'].values())
        and read(route_base / 'execution.json')['exit_code'] == 0
        and 'ERROR:' not in (route_base / 'stderr.log').read_text(encoding='utf-8'), 'REPLAY_ROUTE_CHECKS')
    require((route_base / 'source_before.json').read_bytes() == (route_base / 'source_after.json').read_bytes()
        and (route_base / 'source_before.json').read_bytes() == (base / 'source_before.json').read_bytes(), 'REPLAY_ROUTE_SOURCE_DRIFT')
    if current_sources:
        import development_recovery_candidate as candidate
        selected = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10k_v51_partial_fall_recovery_route_v1', 'REPLAY_ROUTE_SELECTION')
    return dict(ok=True, cold_replay_tests_passed=3, producer_godot_checks=producer_checks,
        reader_godot_checks=reader_checks, route_tests_passed=2, route_godot_checks=45,
        bound_sources=len(entry['bound_source_files']), retained_evidence_files=len(paths),
        current_sources_verified=current_sources, **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    print('R10K_RECOVERY_REPLAY ' + json.dumps(audit(parser.parse_args().current_sources), separators=(',', ':')))
