"""Read a failed publication's original stdout without repairing that attempt.

Copies the exact terminal JSON token into a separate create-only diagnostic
population and optionally invokes the existing zero-world report reader there.
Never constructs a physics world or synthesizes missing termination metadata.
"""
import argparse
import json
from pathlib import Path
import uuid

import development_passive_entry_profile as entry
import development_rearward_fold_checkpoint as summary

RAW_MARKER = b'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '


def extract(root):
    root = root.resolve()
    entry.require(root.parent == entry.EVIDENCE and root.name.startswith('development-recovery-smoke-'), 'RAW_DIAGNOSTIC_ROOT')
    supervisor = entry.read(root / 'supervisor_result.json')
    declaration = entry.read(root / 'declaration.json')
    entry.require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is True, 'RAW_DIAGNOSTIC_NOT_FAILED_PHYSICAL')
    entry.require(len(declaration['children']) == 1, 'RAW_DIAGNOSTIC_SINGLE_CHILD')
    child = declaration['children'][0]
    child_root = Path(child['evidence_path']).resolve()
    entry.require(child_root.parent == root / 'children', 'RAW_DIAGNOSTIC_CHILD_PATH')
    stdout = child_root / 'worker.stdout.txt'
    raw = stdout.read_bytes()
    matches = [line[len(RAW_MARKER):] for line in raw.splitlines() if line.startswith(RAW_MARKER)]
    entry.require(len(matches) == 1, 'RAW_DIAGNOSTIC_SINGLE_TERMINAL_MARKER')
    token = matches[0]
    report = entry.packet.parse_json(token.decode('utf-8'))
    entry.require(report.get('parent_attempt_id') == root.name.removeprefix('development-recovery-smoke-')
                  and report.get('child_attempt_id') == child['child_attempt_id']
                  and report.get('source_commit') == supervisor['source_snapshot']['head'], 'RAW_DIAGNOSTIC_IDENTITY')
    entry.require(entry.packet.same(report.get('candidate_profile'), declaration.get('candidate_profile')), 'RAW_DIAGNOSTIC_PROFILE')
    entry.require(report.get('physical_acceptance_authority') is False and report.get('release_authority') is False, 'RAW_DIAGNOSTIC_AUTHORITY')
    return supervisor, declaration, stdout, token, report


def run(root, replay=False):
    source = entry._source_snapshot()
    supervisor, declaration, stdout, token, report = extract(root)
    population = entry.EVIDENCE / ('development-recovery-raw-stdout-diagnostic-' + uuid.uuid4().hex)
    population.mkdir()
    print('RAW_STDOUT_DIAGNOSTIC_ROOT ' + str(population), flush=True)
    report_path = population / 'worker_report.json'
    with report_path.open('xb') as stream:
        stream.write(token)  # Exact bytes after the original marker, no float reserialization.
    with (population / 'source_snapshot.json').open('xb') as stream:
        stream.write(json.dumps(source, separators=(',', ':')).encode())
    receipt = dict(schema_version='sporespore_development_raw_stdout_diagnostic_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='post_exposure_raw_stdout_diagnostic', question_class='development'),
        source_stdout=entry.runtime.file_identity(stdout),
        original_supervisor=entry.runtime.file_identity(root / 'supervisor_result.json'),
        original_failure_code=supervisor['failure_code'],
        extracted_report=entry.runtime.file_identity(report_path),
        source_snapshot_binding=entry.runtime.file_identity(population / 'source_snapshot.json'),
        original_attempt_reclassified=False, original_missing_publication_reconstructed=False,
        original_termination_protocol_proven=False, original_complete_route_proven=False,
        replay_requested=replay, replay=None, replay_failure=None,
        reported_solver_step_count=report.get('solver_step_count'),
        reported_stop_reason=report.get('stop_reason'),
        reported_ok=report.get('ok'), reported_measurement_complete=report.get('measurement_complete'),
        descriptive_metrics=None, new_world_build_count=0, new_native_physics_read_count=0,
        new_solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    try:
        if replay:
            receipt['replay'] = entry.run_replay(report_path)
        if report.get('retained_arm'):
            receipt['descriptive_metrics'] = summary.summarize(report,
                source_commit=supervisor['source_snapshot']['head'],
                profile_path=declaration['candidate_profile']['resource'].removeprefix('res://'))
            packets = report['passive_entry']['canonical_packets']
            stable = [p['global_semantic_step'] for p in packets if p['step_receipt']['classification']['stable_stance_gate']]
            receipt['stable_global_steps'] = stable
            receipt['maximum_consecutive_stance_dwell_count'] = max(p['step_receipt']['memory']['stance_dwell_steps_observed'] for p in packets)
    except (ValueError, OSError, KeyError, TypeError) as error:
        receipt['replay_failure'] = str(error)
    receipt['source_unchanged_during_diagnostic'] = entry.packet.same(source, entry._source_snapshot())
    receipt['original_stdout_unchanged'] = entry.packet.same(receipt['source_stdout'], entry.runtime.file_identity(stdout))
    with (population / 'diagnostic.json').open('xb') as stream:
        stream.write(json.dumps(receipt, indent=2, allow_nan=False).encode())
    print(json.dumps(receipt, separators=(',', ':'), allow_nan=False))
    entry.require(receipt['replay_failure'] is None and receipt['source_unchanged_during_diagnostic']
                  and receipt['original_stdout_unchanged'], 'RAW_DIAGNOSTIC_FAILED')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    parser.add_argument('--replay', action='store_true', help='One fresh read-only replay of the separately extracted report')
    args = parser.parse_args()
    run(args.root.resolve(), args.replay)
