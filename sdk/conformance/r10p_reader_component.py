"""Retained R10P reader validation. --create runs three cold zero-world replays.

The caller owns the locomotion operation lock. Originals are only read. Each
native replay and each Python measurement receives a separate durable receipt.
Default mode reconstructs the closure without launching another replay process.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

import development_passive_entry_profile as replay
import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import r10p_finite_task_audit as reader
from v52_extended_support_transfer import ROOT, binding, read, verify

sys.path.insert(0, str(ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore

EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RECORD = ROOT / 'sdk/recovery/r10p_consecutive_prone_reader_component_v1.json'
PREDECESSORS = ['sdk/recovery/r10o_phase241_development_pair_closure_v1.json',
                'sdk/recovery/r10o_phase243_prone_counter_diagnosis_v1.json']
SOURCES = ['sdk/conformance/r10p_reader_component.py', 'sdk/conformance/r10p_finite_task_audit.py',
           'sdk/recovery/r10p_consecutive_prone_completion_reader_contract_v1.json',
           'tests/test_r10p_finite_task_audit.py']


def require(value, code):
    if not value:
        raise ValueError('R10P_READER_COMPONENT_' + code)


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def identity(report, checkpoint, cell, runtime):
    observed = dict(source_commit=report['source_commit'], parent_attempt_id=report['parent_attempt_id'],
        child_attempt_id=report['child_attempt_id'], role=report['arm_id'],
        candidate_profile=report['candidate_profile'], task_contract_sha256=report['stance_entry']['task_contract_sha256'],
        runtime_raw_sha256=runtime['raw_sha256'])
    expected = dict(source_commit=checkpoint['source_snapshot']['head'], parent_attempt_id=checkpoint['attempt_id'],
        child_attempt_id=cell['child_attempt_id'], role=cell['role'],
        candidate_profile=checkpoint['observed']['r10o_finite_development']['candidate_profile'],
        task_contract_sha256=reader.contract()['physical_task_contract_sha256'],
        runtime_raw_sha256=reader.contract()['native_dll_sha256'])
    validate_identity(observed, expected)
    return observed, expected


def validate_identity(observed, expected):
    require(packet.same(observed, expected), 'INPUT_IDENTITY')


def identity_controls(observed, expected):
    results = []
    for key in expected:
        changed = copy.deepcopy(observed)
        changed[key] = 'crossed-' + key
        try:
            validate_identity(changed, expected)
        except ValueError as error:
            results.append(dict(field=key, refused=True, error=str(error)))
        else:
            raise ValueError('R10P_READER_COMPONENT_CONTROL_ACCEPTED:' + key)
    return results


def compare_measurements(original, fresh, kind):
    require(fresh['schema_version'] == reader.SCHEMA
            and fresh['reader_contract_sha256'] == 'sha256:' + reader.CONTRACT_SHA, 'NEW_READER_IDENTITY')
    normalized = copy.deepcopy(fresh)
    normalized['schema_version'] = original['schema_version']
    normalized.pop('reader_contract_sha256')
    if kind == 'prone':
        detail = normalized.pop('prone_completion')
        require(detail['passed'] is True and detail['elapsed_steps'] == 14
                and detail['consecutive_samples'] == 12, 'EXPOSED_COUNTER_MEASUREMENT')
        require(normalized['predicates']['recovery_completed'] is True
                and original['predicates']['recovery_completed'] is False, 'DECLARED_PRONE_DIFFERENCE')
        normalized['predicates']['recovery_completed'] = original['predicates']['recovery_completed']
        normalized['finite_task_predicates_passed'] = original['finite_task_predicates_passed']
    require(packet.same(normalized, original), 'UNDECLARED_MEASUREMENT_CHANGE')


def validate_originals():
    output = []
    for relative in PREDECESSORS:
        closure = read(ROOT / relative)
        root = Path(closure['evidence_root'])
        # Reconstruct complete original launch, role, source, invariant and
        # publication checks. Their old results must remain byte-bound negatives
        # or positives exactly as originally retained.
        observed = smoke.retained_checkpoint(root)
        require(packet.same(observed, closure['retained_checkpoint']), 'ORIGINAL_CHECKPOINT')
        for item in closure['retained_evidence']:
            verify(item)
        output.append((closure, observed))
        print('R10P_ORIGINAL_VERIFIED ' + observed['attempt_id'], flush=True)
    return output


def source_files():
    return [binding(path) for path in SOURCES]


def reconstruct(run, *, create=False):
    reader.contract()
    sources = source_files()
    if not create:
        require(packet.same(sources, run['source_bindings']), 'COMPONENT_SOURCE_DRIFT')
        for item in run['retained_evidence']:
            verify(item)
    original_results = validate_originals()
    directory = Path(run['evidence_root'])
    require(directory.parent == EVIDENCE and directory.name == 'r10p-reader-component-' + run['attempt_id'], 'EVIDENCE_ROOT')
    source_snapshot = replay._source_snapshot() if create else read(directory / 'source_snapshot.json')
    if create:
        write(directory / 'source_snapshot.json', source_snapshot)
    cells = []
    slot = 0
    for closure, checkpoint in original_results:
        original = checkpoint['observed']['r10o_finite_development']
        for cell in original['cells']:
            report_path = Path(closure['evidence_root']) / 'children' / cell['role'] / 'worker_report.json'
            report = read(report_path)
            chosen = replay.selection_for_report(report)
            runtime = replay.binding(chosen)['runtime']
            require(packet.same(replay.runtime.file_identity(Path(runtime['path'])), runtime), 'RUNTIME_FILE')
            observed_id, expected_id = identity(report, checkpoint, cell, runtime)
            diagnostic = (EVIDENCE / ('development-passive-entry-post-exposure-replay-' + uuid.uuid4().hex)
                          if create else Path(run['cells'][slot]['replay_directory']))
            print('R10P_REPLAY ' + str(slot) + ' ' + cell['role'], flush=True)
            # The native replay has zero worlds/steps and validates original
            # counter transitions against the unchanged DLL and orchestrator.
            native = (replay.run_replay if create else replay.consume_replay)(report_path, diagnostic_directory=diagnostic)
            core = LocomotionCore(runtime['path'])
            compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
            previous = reader.prior.measure(report, compiled)
            require(packet.same(previous, cell['measurement']), 'OLD_READER_RESULT')
            fresh = reader.measure(report, compiled)
            compare_measurements(previous, fresh, cell['entry_kind'])
            require(fresh['finite_task_predicates_passed'] is True, 'NEW_MEASUREMENT_NEGATIVE')
            result = dict(input_identity=observed_id, input_binding=binding(report_path),
                native_replay=native, replay_directory=diagnostic.as_posix(),
                original_measurement=previous, r10p_measurement=fresh,
                original_attempt_reclassified=False, world_build_count=0, solver_step_count=0,
                physical_acceptance_authority=False, release_authority=False)
            receipt_path = directory / ('reader_result_' + str(slot) + '.json')
            if create:
                write(receipt_path, dict(result=result, source_snapshot_binding=binding(directory / 'source_snapshot.json'),
                    source_bindings=sources, python_process_id=os.getpid(), python_image=binding(Path(sys.executable))))
            receipt = read(receipt_path)
            require(packet.same(receipt['result'], result) and packet.same(receipt['source_bindings'], sources)
                and packet.same(receipt['source_snapshot_binding'], binding(directory / 'source_snapshot.json')),
                'READER_PUBLICATION')
            require(type(receipt['python_process_id']) is int and receipt['python_process_id'] > 0
                and receipt['python_image'] == binding(Path(sys.executable)), 'READER_PROCESS')
            cells.append(dict(result, reader_receipt=binding(receipt_path), binding_controls=identity_controls(observed_id, expected_id)))
            del report
            slot += 1
            print('R10P_MEASURED ' + str(slot) + ' original=' + str(previous['finite_task_predicates_passed'])
                  + ' successor=' + str(fresh['finite_task_predicates_passed']), flush=True)
    require(slot == 3, 'THREE_EXPOSED_REPORTS')
    if create:
        require(packet.same(source_snapshot, replay._source_snapshot()), 'SOURCE_CHANGED_DURING_RUN')
    retained = [binding(path) for path in sorted(directory.rglob('*')) if path.is_file()]
    for cell in cells:
        retained += [binding(path) for path in sorted(Path(cell['replay_directory']).rglob('*')) if path.is_file()]
    return dict(schema_version='sporespore_r10p_consecutive_prone_reader_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='post_exposure_reader_component_validation', question_class='development'),
        status='verified_post_exposure_reader_component', attempt_id=run['attempt_id'],
        evidence_root=directory.as_posix(), source_bindings=sources,
        predecessor_bindings=[binding(path) for path in PREDECESSORS],
        counter_tests=run['counter_tests'], cells=cells, retained_evidence=retained,
        claim_boundary=dict(original_results_preserved=True, original_attempt_reclassified=False,
            changed_no_kick_or_partial_measurements=False, physical_producer_changed=False,
            new_world_count=0, new_solver_step_count=0, held_out_population_selected=False,
            physical_execution_authorized=False, physical_acceptance_authority=False,
            release_authority=False, sdk1_score='14/20'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    if args.create:
        require(not RECORD.exists(), 'COMPONENT_ALREADY_CLOSED')
        attempt = uuid.uuid4().hex
        directory = EVIDENCE / ('r10p-reader-component-' + attempt)
        directory.mkdir()
        command = [sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_r10p_finite_task_audit.py', '-v']
        test = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120)
        for name, raw in (('tests.stdout.txt', test.stdout), ('tests.stderr.txt', test.stderr)):
            with (directory / name).open('xb') as stream:
                stream.write(raw)
        require(test.returncode == 0 and b'Ran 8 tests' in test.stderr and test.stderr.rstrip().endswith(b'OK'), 'COUNTER_TESTS')
        run = dict(attempt_id=attempt, evidence_root=directory.as_posix(),
            counter_tests=dict(command=command, exit_code=test.returncode, test_count=8,
                               stdout=binding(directory / 'tests.stdout.txt'), stderr=binding(directory / 'tests.stderr.txt')))
        # Retain the intended execution even if a later replay or audit refuses.
        write(directory / 'declaration.json', run)
    else:
        run = read(RECORD)
        require(run['counter_tests']['test_count'] == 8 and run['counter_tests']['exit_code'] == 0, 'COUNTER_TEST_RECEIPT')
    result = reconstruct(run, create=args.create)
    if args.create:
        write(RECORD, result)
    else:
        require(packet.same(result, run), 'COMPONENT_RECONSTRUCTION')
    print(json.dumps(dict(ok=True, retained_reports=3, counter_tests=8,
        original_positive=[cell['original_measurement']['finite_task_predicates_passed'] for cell in result['cells']],
        r10p_positive=[cell['r10p_measurement']['finite_task_predicates_passed'] for cell in result['cells']],
        original_attempt_reclassified=False, new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
