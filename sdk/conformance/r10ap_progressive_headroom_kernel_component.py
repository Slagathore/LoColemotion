"""Prepare and audit R10AP's compiled kernel; test mode is portable zero-world.

Successful and failed test attempts retain their exact source bytes. Historical
build provenance therefore survives later additive native-composition work.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import tomllib
import uuid
import zipfile

import r10ao_progressive_headroom_study as model

C, G = model.C, model.G
ROOT, EVIDENCE = C.ROOT, C.EVIDENCE
CONTRACT = ROOT/'sdk/recovery/r10ap_progressive_headroom_kernel_contract_v1.json'
INPUTS = ROOT/'sdk/core/contracts/r10ap_retained_canonical_geometry_input_binding_v1.json'
RECORD = ROOT/'sdk/recovery/r10ap_progressive_headroom_kernel_component_v1.json'
CARGO = Path('C:/Users/Cole/.cargo/bin/cargo.exe')
FAILED = EVIDENCE/'r10ap-kernel-release-db33019d15764470a3d4c2d56335caf1'
PRELIMINARY = EVIDENCE/'r10ap-kernel-release-fe5c8492d8bf4a608d7e08f5c202f194'
CLAIMS = dict(mathematical_kernel_implemented=True, native_composition_integrated=False,
    complete_safety_gate_qualified=False, new_physical_population_declared=False,
    original_result_regraded=False, physical_recovery_obtained=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def source_rows():
    declaration = C.read(CONTRACT)
    for item in declaration['dependencies']:
        assert C.bind(item['path']) == item
    assert C.bind(C.CHILD/'worker_report.json') == declaration['population']['source_report']
    original = C.read(model.RESULT)
    descriptor = C.streams.small_fields(C.CHILD/'worker_report.json')['configuration']['base_descriptor']
    rows = []
    for packet in G.records(C.CHILD/'worker_report.json', 'r10am_partial_recovery', 'step_packets'):
        plan = packet['native_receipt']['next_load_plan']
        if plan is None:
            continue
        request = json.loads(packet['call']['request']['utf8_text'])
        observation = request['step']['observation']
        assert observation['schema_version'] == 'sporespore_recovery_observation_v3'
        assert request['collection']['descriptor'] == descriptor
        # The collection receipt projects V3 to V2. Preserve the original V3
        # energy ledger for Rust admission; only its geometric fields coincide.
        collected = packet['native_receipt']['collection']['observation']
        assert {k: v for k, v in observation.items() if k not in ('schema_version', 'energy_balance')} == {
            k: v for k, v in collected.items() if k not in ('schema_version', 'energy_balance')}
        observed = original['rows'][len(rows)]
        assert observed['semantic_step'] == observation['semantic_step']
        expected = {k: v for k, v in observed.items() if k not in ('semantic_step', 'input_joints', 'positive_bearing')}
        assert expected == model.search(model.M.G.Model(observation, descriptor))
        rows.append(dict(observation=observation, expected=expected,
            source_observation_sha256=plan['source_observation_sha256'],
            v23_fallback_targets=plan['baseline_reference']['baseline_reference']['ordered_target_positions_rad']))
    assert len(rows) == 600
    return dict(schema_version='sporespore_r10ap_canonical_geometry_inputs_v1', descriptor=descriptor,
        source_report=declaration['population']['source_report'], independent_result=C.bind(model.RESULT),
        source_form='original_v3_step_observation', terminal_inputs=0, observations=rows)


def prepare():
    assert not INPUTS.exists()
    fixture = source_rows()
    folder = EVIDENCE/('r10ap-kernel-inputs-'+uuid.uuid4().hex)
    folder.mkdir()
    path = folder/'canonical_inputs.json'
    C.write_new(path, fixture)
    C.write_new(INPUTS, dict(schema_version='sporespore_r10ap_canonical_geometry_input_binding_v1',
        ledger_scope=C.read(CONTRACT)['ledger_scope'], fixture=C.bind(path),
        source_report=fixture['source_report'], independent_model=C.bind(Path(model.__file__)),
        independent_result=fixture['independent_result'], source_form=fixture['source_form'],
        terminal_inputs=0, input_count=600, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False))
    return dict(prepared=True, fixture=C.bind(path), input_count=600)


def build_sources():
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', 'sdk/core'],
        cwd=ROOT, text=True).splitlines()
    paths = {ROOT/name for name in names}
    workspace = ROOT/'sdk/Cargo.toml'
    members = tomllib.loads(workspace.read_text(encoding='utf-8'))['workspace']['members']
    paths.update((workspace, ROOT/'sdk/Cargo.lock'))
    paths.update(ROOT/'sdk'/member/'Cargo.toml' for member in members)
    for directory in (ROOT, ROOT/'sdk'):
        paths.update(p for p in (directory/'.cargo/config', directory/'.cargo/config.toml') if p.exists())
    # Rust embeds resources from outside core/. Capture every literal resource
    # alongside the workspace resolution inputs, not merely the .rs files.
    for path in list(paths):
        if path.suffix != '.rs':
            continue
        raw = path.read_text(encoding='utf-8')
        for match in re.finditer(r'include_(?:str|bytes)!\s*\(', raw):
            literal = re.match(r'\s*"([^"\n]+)"\s*,?\s*\)', raw[match.end():])
            assert literal is not None, ('unhandled compile resource', path)
            resource = (path.parent/literal[1]).resolve()
            assert resource.is_relative_to(ROOT) and resource.is_file()
            paths.add(resource)
    paths.update(Path(item['path']) for item in C.read(CONTRACT)['dependencies'])
    paths.update((CONTRACT, INPUTS, Path(__file__)))
    return [C.bind(p) for p in sorted(paths)]


def tail(path, limit=3000):
    with path.open('rb') as stream:
        stream.seek(max(0, path.stat().st_size-limit))
        return stream.read().decode('utf-8', errors='replace')


def run_tests():
    assert INPUTS.exists()
    operation = Path(os.environ['SPORESPORE_R10AP_OPERATION_RECEIPT']).resolve()
    assert operation.is_relative_to(EVIDENCE)
    receipt = C.read(operation)
    assert receipt['acquired'] is True and receipt['role'] == 'conformance'
    assert receipt['owner_process_id'] == os.getppid()
    folder = EVIDENCE/('r10ap-kernel-release-'+uuid.uuid4().hex)
    folder.mkdir()
    command = [str(CARGO), 'test', '--manifest-path', 'sdk/core/Cargo.toml', '--release',
        '--locked', '--offline', '--lib', '--', '--nocapture', '--test-threads=1']
    before = build_sources()
    C.write_new(folder/'bindings-before.json', before)
    with zipfile.ZipFile(folder/'source-snapshot.zip', 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        for item in before:
            path = Path(item['path'])
            archive.writestr(path.relative_to(ROOT).as_posix(), path.read_bytes())
    version = subprocess.check_output([str(CARGO), '--version'], cwd=ROOT, text=True).strip()
    C.write_new(folder/'invocation.json', dict(command=command, cwd=ROOT.as_posix(), cargo_version=version,
        cargo_executable=C.bind(CARGO), source_parent_commit=C.read(CONTRACT)['source_parent_commit'],
        started_unix=time.time(), parent_operation_lock=C.bind(operation)))
    print('R10AP_TEST_ROOT='+folder.as_posix(), flush=True)
    with (folder/'stdout.log').open('wb') as out, (folder/'stderr.log').open('wb') as err:
        result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
    after = build_sources()
    C.write_new(folder/'bindings-after.json', after)
    C.write_new(folder/'execution.json', dict(command=command, returncode=result.returncode,
        source_unchanged=before == after, finished_unix=time.time()))
    print(tail(folder/'stdout.log', 2400))
    print(tail(folder/'stderr.log'))
    assert result.returncode == 0 and before == after
    return dict(ok=True, run=folder.as_posix())


def validate_archive(folder):
    before = C.read(folder/'bindings-before.json')
    assert before == C.read(folder/'bindings-after.json')
    with zipfile.ZipFile(folder/'source-snapshot.zip') as archive:
        expected = [Path(item['path']).relative_to(ROOT).as_posix() for item in before]
        assert sorted(archive.namelist()) == sorted(expected)
        for item, name in zip(before, expected, strict=True):
            raw = archive.read(name)
            assert len(raw) == item['byte_length']
            assert 'sha256:'+hashlib.sha256(raw).hexdigest() == item['raw_sha256']
    return len(before)


def observations(folder):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(EVIDENCE) and folder.name.startswith('r10ap-kernel-release-')
    execution = C.read(folder/'execution.json')
    assert execution['returncode'] == 0 and execution['source_unchanged']
    assert all(flag in execution['command'] for flag in ('--release', '--locked', '--offline', '--lib', '--test-threads=1'))
    operation = C.read(folder/'invocation.json')['parent_operation_lock']
    assert C.bind(operation['path']) == operation
    source_count = validate_archive(folder)
    manifest_paths = {Path(item['path']).relative_to(ROOT).as_posix() for item in C.read(folder/'bindings-before.json')}
    assert {'sdk/Cargo.toml', 'sdk/Cargo.lock', 'sdk/adapters/godot/Cargo.toml',
        'sdk/adapters/rapier/Cargo.toml', 'sdk/recovery/r10am_support_anchored_kernel_contract_v1.json',
        'sdk/include/sporespore_locomotion.h'}.issubset(manifest_paths)
    failed = C.read(FAILED/'execution.json')
    assert failed['returncode'] == 101 and failed['source_unchanged']
    validate_archive(FAILED)
    error_log = (FAILED/'stderr.log').read_text(encoding='utf-8')
    assert 'for i in 0.0.3' in error_log and 'for i in 0.0.8' in error_log
    assert 'error[E0610]' in error_log and 'could not compile' in error_log
    preliminary = C.read(PRELIMINARY/'execution.json')
    assert preliminary['returncode'] == 0 and preliminary['source_unchanged']
    validate_archive(PRELIMINARY)
    assert 'test result: ok. 503 passed; 0 failed;' in tail(PRELIMINARY/'stdout.log')
    binding = C.read(INPUTS)
    for key in ('fixture', 'source_report', 'independent_model', 'independent_result'):
        assert C.bind(binding[key]['path']) == binding[key]
    fixture = C.read(binding['fixture']['path'])
    assert fixture == source_rows()
    outputs, summaries, new_tests = [], [], []
    for raw_line in (folder/'stdout.log').open(encoding='utf-8'):
        line = raw_line.rstrip('\r\n')
        _, marker, payload = line.partition('R10AP_KERNEL_FIXTURE ')
        if marker:
            outputs.append(json.loads(payload))
        if line.startswith('test result:'):
            summaries.append(line)
        if line.startswith('test recovery_runtime::partial_progressive_headroom_control::tests::'):
            new_tests.append(line.split(' ...')[0])
    assert len(summaries) == 1
    match = re.fullmatch(r'test result: ok\. (\d+) passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in [0-9.]+s', summaries[0])
    assert match and int(match[1]) >= 503 and len(new_tests) == 7
    assert len(outputs) == len(fixture['observations']) == 600
    error = 0.
    modes = Counter()
    increased = 0
    for compiled, row in zip(outputs, fixture['observations'], strict=True):
        expected, geometry = row['expected'], compiled['geometry']
        assert compiled['semantic_step'] == row['observation']['semantic_step']
        assert compiled['source_sha256'] == row['source_observation_sha256']
        for key, field in [('candidates', 'candidate_count'), ('geometric', 'feasible_candidate_count'),
                ('nonworsening', 'nonworsening_headroom_candidate_count'), ('progress', 'headroom_progress_candidate_count')]:
            assert expected[key] == geometry[field]
        modes[compiled['mode']] += 1
        if expected['selected'] is None:
            assert compiled['mode'] == 'explicit_v23_fallback'
            assert geometry['hold_reason'] == expected['refusal']
            targets = row['v23_fallback_targets']
            assert geometry['selected_deficits_rad'] is None
        else:
            selected = expected['selected']
            assert compiled['mode'] == selected['mode']
            assert geometry['selected_scale'] == selected['scale'] and geometry['virtual_level_blend'] == selected['blend']
            assert max(abs(a-b) for a, b in zip(geometry['virtual_translation_world_m'], selected['translation'])) < 1e-12
            assert abs(geometry['selected_cost']-selected['cost']) < 1e-12
            for key, values in [('initial_deficits_rad', expected['deficits_before_rad']),
                    ('selected_deficits_rad', selected['verification']['deficits_after_rad'])]:
                assert max(abs(a-b) for a, b in zip(geometry[key], values)) < 1e-12
            targets = selected['targets']
            increased += geometry['geometry_cost_increased']
        error = max(error, max(abs(a-b) for a, b in zip(compiled['targets'], targets, strict=True)))
    assert dict(modes) == dict(raise_with_headroom=4, recover_joint_headroom=593, explicit_v23_fallback=3)
    assert increased == 492 and error < 1e-10
    return dict(release_core_tests_passed=int(match[1]), new_kernel_tests_passed=7,
        archived_build_source_files=source_count, canonical_inputs=600, compiled_model_comparisons=600,
        support_establishment_parity_inputs=600, source_observation_hashes_preserved=600,
        modes=dict(modes), geometry_cost_increases=increased, maximum_target_error_rad=error,
        retained_compile_failures=1, retained_preliminary_development_passes=1, **CLAIMS)


def create(folder):
    assert not RECORD.exists()
    observed = observations(folder)
    paths = [CONTRACT, INPUTS, model.STUDY, model.RESULT, Path(model.__file__)]
    C.write_new(RECORD, dict(schema_version='sporespore_r10ap_progressive_headroom_kernel_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral', authority_mode='compiled_geometry_component', question_class='development'),
        auditor=C.bind(Path(__file__)), dependencies=[C.bind(p) for p in paths],
        execution_root=Path(folder).as_posix(), retained_evidence=[C.bind(p)
            for root in (Path(folder), FAILED, PRELIMINARY) for p in sorted(root.iterdir()) if p.is_file()],
        observed=observed, claim_boundary=CLAIMS,
        next_action='Integrate a distinct native composition and real C/Python/Godot interfaces with complete source, ownership, energy, phase and terminal admission before declaring a fresh bounded diagnostic.'))
    return observed


def audit():
    record = C.read(RECORD)
    for item in [record['auditor'], *record['dependencies'], *record['retained_evidence']]:
        assert C.bind(item['path']) == item
    assert record['claim_boundary'] == CLAIMS
    assert record['observed'] == observations(record['execution_root'])
    return record['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--run-tests', action='store_true')
    mode.add_argument('--create', type=Path, metavar='RETAINED_RUN')
    args = parser.parse_args()
    result = prepare() if args.prepare else run_tests() if args.run_tests else create(args.create) if args.create else audit()
    print(json.dumps(result, indent=2))
