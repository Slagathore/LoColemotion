"""R10AD read-only helper preflight. This module cannot reserve or claim a world.

The same captured Git transport is intended for the successor's launch guard.
Identity/runtime/source checks here are a component, not complete qualification.
"""
import argparse
import json
import os
from pathlib import Path

import r10ad_development as identity
import r10ad_host_runtime as host
import r10ad_startup_transport as transport
from r10ac_native_world_authority import worker_image


def require(value, code):
    if not value:
        raise ValueError('R10AD_STARTUP_' + code)


def current_freeze(source_commit, receipts=None):
    receipts = [] if receipts is None else receipts
    def git(*args):
        receipt = transport.run_captured(['git', *args], cwd=identity.ROOT)
        receipts.append(receipt)
        if receipt['timed_out'] or receipt['exit_code'] != 0:
            raise transport.CommandRefused(receipt)
        return receipt['stdout'].strip()
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == identity.ROOT.resolve(), 'SOURCE_ROOT')
    require(git('remote', 'get-url', 'origin') == 'https://github.com/Slagathore/sporespore.git', 'SOURCE_REMOTE')
    require(git('branch', '--show-current') == 'main', 'SOURCE_BRANCH')
    require(git('status', '--porcelain') == '', 'SOURCE_NOT_CLEAN')
    head, tracking = git('rev-parse', 'HEAD'), git('rev-parse', 'origin/main')
    remote = git('ls-remote', 'origin', 'refs/heads/main').split()
    require(len(remote) == 2 and remote[1] == 'refs/heads/main'
        and head == tracking == remote[0] == source_commit, 'SOURCE_NOT_PUSHED')
    return dict(root=identity.ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git',
        branch='main', head=head, origin_main=tracking, live_origin_main=remote[0], clean=True)


def validate_owner(pid):
    require(type(pid) is int and pid > 0 and pid == os.getppid(), 'HELPER_PARENT')
    actual = worker_image(pid)
    expected = host.expected_binding()['images']['godot_engine']
    require(Path(actual['path']).resolve() == Path(expected['path']).resolve()
        and actual['byte_length'] == expected['byte_length']
        and actual['raw_sha256'] == expected['raw_sha256'], 'RUNNING_IMAGE')
    return expected


def inspect_request(declaration_path, worker_pid):
    """Return structured success/refusal with subprocess streams; never throw away detail."""
    path = Path(declaration_path).resolve()
    result = dict(schema_version='sporespore_r10ad_startup_preflight_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='read_only_identity_runtime_source_preflight', question_class='development'),
        ok=False, stage='declaration', failure_code='', command_receipts=[],
        candidate_source_key_checked=False, complete_safety_gate_checked=False,
        launch_reservation_created=False, native_world_claim_created=False,
        world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False)
    try:
        declaration = json.loads(path.read_text(encoding='utf-8-sig'))
        identity.validate_declaration(declaration)
        result['declaration_binding'] = dict(path=path.as_posix(), raw_sha256=identity.sha(path))
        result['stage'] = 'runtime_binding'
        host.validate_binding(declaration.get('runtime'))
        result['stage'] = 'worker_owner'
        result['worker_image'] = validate_owner(worker_pid)
        result['stage'] = 'runtime_images'
        images = declaration['runtime']['images']
        host.bind_runtime(images['godot_console']['path'], images['powershell_host']['path'])
        result['stage'] = 'source_freeze'
        result['freeze'] = current_freeze(declaration['source_snapshot']['head'], result['command_receipts'])
        result.update(ok=True, stage='complete')
    except (ValueError, OSError, KeyError, TypeError, transport.CommandRefused) as error:
        result.update(failure_code=str(error), exception_type=type(error).__name__)
        if isinstance(error, transport.CommandRefused):
            result['failed_command'] = error.receipt
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preflight', type=Path, required=True)
    parser.add_argument('--worker-pid', type=int, required=True)
    args = parser.parse_args()
    result = inspect_request(args.preflight, args.worker_pid)
    print(json.dumps(result, separators=(',', ':')))
    raise SystemExit(0 if result['ok'] else 1)
