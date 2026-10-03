"""Fresh, bounded post-exposure replay of the consumed R10H pair; zero worlds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

import development_passive_entry_profile as entry
import qsdk_r10f_l15_collection_retention as packet

ROOT = entry.ROOT
EVIDENCE = entry.EVIDENCE
ATTEMPT = EVIDENCE / 'development-recovery-smoke-0259ba28cec14f388917500243bc933b'
READER = 'res://sdk/trace_analysis/recovery_stance_entry_retained_replay.gd'
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')


def identity(path):
    with path.open('rb') as stream:
        sha = hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256='sha256:'+sha)


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def selection_for_retained_report(report):
    """Audit frozen data against its immutable profile, not a newer source tree."""
    reference = report['candidate_profile']
    profile_path = entry.candidate_profile.resource_path(reference['resource'])
    entry.require(identity(profile_path)['raw_sha256'] == reference['raw_sha256'], 'RETAINED_PROFILE_DRIFT')
    profile = entry.read(profile_path)
    binding_path = entry.candidate_profile.resource_path(profile['runtime_binding'])
    entry.require(identity(binding_path)['raw_sha256'] == profile['runtime_binding_sha256'], 'RETAINED_RUNTIME_BINDING_DRIFT')
    binding = entry.read(binding_path)
    entry.require(identity(Path(binding['runtime']['path']))['raw_sha256'] == profile['runtime_sha256'], 'RETAINED_DLL_DRIFT')
    return dict(candidate_profile=reference, reader=READER,
        replay_receipt_schema='sporespore_development_recovery_candidate_replay_receipt_v1',
        worker_selection=dict(binding=profile['runtime_binding']))


def consume(directory):
    execution = entry.read(directory / 'execution.json')
    original = entry.read(directory / 'original_inventory.json')
    for bound in original:
        entry.require(packet.same(identity(Path(bound['path'])), bound), 'ORIGINAL_FILE_CHANGED')
    entry.require(execution['returncode'] == 0 and not execution['timed_out'], 'RETAINED_PROCESS_FAILED')
    entry.require(execution['source_unchanged'], 'RETAINED_SOURCE_DRIFT')
    for name in ('stdout.txt', 'stderr.txt', 'source_snapshot.json'):
        entry.require(packet.same(identity(directory / name), execution['bindings'][name]), 'RETAINED_OUTPUT_BINDING')
    stdout = (directory / 'stdout.txt').read_text(encoding='utf-8')
    stderr = (directory / 'stderr.txt').read_text(encoding='utf-8')
    entry.require('ERROR:' not in stdout+stderr, 'RETAINED_SCRIPT_ERROR')
    marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    rows = [packet.parse_json(line[len(marker):]) for line in stdout.splitlines() if line.startswith(marker)]
    entry.require(len(rows) == 1, 'RETAINED_MARKER')
    result = rows[0]
    report_path = ATTEMPT / 'children' / execution['role'] / 'worker_report.json'
    report = entry.read(report_path)
    chosen = selection_for_retained_report(report)
    entry.require(packet.same(execution['command'], entry._command(report_path, dict(chosen, reader=READER))), 'RETAINED_COMMAND')
    entry.require(packet.same(execution['engine_image'], entry.runtime.IMAGES['godot_engine'])
        and execution['timeout_seconds'] == 900, 'RETAINED_ENGINE_OR_BOUND')
    expected = dict(schema_version=chosen['replay_receipt_schema'], ok=True,
        complete_report_timeline_replayed=True, initial_global_semantic_step=0,
        transition_count=report['solver_step_count'], final_global_semantic_step=report['solver_step_count'],
        final_state_sha256=report['retained_arm']['orchestrator_state']['payload_sha256'],
        process_id=execution['process_id'],
        input_raw_sha256=identity(report_path)['raw_sha256'], runtime_raw_sha256=entry.binding(chosen)['runtime']['raw_sha256'],
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        complete_route_proven=False, physical_acceptance_authority=False, release_authority=False)
    for key, value in expected.items():
        entry.require(packet.same(result.get(key), value), 'RETAINED_'+key)
    correction = result.get('post_exposure_reader', {})
    entry.require(correction.get('profile_id') in ('r10h_original_compilation_and_handoff_location_v1',
        'r10h_original_transport_handoff_and_resume_phase_v2')
        and correction.get('original_attempt_reclassified') is False
        and correction.get('readiness_tolerance_added') is False, 'RETAINED_CORRECTION_IDENTITY')
    retained = report['stance_entry']
    stance = result['stance_entry_replay']
    entry.require(stance['replayed_neutral_commands'] == len(retained['neutral_control_rows'])
        and stance['recomputed_readiness_samples'] == len(retained['readiness_rows']), 'RETAINED_ENTRY_POPULATION')
    entry.require(packet.same(result['finite_recovery_task'], report['finite_recovery_task']), 'RETAINED_TASK')
    sys.path.insert(0, str(ROOT / 'sdk/python'))
    from sporespore_locomotion import LocomotionCore
    import finite_recovery_walking
    core = LocomotionCore(entry.binding(chosen)['runtime']['path'])
    compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
    task = entry.read(ROOT / 'sdk/recovery/r10h_stance_entry_finite_cycle_contract_v1.json')
    result['stance_entry_independent_measurement'] = entry.verify_entry_measurements(retained['readiness_rows'], compiled, task['stance_entry'])
    result['finite_walking_measurement'] = (finite_recovery_walking.measure(report, compiled, task)
        if report.get('development_walking_entry', {}).get('rows') else dict(status='walking_not_reached'))
    result['ledger_scope']['authority_mode'] = 'post_exposure_retained_report_replay'
    result.update(original_attempt_reclassified=False, role=execution['role'],
        diagnostic_directory=directory.as_posix(), process_receipt=identity(directory / 'execution.json'))
    return result


def run(role):
    directory = EVIDENCE / ('r10h-stance-entry-retained-replay-'+uuid.uuid4().hex)
    directory.mkdir()
    write(directory / 'original_inventory.json', [identity(p) for p in sorted(ATTEMPT.rglob('*')) if p.is_file()])
    source = entry._source_snapshot()
    write(directory / 'source_snapshot.json', source)
    report_path = ATTEMPT / 'children' / role / 'worker_report.json'
    report = entry.read(report_path)
    chosen = entry.selection_for_report(report)
    command = entry._command(report_path, dict(chosen, reader=READER))
    image = entry.runtime.IMAGES['godot_engine']
    entry.require(packet.same(entry.runtime.file_identity(Path(image['path'])), image), 'RETAINED_ENGINE_DRIFT')
    environment = {k: v for k, v in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')}
    started = time.monotonic()
    timed_out = False
    with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          env=environment, creationflags=subprocess.CREATE_NO_WINDOW) as process:
        try:
            stdout, stderr = process.communicate(timeout=900)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            stdout, stderr = process.communicate()
    for name, raw in [('stdout.txt', stdout), ('stderr.txt', stderr)]:
        with (directory / name).open('xb') as stream:
            stream.write(raw)
    write(directory / 'execution.json', dict(schema_version='sporespore_r10h_post_exposure_reader_execution_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_report_replay', question_class='development'),
        role=role, command=command, engine_image=image, process_id=process.pid, returncode=process.returncode,
        elapsed_seconds=time.monotonic()-started, timeout_seconds=900, timed_out=timed_out,
        source_unchanged=packet.same(source, entry._source_snapshot()), original_attempt_reclassified=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False,
        bindings={name: identity(directory / name) for name in ('stdout.txt', 'stderr.txt', 'source_snapshot.json')}))
    print('R10H_RETAINED_REPLAY_ROOT', directory, flush=True)
    try:
        result = consume(directory)
    except (ValueError, KeyError, TypeError, OSError) as error:
        result = dict(ok=False, failure_code=str(error), original_attempt_reclassified=False,
                      physical_acceptance_authority=False, release_authority=False)
    write(directory / 'result.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--role', choices=ROLES)
    parser.add_argument('--consume', type=Path)
    args = parser.parse_args()
    if bool(args.role) == bool(args.consume):
        parser.error('Choose one fresh role replay or one retained directory to consume')
    result = run(args.role) if args.role else consume(args.consume.resolve())
    print(json.dumps(result, separators=(',', ':'), allow_nan=False))
    raise SystemExit(0 if result.get('ok') is True else 1)
