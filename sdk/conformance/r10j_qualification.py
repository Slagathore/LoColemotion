"""Complete R10J zero-world qualification and independent retained gate reader.

The wrapper writes only a fresh durable evidence directory. A passing record
must subsequently be committed alone, followed by the authority-only child.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import uuid

import r10j_campaign_authority as authority
import r10j_dependency_manifest as dependencies


def library_contract():
    command = ". ./sdk/run_r10j_finite_recovery.ps1 -Library; ConvertTo-Json -InputObject @{stages=$r10jStages;candidate=$candidateSelection.candidate_profile} -Depth 100 -Compress"
    run = subprocess.run(['pwsh', '-NoProfile', '-Command', command], cwd=authority.ROOT,
                         capture_output=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    authority.require(run.returncode == 0, 'QUALIFICATION_LIBRARY:' + run.stderr.decode(errors='replace'))
    return authority.parse(run.stdout)


def validate_stage_stream(actual, expected, read_bytes):
    authority.require(type(actual) is list and len(actual) == len(expected) and
                      [s.get('id') for s in actual] == [s['id'] for s in expected], 'QUALIFICATION_STAGE_POPULATION')
    for stage, spec in zip(actual, expected):
        for field, value in [('passed', True), ('exit_code', 0), ('timed_out', False),
                             ('test_count', spec['tests']), ('expected_test_count', spec['tests'])]:
            authority.require(authority.same(stage.get(field), value), 'QUALIFICATION_STAGE_'+field)
        logs = ''
        for stream in ('stdout', 'stderr'):
            name = spec['id']+'.'+stream+'.log'
            authority.require(stage.get(stream) == name, 'QUALIFICATION_LOG_PATH')
            raw = read_bytes(name)
            authority.require(authority.sha(raw) == 'sha256:'+stage.get(stream+'_sha256', ''), 'QUALIFICATION_LOG_BYTES')
            logs += raw.decode('utf-8', errors='strict')
        counts = re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$', logs, re.M)
        authority.require(counts == [str(spec['tests'])] and
                          len(re.findall(r'^OK\s*$', logs, re.M)) == 1 and
                          not re.search(r'^FAILED\b|^ERROR:', logs, re.M), 'QUALIFICATION_LOG_RESULT')
    return sum(s['tests'] for s in expected)


def validate_gate(root, *, source_commit, route_key, physical):
    root = Path(root).resolve()
    prefix = 'r10j-production-ghost-' if physical else 'r10j-zero-world-check-'
    authority.require(root.parent == authority.EVIDENCE.resolve() and
                      re.fullmatch(prefix+'[0-9a-f]{32}', root.name), 'QUALIFICATION_GATE_ROOT')
    receipt = authority.parse((root / 'supervisor_result.json').read_bytes())
    lines = (root / 'published_marker.txt').read_text(encoding='utf-8').splitlines()
    marker = 'R10J_CAMPAIGN_COMPLETE '
    authority.require(len(lines) == 1 and lines[0].startswith(marker) and
                      authority.same(authority.parse(lines[0][len(marker):]), receipt), 'QUALIFICATION_PUBLICATION')
    source = receipt.get('source_snapshot', {})
    authority.require(receipt.get('schema_version') == 'sporespore_r10j_campaign_supervisor_v1' and
                      receipt.get('ok') is True and receipt.get('failure_code') == '' and
                      receipt.get('mode') == 'development_ghost' and receipt.get('run_requested') is physical and
                      receipt.get('physical_attempt_started') is physical and receipt.get('cell_failures') == [] and
                      source.get('head') == source_commit and source.get('dirty') is False and
                      source.get('status') == [] and source.get('changed_file_bindings') == [] and
                      receipt.get('production_route_key') == route_key and
                      receipt.get('physical_acceptance_authority') is False and receipt.get('release_authority') is False,
                      'QUALIFICATION_GATE_RECEIPT')
    if not physical:
        authority.require(receipt.get('pairs') == [] and receipt.get('independent_audit') is None, 'QUALIFICATION_OPENED_WORLD')
    manifest = authority.parse((root / 'source_manifest.json').read_bytes())
    authority.require(dependencies.validate(manifest) == route_key, 'QUALIFICATION_GATE_KEY')
    count = validate_stage_stream(receipt['safety_stages'], library_contract()['stages'],
                                  lambda name: (root / name).read_bytes())
    native_prefix = 'DEVELOPMENT_SMOKE_ZERO_WORLD '
    native_rows = [line[len(native_prefix):] for line in
                   (root / 'smoke_native_safety.stdout.log').read_text(encoding='utf-8').splitlines()
                   if line.startswith(native_prefix)]
    authority.require(len(native_rows) == 1, 'QUALIFICATION_NATIVE_MARKER')
    native = authority.parse(native_rows[0])
    authority.require(native.get('ok') is True, 'QUALIFICATION_NATIVE_FAILED')
    import qsdk_r10f_zero_world_implementation as implementation
    implementation.validate_godot_receipt(native['native'], require_l15_context=True)
    return dict(root=root.as_posix(), test_count=count, stage_count=len(receipt['safety_stages']),
                supervisor_sha256=authority.sha((root / 'supervisor_result.json').read_bytes()),
                marker_sha256=authority.sha((root / 'published_marker.txt').read_bytes()))


def validate_ghost(ghost, route_key):
    authority.require(ghost.get('production_route_key') == route_key and
                      ghost.get('production_route_ghost_passed') is True and
                      ghost.get('launcher_ok') is True and ghost.get('independent_audit_ok') is True and
                      ghost.get('post_exposure_regraded') is False and
                      authority.same(ghost.get('held_out_worlds_opened'), 0) and
                      ghost.get('physical_acceptance_authority') is False, 'QUALIFICATION_GHOST_REQUIRED')
    root = Path(ghost['evidence_root'])
    gate = validate_gate(root, source_commit=ghost['source_commit'], route_key=route_key, physical=True)
    authority.require(authority.same(ghost.get('safety_gate'), gate), 'QUALIFICATION_GHOST_GATE_BINDING')
    import r10j_campaign_audit as campaign
    audit = campaign.audit(root, retained=True)
    authority.require(audit['execution_valid'] is True and
                      authority.same(ghost.get('independent_audit'), audit), 'QUALIFICATION_GHOST_AUDIT')
    return audit


def validate_retained_qualification(qualification, ghost):
    route_key = qualification['production_route_key']
    validate_ghost(ghost, route_key)
    gate = validate_gate(qualification['safety_gate_root'], source_commit=qualification['source_freeze_commit'],
                         route_key=route_key, physical=False)
    authority.require(authority.same(qualification.get('safety_gate'), gate), 'QUALIFICATION_GATE_BINDING')
    root = Path(qualification['qualification_evidence_root']).resolve()
    authority.require(root.parent == authority.EVIDENCE.resolve() and
                      re.fullmatch('r10j-qualification-[0-9a-f]{32}', root.name), 'QUALIFICATION_EVIDENCE_ROOT')
    authority.require(authority.same(authority.parse((root / 'qualification_record.json').read_bytes()), qualification),
                      'QUALIFICATION_ORIGINAL_RECORD')
    authority.require(authority.parse((root / 'wrapper_completion.json').read_bytes()) ==
                      dict(exit_code=0, record_sha256=authority.sha((root / 'qualification_record.json').read_bytes())),
                      'QUALIFICATION_WRAPPER_COMPLETION')
    stdout = (root / 'runner.stdout.log').read_bytes()
    stderr = (root / 'runner.stderr.log').read_bytes()
    authority.require(authority.sha(stdout) == qualification['runner_stdout_sha256'] and
                      authority.sha(stderr) == qualification['runner_stderr_sha256'], 'QUALIFICATION_WRAPPER_LOGS')
    marker = 'R10J_CAMPAIGN_COMPLETE '
    rows = [line for line in stdout.decode('utf-8').splitlines() if line.startswith(marker)]
    authority.require(len(rows) == 1 and authority.same(authority.parse(rows[0][len(marker):]),
                      authority.parse((Path(gate['root']) / 'supervisor_result.json').read_bytes())),
                      'QUALIFICATION_WRAPPER_PUBLICATION')
    return gate


def qualify():
    head = authority.repository_state()
    manifest = authority.parse((authority.ROOT / authority.MANIFEST_PATH).read_bytes())
    route_key = dependencies.validate(manifest)
    ghost = authority.parse((authority.ROOT / authority.GHOST_PATH).read_bytes())
    validate_ghost(ghost, route_key)
    preregistration = authority.validate_preregistration(authority.parse((authority.ROOT / authority.PREREGISTRATION_PATH).read_bytes()))
    authority.require(preregistration['candidate_profile'] == library_contract()['candidate'], 'QUALIFICATION_CANDIDATE')
    root = authority.EVIDENCE / ('r10j-qualification-'+uuid.uuid4().hex)
    root.mkdir()
    command = ['pwsh', '-NoProfile', '-File', str(authority.ROOT / 'sdk/run_r10j_finite_recovery.ps1')]
    declaration = dict(command=command, source_freeze_commit=head, production_route_key=route_key,
                       world_attempt_count=0, physical_execution_authorized=False)
    (root / 'wrapper_declaration.json').write_text(json.dumps(declaration, indent=2)+'\n', encoding='utf-8')
    print('R10J_QUALIFICATION_ROOT '+root.as_posix(), flush=True)
    with (root / 'runner.stdout.log').open('xb') as out, (root / 'runner.stderr.log').open('xb') as err:
        run = subprocess.run(command, cwd=authority.ROOT, stdout=out, stderr=err,
                             creationflags=subprocess.CREATE_NO_WINDOW)
    if run.returncode:
        (root / 'wrapper_completion.json').write_text(json.dumps(dict(exit_code=run.returncode, passed=False))+'\n', encoding='utf-8')
    authority.require(run.returncode == 0, 'QUALIFICATION_RUNNER_FAILED')
    marker = 'R10J_CAMPAIGN_COMPLETE '
    rows = [line[len(marker):] for line in (root / 'runner.stdout.log').read_text(encoding='utf-8').splitlines() if line.startswith(marker)]
    authority.require(len(rows) == 1 and authority.repository_state() == head and dependencies.validate(manifest) == route_key,
                      'QUALIFICATION_SOURCE_OR_OUTPUT_DRIFT')
    supervisor = authority.parse(rows[0])
    gate = validate_gate(supervisor['evidence_root'], source_commit=head, route_key=route_key, physical=False)
    record = dict(schema_version='sporespore_r10j_zero_world_qualification_v1', passed=True,
                  ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='official_zero_world_qualification', question_class='finite decision'),
                  source_freeze_commit=head, production_route_key=route_key, safety_gate=gate,
                  safety_gate_root=gate['root'], qualification_evidence_root=root.as_posix(),
                  dependency_manifest_sha256=authority.file_binding(authority.MANIFEST_PATH)['raw_sha256'],
                  preregistration_sha256=authority.file_binding(authority.PREREGISTRATION_PATH)['raw_sha256'],
                  runner_stdout_sha256=authority.sha((root / 'runner.stdout.log').read_bytes()),
                  runner_stderr_sha256=authority.sha((root / 'runner.stderr.log').read_bytes()),
                  world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
                  physical_acceptance_authority=False, release_authority=False)
    path = root / 'qualification_record.json'
    path.write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    (root / 'wrapper_completion.json').write_text(json.dumps(dict(exit_code=0, record_sha256=authority.sha(path.read_bytes())))+'\n', encoding='utf-8')
    validate_retained_qualification(record, ghost)
    return dict(record_path=path.as_posix(), passed=True, physical_execution_authorized=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qualify', action='store_true', required=True)
    parser.parse_args()
    try:
        print('R10J_QUALIFICATION_COMPLETE '+json.dumps(qualify()))
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('R10J_QUALIFICATION_REFUSED '+str(error))
        raise SystemExit(1)
