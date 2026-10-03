"""One-use R10DG reservation and native construction claim; never launches physics."""
import argparse
import json
import os
from pathlib import Path

import r10dg_identity as I
from r10ac_native_world_authority import worker_image


def declared(path):
    path = Path(path).resolve()
    value = I.validate(I.read(path), physical=True)
    I.require(path == I.EVIDENCE / ('development-recovery-smoke-' + value['attempt_id']) / 'declaration.json', 'DECLARATION_PATH')
    return value


def verify_qualification(value):
    from r10dg_safety import verify
    path = Path(value['safety_qualification']['path'])
    I.require(I.binding(path) == value['safety_qualification'], 'QUALIFICATION_BINDING')
    return verify(path)


def verify(path):
    path = Path(path).resolve()
    value = declared(path)
    verify_qualification(value)
    reservation = I.read(I.TOKEN)
    launch = I.read(path.parent / I.LAUNCH)
    I.require(reservation['declaration'] == I.binding(path), 'CONSUMED_DIFFERENT_DECLARATION')
    I.require(launch['declaration'] == I.binding(path) and launch['reservation'] == I.binding(I.TOKEN), 'LAUNCH_BINDING')
    I.require(reservation['maximum_physical_attempts'] == 1 and reservation['physical_acceptance_authority'] is False
              and reservation['release_authority'] is False, 'RESERVATION_SCOPE')
    return value


def authorize(path):
    path = Path(path).resolve()
    value = declared(path)
    I.freeze(value['source_snapshot']['head'])
    I.verify_images()
    qualification = verify_qualification(value)
    for name in ['prepared-context.json', 'pre-world-result.json']:
        receipt = I.read(path.parent / name)
        I.require(receipt['ok'] is True and receipt['world_build_count'] == receipt['solver_step_count'] == 0, 'PREWORLD:' + name)
    preworld = I.read(path.parent / 'pre-world-result.json')
    I.require(preworld['construction_boundary_reached'] is True
              and preworld['construction_guard'].get('failure_code') == 'R10DG_NATIVE_WORLD_QUALIFICATION_PENDING'
              and preworld['comparison'].get('ok') is True, 'CONSTRUCTION_INTERCEPT')
    # A partial exclusive write still consumes this identity. No retry deletes it.
    I.write_new(I.TOKEN, dict(schema_version='sporespore_r10dg_population_consumption_v1',
        ledger_scope=I.read(I.DESIGN)['ledger_scope'], declaration=I.binding(path), qualification=value['safety_qualification'],
        seed=I.SEED, prefix_phase=248, maximum_physical_attempts=1,
        physical_acceptance_authority=False, release_authority=False))
    I.write_new(path.parent / I.LAUNCH, dict(schema_version='sporespore_r10dg_single_use_launch_v1',
        declaration=I.binding(path), reservation=I.binding(I.TOKEN),
        prepared_context=I.binding(path.parent / 'prepared-context.json'),
        pre_world=I.binding(path.parent / 'pre-world-result.json'), physical_acceptance_authority=False, release_authority=False))
    return dict(ok=True, launch=I.binding(path.parent / I.LAUNCH), world_build_count=0, solver_step_count=0)


def expected_claim(path, value, pid):
    child = value['children'][0]
    return dict(schema_version='sporespore_r10dg_native_world_claim_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='single_use_native_diagnostic_child_claim', question_class='development'),
        parent_attempt_id=value['attempt_id'], child_attempt_id=child['child_attempt_id'], role=I.ROLE,
        termination_nonce=child['termination_nonce'], worker_process_id=pid,
        source_commit=value['source_snapshot']['head'], worker_image=I.read(I.HOST)['images']['godot_engine'],
        maximum_world_builds=1, permission_scope='diagnostic_world_construction_only',
        declaration=I.binding(path), launch=I.binding(path.parent / I.LAUNCH), reservation=I.binding(I.TOKEN),
        physical_acceptance_authority=False, release_authority=False)


def probe_worker(pid):
    I.require(type(pid) is int and pid > 0 and pid == os.getppid(), 'NATIVE_HELPER_PARENT')
    actual = worker_image(pid)
    expected = I.read(I.HOST)['images']['godot_engine']
    I.require(Path(actual['path']).resolve() == Path(expected['path']).resolve()
        and actual['byte_length'] == expected['byte_length'] and actual['raw_sha256'] == expected['raw_sha256'], 'NATIVE_HELPER_IMAGE')
    return dict(ok=True, worker_image=expected, world_build_count=0, solver_step_count=0)


def claim(path, pid):
    path = Path(path).resolve()
    value = verify(path)
    child = value['children'][0]
    expected_env = dict(AUTHORIZATION_SHA256=I.sha(path), SOURCE_COMMIT=value['source_snapshot']['head'],
        PARENT_ATTEMPT_ID=value['attempt_id'], ATTEMPT_ID=child['child_attempt_id'], CHILD_ROLE=I.ROLE,
        TERMINATION_NONCE=child['termination_nonce'], SEED=str(I.SEED), SEED_LABEL=I.LABEL,
        SEED_SHA256=I.seed_identity()['sha256'], SUPERVISED_TERMINATION='1')
    I.require(all(os.environ.get('SPORESPORE_GODOT_RECOVERY_' + k) == v for k, v in expected_env.items()), 'CHILD_ENVIRONMENT')
    probe_worker(pid)
    I.freeze(value['source_snapshot']['head'])
    I.verify_images()
    target = Path(child['evidence_path']) / I.CLAIM
    result = expected_claim(path, value, pid)
    I.write_new(target, result)
    return dict(ok=True, claim=result, claim_binding=dict(path=target.as_posix(), raw_sha256=I.sha(target)),
                world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--authorize', type=Path)
    mode.add_argument('--claim', type=Path)
    mode.add_argument('--verify', type=Path)
    mode.add_argument('--probe-worker', action='store_true')
    parser.add_argument('--worker-pid', type=int)
    args = parser.parse_args()
    try:
        result = (probe_worker(args.worker_pid) if args.probe_worker else authorize(args.authorize) if args.authorize
                  else claim(args.claim, args.worker_pid) if args.claim else dict(ok=bool(verify(args.verify))))
        print(json.dumps(result, separators=(',', ':')))
    except Exception as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), exception_type=type(error).__name__, world_build_count=0, solver_step_count=0)))
        raise SystemExit(1)
