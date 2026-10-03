"""Fresh synthetic reports through the complete production Python consumer.

Use --catalog with a prospective fixture catalog and --case (or all). Run under
the native operation lock. Each catalog case is single-use, even on failure.
No selection, host admission, subprocess receipt or report consumer is mocked.
"""
import argparse
import copy
import gc
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback

import development_passive_entry_profile as consumer
import development_recovery_candidate as candidate
import r10ap_development as identity
import r10ap_host_runtime as host
import r10ap_native_component as native
import r10ap_report_fixtures as registry

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
sys.path.insert(0, str(ROOT / 'tests'))
CONTROL = EVIDENCE / 'development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'
CLAIMS = dict(synthetic_measurements_only=True, real_candidate_admission=True,
    complete_production_python_consumer=True, world_build_count=0, solver_step_count=0,
    physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)


def write(path, value):
    with Path(path).open('xb') as stream: stream.write(registry.raw(value))


def native_child(out, name, script, args, environment=None, timeout=420):
    command = [host.expected_binding()['images']['godot_engine']['path'], '--headless',
        '--path', str(ROOT), '--script', 'res://tests/' + script, '--', *map(str, args)]
    started = time.monotonic()
    env = {k: v for k, v in os.environ.items() if not k.startswith(('SPORE_R10', 'SPORESPORE_GODOT_RECOVERY_'))}
    env.update(environment or {})
    with (out / (name + '.stdout.txt')).open('xb') as stdout, (out / (name + '.stderr.txt')).open('xb') as stderr:
        with subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                              creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try: code = process.wait(timeout=timeout); timed_out = False
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); code = process.returncode; timed_out = True
            write(out / (name + '.execution.json'), dict(command=command, process_id=process.pid,
                returncode=code, timed_out=timed_out, timeout_seconds=timeout,
                elapsed_seconds=time.monotonic()-started, **CLAIMS))
    assert code == 0 and not timed_out, (name, code, (out / (name + '.stderr.txt')).read_text()[-5000:])
    assert (out / (name + '.stderr.txt')).read_bytes() == b'', name


