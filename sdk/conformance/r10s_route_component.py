"""Read-only audit of finite R10S route and upright-segment interface evidence.

The initial source key, its failed ramp fixture, and the corrected source key
remain distinct. This component does not qualify a full report or launcher.
"""
import argparse
import json
from pathlib import Path

import v56_walking_adapter as files

ROOT = files.ROOT
RECORD = ROOT / 'sdk/recovery/r10s_route_component_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10S_ROUTE_COMPONENT_' + code)


def checks(path, count):
    value = files.read(path)
    require(value['ok'] is True and len(value['checks']) == count
        and all(v is True for v in value['checks'].values()), 'CHECKS:' + path.name)
    require(value['world_build_count'] == value['solver_step_count'] == 0
        and value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'CLAIMS')
    return value


def audit(current_sources=False):
    record = files.read(RECORD)
    require(record['schema_version'] == 'sporespore_r10s_route_component_v1'
        and record['status'] == 'route_selection_and_upright_segment_verified_full_report_and_launcher_pending', 'SCHEMA')
    for item in record['retained_evidence']:
        files.verify(item)
    source = files.read(files.verify(record['source_contract']))
    archive = files.read(files.verify(record['initial_source_archive']))
    require(len(archive['files']) == 607 and len(source['bound_source_files']) == 606, 'SOURCE_POPULATION')
    for item in archive['files']:
        files.verify(dict(path=item['archive_path'], byte_length=item['byte_length'], raw_sha256=item['raw_sha256']))
    if current_sources:
        for item in source['bound_source_files'] + record['component_sources']:
            files.verify(item)
        import development_recovery_candidate as candidate
        selected = candidate.selection(candidate.reference_for_path(files.verify(record['candidate_profile'])))
        require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10s_v56_upright_recovery_route_v1'
            and selected['reader'] == 'res://sdk/trace_analysis/r10s_recovery_replay.gd', 'CURRENT_SELECTION')
    initial, repaired = [Path(record[k]) for k in ['initial_run', 'repaired_run']]
    for run, status in [(initial, 1), (repaired, 0)]:
        require(files.read(run / 'execution.json')['exit_code'] == status
            and files.read(run / 'execution.json')['source_unchanged'] is True, 'RUN_STATUS')
        require((run / 'source_before.json').read_bytes() == (run / 'source_after.json').read_bytes(), 'RUN_SOURCE')
        require((run / 'routes/source_before.json').read_bytes() == (run / 'routes/source_after.json').read_bytes(), 'ROUTE_SOURCE')
    negative = files.read(initial / 'routes/routes.json')
    require(negative['ok'] is False and [k for k, v in negative['checks'].items() if v is not True]
        == ['ramp_production_motor_ledger'], 'PRESERVED_INITIAL_REFUSAL')
    routes = checks(repaired / 'routes/routes.json', 50)
    require(files.read(repaired / 'routes/routes.execution.json')['exit_code'] == 0
        and (repaired / 'routes/routes.stderr.log').read_bytes() == b'', 'ROUTE_EXECUTION')
    for label in ['resume', 'matched', 'ramp', 'hold']:
        value = routes['result'][label]
        ledger = value['ledger']
        require(value['start']['ok'] is True and ledger['ok'] is True
            and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['world_build_count'] == ledger['solver_step_count'] == ledger['scene_tree_insertion_count'] == 0, 'ACTUAL_MOTOR_HANDOFF')
    producer = checks(initial / 'routes/producer.json', 23)
    reader = checks(initial / 'routes/reader.json', 21)
    for name in ['producer', 'reader']:
        require(files.read(initial / ('routes/' + name + '.execution.json'))['exit_code'] == 0
            and (initial / ('routes/' + name + '.stderr.log')).read_bytes() == b'', 'SEGMENT_EXECUTION')
    require(producer['synthetic_measurements_only'] is True
        and len(producer['input']['retention']['entry_packets']) == 240
        and len(producer['input']['upright_retention']['step_packets']) == 63
        and producer['input']['upright_retention']['final_memory']['standing_samples_observed'] == 60, 'SYNTHETIC_UPRIGHT_POPULATION')
    require(reader['complete_report_exercised'] is False and reader['replay']['transition_count'] == 304
        and reader['replay']['initial_global_semantic_step'] == 271, 'SEGMENT_SCOPE')
    require(all(reader['checks'][k] is True for k in ['actual_retained_worker_replayed',
        'fabricated_partial_history_refused', 'raise_actual_v12_owner_links',
        'raise_old_v20_owner_refused', 'raise_old_q_step_source_refused']), 'INDEPENDENT_READER')
    schedule = Path(record['schedule_run'])
    rows = [json.loads(line.partition(' ')[2]) for line in (schedule / 'schedule_hooks.stdout.txt').read_text(encoding='utf-8').splitlines()
        if line.startswith('CANDIDATE_SCHEDULE_CHECKS ')]
    require(len(rows) == 1 and rows[0]['ok'] is True and len(rows[0]['checks']) == 66
        and all(v is True for v in rows[0]['checks'].values()), 'SCHEDULE_CHECKS')
    require(rows[0]['limits']['after_interaction_steps'] == 3160
        and rows[0]['limits']['maximum_steps_per_child'] == 3512
        and rows[0]['world_build_count'] == rows[0]['solver_step_count'] == 0, 'SCHEDULE_LIMITS')
    observed = dict(ok=True, route_checks=50, schedule_checks=66, upright_producer_checks=23,
        independent_segment_reader_checks=21, synthetic_entry_packets=240,
        synthetic_upright_packets=63, replayed_segment_transitions=304,
        actual_motor_handoffs=4, source_versions_retained=2,
        world_build_count=0, solver_step_count=0, complete_report_qualified=False,
        complete_safety_gate_qualified=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')
    require(observed == record['observed'], 'OBSERVATION')
    return dict(observed, current_sources_verified=current_sources,
        retained_evidence_files=len(record['retained_evidence']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10S_ROUTE_COMPONENT ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
