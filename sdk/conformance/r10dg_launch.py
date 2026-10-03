"""Build fresh declarations and qualify the real pre-world context transport."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid

import r10dg_identity as I


def declaration(head, fixture=False):
    ids = [('ffffffff' + uuid.uuid4().hex[8:]) if fixture else uuid.uuid4().hex for _ in range(3)]
    profile = I.read(I.PROFILE)
    runtime = I.read(I.ROOT / profile['runtime_binding'][6:])
    design = I.read(I.DESIGN)
    value = dict(schema_version='sporespore_development_recovery_candidate_declaration_v1', ledger_scope=design['ledger_scope'],
        attempt_id=ids[0], source_snapshot=dict(head=head, dirty=False, status=[], changed_file_bindings=[]),
        runtime=I.read(I.HOST), seed=I.SEED,
        children=[dict(role=I.ROLE, child_attempt_id=ids[1], termination_nonce=ids[2],
                       evidence_path=(I.EVIDENCE / ('development-recovery-smoke-' + ids[0]) / 'children' / I.ROLE).as_posix())],
        candidate_profile=I.reference(), worker_resource=I.WORKER, development_execution_mode='single_kick_controller_diagnostic_v1',
        comparative_authority=False, baseline_reused=False, official_qualification=False, physical_acceptance_authority=False, release_authority=False,
        diagnostic_schedule_id='r10dg_finite_reference_tracking_v1', passive_entry_runtime=runtime['runtime'],
        step_cost_profile_id='recovery_step_cost_wall_clock_v1', context_cache_profile_id='recovery_exact_context_checks_v1',
        context_cache_call_sites=['epoch_preflight', 'global_context_validation'],
        timeout_seconds_per_child=2400, independent_replay_timeout_seconds=1200,
        coverage_question=design['question'], uncovered_paths=design['uncovered_paths'],
        telemetry_profile='unchanged_full_per_step_capture')
    for key in ['maximum_precondition_steps', 'walking_prefix_steps', 'interaction_steps', 'maximum_passive_descent_steps', 'after_interaction_steps', 'maximum_steps_per_child']:
        value[key] = design['limits'][key]
    value[I.CONTEXT] = I.context(head)
    if fixture:
        value['report_fixture_only'] = True
    return I.validate(value)


def run_process(folder, name, command, env=None, timeout=180):
    with (folder / (name + '.stdout.txt')).open('xb') as out, (folder / (name + '.stderr.txt')).open('xb') as err:
        with subprocess.Popen(list(map(str, command)), cwd=I.ROOT, env=env, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW) as proc:
            try:
                code = proc.wait(timeout=timeout)
                timed_out = False
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                code, timed_out = proc.returncode, True
    receipt = dict(command=list(map(str, command)), exit_code=code, timed_out=timed_out,
                   stdout=I.binding(folder / (name + '.stdout.txt')), stderr=I.binding(folder / (name + '.stderr.txt')))
    I.write_new(folder / (name + '.process.json'), receipt)
    I.require(code == 0 and not timed_out, 'PROCESS:' + name)
    I.require((folder / (name + '.stderr.txt')).read_bytes() == b'', 'STDERR:' + name)
    return receipt


def clean_environment():
    return {k: v for k, v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_', 'SPORE_R10'))}


def prepare_context(folder, value):
    proposal = folder / 'context-proposal.json'
    I.write_new(proposal, value)
    engine = value['runtime']['images']['godot_engine']['path']
    target = folder / 'prepared-context.json'
    run_process(folder, 'context-producer', [engine, '--headless', '--path', I.ROOT, '--script',
        'res://sdk/adapters/godot/gdscript/r10dg_prepare_launch_context_v1.gd', '--', proposal, target], clean_environment())
    prepared = I.read(target)
    I.require(prepared['ok'] is True and prepared['world_build_count'] == prepared['solver_step_count'] == 0, 'PREPARED_CONTEXT')
    value['prepared_context_expectation'] = prepared['expectation']
    declaration_path = folder / 'declaration.json'
    I.write_new(declaration_path, value)
    run_process(folder, 'environment', [value['runtime']['images']['powershell_host']['path'], '-NoProfile', '-File',
        I.ROOT / 'sdk/r10dg_child_environment.ps1', '-Declaration', declaration_path, '-OutputPath', folder / 'child-environment.json'])
    environment = I.read(folder / 'child-environment.json')
    env = clean_environment()
    env.update(environment['environment'])
    run_process(folder, 'pre-world', [engine, '--headless', '--path', I.ROOT, '--script',
        'res://sdk/adapters/godot/gdscript/r10dg_pre_world_consumer_v1.gd', '--', declaration_path, folder / 'pre-world-result.json'], env)
    result = I.read(folder / 'pre-world-result.json')
    I.require(result['ok'] is True and result['world_build_count'] == result['solver_step_count'] == 0
              and result['construction_boundary_reached'] is True, 'PREWORLD_REACHED')
    I.require(result['construction_guard'].get('failure_code') == 'R10DG_NATIVE_WORLD_QUALIFICATION_PENDING', 'WORLD_PERMISSION_REFUSAL')
    return declaration_path


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--qualification', type=Path, required=True)
    args = parser.parse_args()
    from r10dg_safety import verify
    verify(args.qualification)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=I.ROOT, text=True).strip()
    I.freeze(head)
    I.verify_images()
    value = declaration(head)
    value['safety_qualification'] = I.binding(args.qualification)
    folder = I.EVIDENCE / ('development-recovery-smoke-' + value['attempt_id'])
    folder.mkdir()
    Path(value['children'][0]['evidence_path']).mkdir(parents=True)
    path = prepare_context(folder, value)
    print(json.dumps(dict(ok=True, declaration=I.binding(path))))
