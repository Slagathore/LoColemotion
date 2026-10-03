"""Complete R10W zero-world qualification and independent retained gate reader.

The wrapper writes only a fresh durable evidence directory. A passing record
must subsequently be committed alone, followed by the authority-only child.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import uuid
import time
import r10w_durable_host_v1 as host
import r10w_safety_gate as safety
import r10t_route_integration_component as files

import r10w_campaign_authority as authority
import r10w_dependency_manifest as dependencies


def library_contract():
    # Pure declared population: do not spawn an unbounded helper from an auditor.
    import r10w_campaign_profile as profile
    return dict(stages=safety.contract(complete=True)['stages'],candidate=profile.reference())


def validate_completed_host(root, receipt):
    context=receipt.get('r10w_host')
    authority.require(type(context) is dict, 'QUALIFICATION_HOST_MISSING')
    request=Path(context['request']['path'])
    authority.require(files.bind(request)==context['request'], 'QUALIFICATION_HOST_REQUEST_BYTES')
    status=host.status(request.parent)
    authority.require(status['state']=='complete' and status['host_alive'] is False,
        'QUALIFICATION_HOST_INCOMPLETE')
    authority.require(status['result']['primary_terminal']==files.bind(Path(root)/'supervisor_result.json'),
        'QUALIFICATION_HOST_PRIMARY')
    original=host.read(request)
    authority.require(original['source_snapshot']['head']==receipt['source_snapshot']['head']
        and original['attempt_id']==receipt['attempt_id'] and original['mode']==receipt['mode']
        and receipt['prehost_qualification']==original['prehost_qualification'], 'QUALIFICATION_HOST_CONTEXT')
    return dict(request=files.bind(request),result=files.bind(request.parent/'host_result.json'),
        publication=files.bind(request.parent/'published.json'),prehost=original['prehost_qualification'])


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
    prefix = 'r10w-production-ghost-' if physical else 'r10w-zero-world-check-'
    authority.require(root.parent == authority.EVIDENCE.resolve() and
                      re.fullmatch(prefix+'[0-9a-f]{32}', root.name), 'QUALIFICATION_GATE_ROOT')
    receipt = authority.parse((root / 'supervisor_result.json').read_bytes())
    lines = (root / 'published_marker.txt').read_text(encoding='utf-8').splitlines()
    marker = 'R10W_CAMPAIGN_COMPLETE '
    authority.require(len(lines) == 1 and lines[0].startswith(marker) and
                      authority.same(authority.parse(lines[0][len(marker):]), receipt), 'QUALIFICATION_PUBLICATION')
    source = receipt.get('source_snapshot', {})
    authority.require(receipt.get('schema_version') == 'sporespore_r10w_campaign_supervisor_v1' and
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
    completed_host=validate_completed_host(root,receipt)
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
    return dict(root=root.as_posix(), test_count=count, stage_count=len(receipt['safety_stages']),host=completed_host,
                supervisor_sha256=authority.sha((root / 'supervisor_result.json').read_bytes()),
                marker_sha256=authority.sha((root / 'published_marker.txt').read_bytes()))


def validate_ghost(ghost, route_key):
    from r10w_campaign_closure import development_coverage, workflow_passed
    authority.require(workflow_passed(ghost), 'QUALIFICATION_GHOST_ORIGINAL_WORKFLOW')
    authority.require(ghost.get('schema_version') == 'sporespore_r10w_production_route_ghost_closure_v1' and
                      ghost.get('all_tasks_positive') is True and
                      ghost.get('reader_component_sha256') == authority.READER_COMPONENT_SHA and
                      authority.same(ghost.get('declared_cells'), authority.population('development_ghost')) and
                      ghost.get('production_route_key') == route_key and
                      ghost.get('production_route_ghost_passed') is True and
                      ghost.get('launcher_ok') is True and ghost.get('independent_audit_ok') is True and
                      ghost.get('post_exposure_regraded') is False and
                      authority.same(ghost.get('held_out_worlds_opened'), 0) and
                      ghost.get('physical_acceptance_authority') is False, 'QUALIFICATION_GHOST_REQUIRED')
    root = Path(ghost['evidence_root'])
    gate = validate_gate(root, source_commit=ghost['source_commit'], route_key=route_key, physical=True)
    authority.require(authority.same(ghost.get('safety_gate'), gate), 'QUALIFICATION_GHOST_GATE_BINDING')
    import r10w_campaign_audit as campaign
    audit = campaign.audit(root, retained=True)
    development_coverage(audit)
    authority.design.audit()
    authority.require(audit['execution_valid'] is True and audit['all_finite_tasks_passed'] is True and
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
                      re.fullmatch('r10w-qualification-[0-9a-f]{32}', root.name), 'QUALIFICATION_EVIDENCE_ROOT')
    authority.require(authority.same(authority.parse((root / 'qualification_record.json').read_bytes()), qualification),
                      'QUALIFICATION_ORIGINAL_RECORD')
    authority.require(authority.parse((root / 'wrapper_completion.json').read_bytes()) ==
                      dict(exit_code=0, record_sha256=authority.sha((root / 'qualification_record.json').read_bytes())),
                      'QUALIFICATION_WRAPPER_COMPLETION')
    request=Path(gate['host']['request']['path'])
    for stream in ('stdout','stderr'):
        authority.require((root/('runner.'+stream+'.log')).read_bytes()==(request.parent/('supervisor.'+stream+'.txt')).read_bytes(), 'QUALIFICATION_ORIGINAL_HOST_STREAM')
    stdout = (root / 'runner.stdout.log').read_bytes()
    stderr = (root / 'runner.stderr.log').read_bytes()
    authority.require(authority.sha(stdout) == qualification['runner_stdout_sha256'] and
                      authority.sha(stderr) == qualification['runner_stderr_sha256'], 'QUALIFICATION_WRAPPER_LOGS')
    marker = 'R10W_CAMPAIGN_COMPLETE '
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
    root = authority.EVIDENCE / ('r10w-qualification-'+uuid.uuid4().hex)
    root.mkdir()
    command=[str(host.PWSH),'-NoLogo','-NoProfile','-File',str(authority.ROOT/'sdk/run_r10w_prehost_qualification.ps1')]
    files.write_new(root/'wrapper_declaration.json',dict(command=command,source_freeze_commit=head,
        production_route_key=route_key,world_attempt_count=0,physical_execution_authorized=False))
    print('R10W_QUALIFICATION_ROOT '+root.as_posix(),flush=True)
    try:
        with (root/'prehost.stdout.log').open('xb') as out,(root/'prehost.stderr.log').open('xb') as err:
            run=subprocess.run(command,cwd=authority.ROOT,stdout=out,stderr=err,timeout=900,
                creationflags=subprocess.CREATE_NO_WINDOW)
        authority.require(run.returncode==0,'QUALIFICATION_PREHOST_FAILED')
        prefix='R10W_PREHOST_ROOT '
        rows=[line[len(prefix):] for line in (root/'prehost.stdout.log').read_text(encoding='utf-8').splitlines() if line.startswith(prefix)]
        authority.require(len(rows)==1,'QUALIFICATION_PREHOST_ROOT')
        request=host.prepare(lane='production_gate',mode='development_ghost',prehost_qualification=Path(rows[0])/'qualification.json')
        files.write_new(root/'host_request.json',files.bind(request))
        launched=host.launch(request)
        files.write_new(root/'host_launch.json',launched)
        deadline=time.monotonic()+host.read(request)['deadline_seconds']+30
        while True:
            status=host.status(request.parent)
            if status['state'] not in ('running','publishing') and not status.get('host_alive',False):break
            authority.require(time.monotonic()<deadline,'QUALIFICATION_HOST_OBSERVATION_TIMEOUT')
            time.sleep(1)
        files.write_new(root/'host_terminal_observation.json',status)
        for stream in ('stdout','stderr'):
            with (root/('runner.'+stream+'.log')).open('xb') as output:
                output.write((request.parent/('supervisor.'+stream+'.txt')).read_bytes())
        authority.require(status['state']=='complete','QUALIFICATION_HOST_FAILED')
    except Exception as error:
        files.write_new(root/'wrapper_completion.json',dict(exit_code=1,passed=False,failure_code=str(error),retry_authorized=False))
        raise
    marker = 'R10W_CAMPAIGN_COMPLETE '
    rows = [line[len(marker):] for line in (root / 'runner.stdout.log').read_text(encoding='utf-8').splitlines() if line.startswith(marker)]
    authority.require(len(rows) == 1 and authority.repository_state() == head and dependencies.validate(manifest) == route_key,
                      'QUALIFICATION_SOURCE_OR_OUTPUT_DRIFT')
    supervisor = authority.parse(rows[0])
    gate = validate_gate(supervisor['evidence_root'], source_commit=head, route_key=route_key, physical=False)
    record = dict(schema_version='sporespore_r10w_zero_world_qualification_v1', passed=True,
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
        print('R10W_QUALIFICATION_COMPLETE '+json.dumps(qualify()))
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('R10W_QUALIFICATION_REFUSED '+str(error))
        raise SystemExit(1)