def phase_inputs(out, branch):
    import test_development_r10v_preparation_report as preparation
    import r10r_native_component as fixtures_native
    exposed = preparation.exposed_input()
    hold = next(s for s in exposed['segments'] if s['id'] == 'v50_hold_stance_entry')
    walking = copy.deepcopy(next(s for s in exposed['segments'] if s['id'] == 'matched_continuation'))
    walking['id'] = 'walking_resume'
    supplied = dict(source_report=exposed['source_report'], original_result_regraded=False,
        synthetic_counterfactual_only=True, physical_values_are_supplied_not_simulated=True,
        segment=dict(id='v50_post_recovery_settling', start=hold['start'],
                     initial_contact_by_limb=hold['traces'][-1]['contact_by_limb']),
        sample=hold['samples'][-1], trace=hold['traces'][-1], readiness=hold['readiness'][-1],
        walking_segment=walking, timeout=branch == 'timeout')
    write(out / 'phase-input.json', supplied)
    runtime = candidate.read(ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
    old = candidate.read(fixtures_native.Q_BINDING)
    sources = [old['compiled_fixtures'], runtime['compiled_fixtures']]
    for source in sources: native.builds.verify(source)
    write(out / 'fixture-sources.json', sources)
    fixtures = [fixtures_native.fixtures(sources[0]['path'], 'R10Q_UPRIGHT_FIXTURE')[0],
                *fixtures_native.fixtures(sources[1]['path'], 'R10R_UPRIGHT_FIXTURE')]
    path = out / 'source-fixtures.jsonl'
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(''.join('R10V_SOURCE_FIXTURE ' + json.dumps(f) + '\n' for f in fixtures))
    return path


def damage(report, case):
    """Retain deliberate corruptions separately from the original fixture."""
    kind = case.split('_', 1)[1]
    if kind == 'source':
        report['r10af_contact_frame_links']['records'][300]['source_trace']['contact_source_sha256'] = 'sha256:' + '0'*64
    elif kind in ('owner', 'phase', 'energy'):
        transition = report['passive_entry']['orchestrator_transitions'][300]
        if kind == 'owner': transition['event']['control_owner'] = 'undeclared_owner'
        elif kind == 'phase': transition['state_before']['phase'] = 'fresh_selected_policy_walking_resume'
        else:
            # The source packet is already hashed. Alter a measured energy value
            # without recomputing receipts, simulating corrupted retained data.
            transition['state_before']['energy_initializer_sha256'] = 'sha256:' + '0'*64
    elif kind == 'shutdown':
        report['retained_arm']['walking_sessions'][0]['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] = 0
    elif kind == 'memory':
        report['development_walking_entry']['rows'][0]['request']['memory']['ordered_limb_memory'][0]['gait_step'] += 1
    elif kind == 'capture': report['r10af_contact_frames']['records'].pop()
    elif kind == 'missing': del report['post_recovery_settling']
    else: raise ValueError(case)


def run_case(catalog_path, name):
    catalogs = dict((p.resolve(), c) for p, c in registry.catalogs())
    catalog_path = Path(catalog_path).resolve(); catalog = catalogs[catalog_path]
    case = catalog['cases'][name]; declaration = case['declaration']
    root = EVIDENCE / ('development-recovery-smoke-' + declaration['attempt_id'])
    root.mkdir()  # A failed case is consumed too; never overwrite its output.
    out = Path(declaration['children'][0]['evidence_path']); out.mkdir(parents=True)
    write(root / 'declaration.json', declaration)
    assert registry.registered_declaration(root / 'declaration.json')
    write(root / 'synthetic-report-fixture.json', dict(catalog=native.closure.bind(catalog_path), case=name, **CLAIMS))
    print('R10AP_CONSUMER_CASE ' + name + ' ' + root.as_posix(), flush=True)
    before = consumer._source_snapshot(); write(root / 'source-before.json', before)
    execution = dict(ok=False, **CLAIMS)
    try:
        chosen = candidate.selection(identity.reference())
        host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
                          host.expected_binding()['images']['powershell_host']['path'])
        frames = out / 'frame-fixtures.json'
        native_child(out, 'frames', 'test_r10ap_contact_report_fixture.gd', [root / 'declaration.json', frames])
        env = dict(SPORE_R10AP_FIXTURE_DECLARATION=str(root / 'declaration.json'),
                   SPORE_R10AP_FRAME_FIXTURES=str(frames))
        branch = name.split('_', 1)[0]
        fixture_path = out / 'fixture.json'
        if branch == 'partial':
            assert identity.sha(CONTROL) == 'sha256:8b389a917370a534accc0502835a2cca66537fe1d6785f7eb5d7b27c7f3441ae'
            native_child(out, 'fixture', 'test_r10ap_complete_report_fixture.gd', [CONTROL, fixture_path, 'partial'], env)
        else:
            fixtures = phase_inputs(out, branch)
            env.update(SPORE_R10AP_PHASE_BRANCH=branch, SPORE_R10AP_HOLD_REPORT_INPUT=str(out / 'phase-input.json'))
            native_child(out, 'fixture', 'test_r10ap_complete_phase_fixture.gd', [fixtures, fixture_path], env)
        fixed = candidate.read(fixture_path)
        assert fixed['ok'] is True and all(fixed['checks'].values()), fixed.get('checks')
        assert fixed['synthetic_measurements_only'] is True
        assert fixed['world_build_count'] == fixed['solver_step_count'] == 0
        report = fixed['active']['report']; identity.validate_report_header(report, declaration)
        negative = '_' in name
        if negative: damage(report, name)
        report_path = out / 'worker_report.json'; write(report_path, report)
        try:
            result = consumer.run_replay(report_path)
        except ValueError as error:
            if not negative: raise
            process = candidate.read(out / 'passive_entry_replay/execution.json')
            assert process['timed_out'] is False, 'Timeout is not a valid negative control'
            assert str(error).startswith('DEVELOPMENT_PASSIVE_PROFILE_'), str(error)
            result = dict(expected_refusal=True, consumer_error=str(error), process_returncode=process['returncode'])
            marker = chosen['replay_marker']
            stdout = (out / 'passive_entry_replay/stdout.txt').read_text()
            receipts = [json.loads(line[len(marker):]) for line in stdout.splitlines() if line.startswith(marker)]
            assert len(receipts) == 1 and receipts[0].get('ok') is False, receipts
            result['native_failure_code'] = receipts[0].get('failure_code')
        else:
            assert not negative, 'Corrupted report was accepted'
            expected = dict(partial=575, upright=575, ready=605, timeout=815, walking=607)[branch]
            assert result['transition_count'] == expected
            assert result['stance_entry_replay']['replayed_post_recovery_hold_commands'] == dict(partial=0, upright=0, ready=30, timeout=240, walking=30)[branch]
            if branch == 'walking': assert result['walking_control_replay']['replayed_walking_steps'] == 2
        write(root / 'result.json', dict(case=name, result=result, **CLAIMS))
        execution['ok'] = True
        print('R10AP_CONSUMER_PASS ' + name, flush=True)
    except BaseException:
        execution['error'] = traceback.format_exc(); raise
    finally:
        after = consumer._source_snapshot(); write(root / 'source-after.json', after)
        execution['source_unchanged'] = before == after
        write(root / 'execution.json', execution)
    assert execution['source_unchanged']
    return root.as_posix()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', required=True); parser.add_argument('--case', choices=['all', *registry.CASES], required=True)
    args = parser.parse_args()
    for name in registry.CASES if args.case == 'all' else [args.case]:
        run_case(args.catalog, name); gc.collect()
