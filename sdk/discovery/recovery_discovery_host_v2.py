"""Detached, bounded owner for discovery physical pools.

Uses the established R10X breakaway/job pattern. Redirected coordinator
children use the original CREATE_NO_WINDOW launch behavior.
A surviving descendant still refuses the result; no image-name exemption exists.
 The interactive launcher may
exit; the durable owner persists. Losing the owner reaps its entire job.
"""
import argparse
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

import recovery_discovery as D
import recovery_owned_cleanup_v1 as Cleanup
sys.path.insert(0, str(D.ROOT / 'sdk/conformance'))
import r10v_windows_job as W

SCRIPT = Path(__file__).resolve()
FIXTURE = D.HERE / 'recovery_discovery_host_fixture_v2.py'
NESTED = D.HERE / 'recovery_discovery_nested_fixture_v2.ps1'
COORDINATOR = D.HERE / 'recovery_discovery_coordinator_fixture_v2.ps1'
PYTHON = Path('C:/Program Files/Python311/python.exe')
PWSH = Path('C:/Program Files/PowerShell/7/pwsh.exe')
SCHEMA = 'sporespore_discovery_durable_host_v2'
SCOPE = dict(subsystem='recovery', engine_scope='godot_jolt',
             authority_mode='development_discovery_host', question_class='development')


def fixed_bindings():
    return [D.binding(p) for p in (SCRIPT, FIXTURE, NESTED, COORDINATOR, Path(Cleanup.__file__), Path(D.__file__), Path(W.__file__), PYTHON, PWSH)]


def validate_population(value, source, rows):
    selected = value['selected_cells']
    D.require(1 <= value['workers'] <= source['design']['maximum_workers'], 'HOST_WORKERS')
    D.require(len(selected) == value['maximum_cells']
              and all(row in rows for row in selected)
              and len({row['cell']['cell_id'] for row in selected}) == len(selected), 'HOST_SELECTED_POPULATION')


def command(path, value):
    if value['mode'] == 'fixture':
        if value['case'] == 'nested_coordinator':
            return [str(PWSH), '-NoProfile', '-File', str(COORDINATOR), '-RequestPath', str(path)]
        return [str(PYTHON), '-B', str(FIXTURE), str(path)]
    if value['mode'] == 'r10dh':
        return [str(PWSH), '-NoProfile', '-File', str(D.ROOT/'sdk/conformance/run_r10dh_campaign.ps1'),
                '-Batch', value['batch'], '-MaximumCells', str(value['maximum_cells']), '-Workers', '1']
    return [str(PWSH), '-NoProfile', '-File', str(D.HERE/'run_recovery_discovery.ps1'),
            '-Batch', value['batch'], '-MaximumCells', str(value['maximum_cells']), '-Workers', str(value['workers'])]


def validate_shape(value):
    D.require(value['schema_version'] == SCHEMA and value['mode'] in ('fixture', 'run', 'r10dh'), 'HOST_SCHEMA')
    D.require(all(value[k] is False for k in D.FLAGS), 'HOST_CLAIMS')
    D.require(type(value['deadline_seconds']) is int and 1 <= value['deadline_seconds'] <= 75000, 'HOST_DEADLINE')
    if value['mode'] == 'fixture':
        D.require(value['case'] in ('success', 'nonzero', 'missing', 'hang', 'orphan', 'nested_pool', 'nested_orphan', 'nested_coordinator')
                  and type(value['hold_seconds']) in (float, int) and 0 <= value['hold_seconds'] <= 30
                  and value['deadline_seconds'] <= (120 if value['case'].startswith('nested_') else 90)
                  and value['batch'] is None, 'HOST_FIXTURE')
    else:
        D.require(value['case'] is None and value['hold_seconds'] == 0, 'HOST_PHYSICAL_FIXTURE_CROSS')
        D.require(type(value['maximum_cells']) is int and 1 <= value['maximum_cells'] <= 24
                      and type(value['workers']) is int and 1 <= value['workers'] <= 4
                      and value['deadline_seconds'] == math.ceil(value['maximum_cells']/value['workers'])*3090+120,
                      'HOST_POOL_BOUNDS')
        if value['mode'] == 'r10dh':
            D.require(value['maximum_cells'] in (2, 6) and value['workers'] == 1, 'HOST_R10DH_SERIAL_POPULATION')


def request(path, live=True):
    path = Path(path).resolve()
    D.require(path.name == 'request.json' and path.parent.parent == D.EVIDENCE
              and path.parent.name.startswith('discovery-host-v2-'), 'HOST_PATH')
    v = D.read(path); validate_shape(v)
    D.require(path.parent.name == 'discovery-host-v2-'+v['id'] and len(v['id']) == 32
              and all(c in '0123456789abcdef' for c in v['id']), 'HOST_ID')
    D.require(v['command'] == command(path, v), 'HOST_COMMAND')
    if live:
        D.repository()
        D.require(v['bindings'] == fixed_bindings(), 'HOST_SOURCE_BINDINGS')
        if v['mode'] == 'r10dh':
            import r10dh_dependency_manifest as M
            import r10dh_contract as C
            b = Path(v['batch']).resolve()
            D.require(b.parent == D.EVIDENCE, 'HOST_R10DH_PATH')
            prepared = C.read(b/'prepared.json')
            D.require(prepared['qualification_only'] is False, 'HOST_R10DH_PHYSICAL_PREPARATION')
            rows = C.read(b/'cells.json'); C.validate_population([r['cell'] for r in rows], prepared['mode'])
            D.require(v['selected_cells'] == rows and v['maximum_cells'] == len(rows), 'HOST_R10DH_EXACT_POPULATION')
            D.require(v['manifest'] == D.binding(b/'manifest.json'), 'HOST_R10DH_MANIFEST')
            M.validate(C.read(b/'manifest.json'))
        elif v['mode'] != 'fixture':
            b = Path(v['batch']).resolve()
            D.require(b.parent == D.EVIDENCE and b.name.startswith('recovery-discovery-'), 'HOST_BATCH')
            D.require(v['manifest'] == D.binding(b/'manifest.json'), 'HOST_MANIFEST')
            source = D.verify_manifest(b/'manifest.json')
            validate_population(v, source, D.read(b/'cells.json'))
            D.verify_binding(v['qualification'])
            gate = D.read(b/'qualification.json')
            D.require(v['qualification'] == D.binding(b/'qualification.json') and gate['ok'] is True
                      and gate['manifest'] == v['manifest'], 'HOST_GATE')
            D.verify_binding(gate['test_receipt'])
            D.require(not (b/'commission-closed.json').exists(), 'HOST_RETIRED_BATCH')
    return v


def prepare(mode, batch=None, maximum=1, workers=1, case='success', hold=4, deadline=30):
    D.repository()
    root = D.EVIDENCE/('discovery-host-v2-'+uuid.uuid4().hex); root.mkdir()
    path = root/'request.json'
    selected = []; manifest = None
    qualification = None
    if mode == 'r10dh':
        import r10dh_authority as A
        import r10dh_contract as C
        batch = Path(batch).resolve(); prepared = C.read(batch/'prepared.json')
        A.validate_launch(prepared['mode'])
        selected = C.read(batch/'cells.json'); C.validate_population([r['cell'] for r in selected], prepared['mode'])
        D.require(maximum == len(selected) and workers == 1, 'HOST_R10DH_PREPARE_POPULATION')
        manifest = D.binding(batch/'manifest.json'); case, hold = None, 0
        deadline = maximum*3090+120
    elif mode != 'fixture':
        batch = Path(batch).resolve(); source = D.verify_manifest(batch/'manifest.json')
        manifest = D.binding(batch/'manifest.json')
        D.require(not (batch/'commission-closed.json').exists(), 'HOST_RETIRED_BATCH')
        case, hold = None, 0
        D.require(D.read(batch/'qualification.json')['ok'] is True, 'HOST_QUALIFICATION')
        D.require(1 <= workers <= source['design']['maximum_workers'], 'HOST_WORKERS')
        selected = [r for r in D.read(batch/'cells.json') if not
                    (Path(r['folder'])/'children'/r['cell']['role']/'launch-reservation.json').exists()][:maximum]
        D.require(len(selected) == maximum, 'HOST_FRESH_POPULATION')
        deadline = math.ceil(maximum/workers)*3090+120
        qualification = D.binding(batch/'qualification.json')
    v = dict(schema_version=SCHEMA, ledger_scope=SCOPE, id=root.name.removeprefix('discovery-host-v2-'),
             mode=mode, batch=None if batch is None else batch.as_posix(), manifest=manifest,
             maximum_cells=maximum, workers=workers, case=case, hold_seconds=hold, deadline_seconds=deadline,
             selected_cells=selected, qualification=qualification,
             bindings=fixed_bindings(), official_qualification=False,
             physical_acceptance_authority=False, release_authority=False)
    v['command'] = command(path, v); validate_shape(v); D.write_new(path, v)
    request(path)
    return path


def launch(path):
    path = Path(path).resolve(); request(path); root = path.parent
    D.write_new(root/'launch-reservation.json', dict(request=D.binding(path), retry=False))
    with (root/'host.stdout.txt').open('xb') as out, (root/'host.stderr.txt').open('xb') as err:
        # Same flags as R10X: refuse if breakaway is unavailable, never fall back
        # to inheriting the lifetime of the interactive caller's Windows job.
        proc = subprocess.Popen([str(PYTHON), '-B', str(SCRIPT), 'host', str(path)], cwd=D.ROOT,
                                stdin=subprocess.DEVNULL, stdout=out, stderr=err, close_fds=True,
                                creationflags=0x01000000 | 0x00000008 | 0x00000200)
    identity = W.identity(proc.pid); D.require(identity is not None, 'HOST_START')
    identity.pop('running')
    D.write_new(root/'launch.json', dict(request=D.binding(path), host_identity=identity))
    return dict(root=root.as_posix(), host_identity=identity)


def worker(path):
    path = Path(path).resolve(); v = request(path); root = path.parent
    limit = time.monotonic()+30
    while not (root/'job-assigned.json').exists():
        D.require(time.monotonic() < limit, 'HOST_ASSIGNMENT_TIMEOUT'); time.sleep(.05)
    assigned = D.read(root/'job-assigned.json')
    D.require(assigned['worker_identity'] == W.current_identity() and assigned['request'] == D.binding(path)
              and W.current_in_job(), 'HOST_ASSIGNMENT_CROSSED')
    child = subprocess.Popen(v['command'], cwd=D.ROOT, env=D.clean_environment(), stdin=subprocess.DEVNULL,
                             stdout=sys.stdout, stderr=sys.stderr, creationflags=subprocess.CREATE_NO_WINDOW)
    identity = W.identity(child.pid); D.require(identity is not None, 'HOST_COMMAND_START')
    D.write_new(root/'command-started.json', dict(request=D.binding(path), identity=identity, command=v['command']))
    return child.wait()


def primary(path, v):
    root = path.parent
    if v['mode'] == 'fixture':
        result = D.read(root/'fixture-terminal.json')
        D.require(result == dict(ok=True, request=D.binding(path), world_build_count=0, solver_step_count=0), 'HOST_FIXTURE_TERMINAL')
        return [D.binding(root/'fixture-terminal.json')]
    if v['mode'] == 'r10dh':
        batch = Path(v['batch']); terminal = D.read(batch/'supervisor-result.json')
        D.require(terminal['ok'] is True and terminal['source_unchanged'] is True, 'HOST_R10DH_TERMINAL')
        D.require([r['cell'] for r in terminal['cells']] == [r['cell'] for r in v['selected_cells']]
                  and all(r['valid'] is True for r in terminal['cells']), 'HOST_R10DH_READER_POPULATION')
        return [D.binding(batch/'supervisor-result.json')]
    batch = Path(v['batch'])
    bindings = []
    for row in v['selected_cells']:
        c = Path(row['folder'])/'children'/row['cell']['role']
        audit = D.read(c/'discovery-audit.json'); process = D.read(c/'pool-process.json')
        D.require(audit['valid'] is True and audit['cell'] == row['cell'] and process['exit_code'] == 0
                  and process['cell'] == row['cell'], 'HOST_CELL_TERMINAL')
        bindings.extend([D.binding(c/'discovery-audit.json'), D.binding(c/'pool-process.json')])
    return bindings


def snapshot_owned(root, job, name):
    rows = []
    for pid in job.pids():
        identity = W.identity(pid)
        try: image = D.image_path(pid) if identity is not None else None
        except (ValueError, OSError): image = None
        rows.append(dict(pid=pid, identity=identity, image=image))
    D.write_new(root/(name+'.json'), dict(event=name, owned_processes=rows))


def run_host(path):
    path = Path(path).resolve(); v = request(path); root = path.parent
    D.require(not W.current_in_job(), 'HOST_STILL_IN_CALLER_JOB')
    me = W.current_identity(); bound = D.binding(path)
    D.write_new(root/'host-started.json', dict(identity=me, request=bound, in_caller_job=False))
    job = W.Job(); proc = None; failure = ''; outputs = []; start = time.monotonic(); cancelled = False
    try:
        with (root/'command.stdout.txt').open('xb') as out, (root/'command.stderr.txt').open('xb') as err:
            proc = subprocess.Popen([str(PYTHON), '-B', str(SCRIPT), 'worker', str(path)], cwd=D.ROOT,
                                    stdin=subprocess.DEVNULL, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            job.add(proc); ident = W.identity(proc.pid); D.require(ident is not None, 'HOST_WORKER_START'); ident.pop('running')
            D.write_new(root/'job-assigned.json', dict(worker_identity=ident, host_identity=me, request=bound, kill_on_close=True))
            while proc.poll() is None:
                D.require(time.monotonic()-start < v['deadline_seconds'], 'HOST_DEADLINE_EXCEEDED')
                D.require(D.binding(path) == bound, 'HOST_REQUEST_DRIFT')
                cancel = root/'cancel.json'
                if cancel.exists() and not cancelled:
                    cancelled = True
                    if D.read(cancel) == dict(request=bound, host_identity=me):
                        raise ValueError('HOST_OWNED_CANCELLATION')
                    D.write_new(root/'cancel-refused.json', dict(reason='crossed_identity', cancel=D.binding(cancel)))
                time.sleep(.2)
            D.require(proc.returncode == 0, 'HOST_COMMAND_NONZERO')
            snapshot_owned(root, job, "owner-drain-start")
            drain = time.monotonic()+5
            while job.pids() and time.monotonic() < drain: time.sleep(.05)
            snapshot_owned(root, job, 'owner-drain-end')
            D.require(not job.pids(), 'HOST_ORPHAN_DESCENDANT')
            outputs = primary(path, v)
            request(path)
    except BaseException:
        failure = traceback.format_exc()
    finally:
        snapshot_owned(root, job, "owner-cleanup-start")
        owned = job.pids()
        if owned: job.terminate()
        # Assignment itself can fail. The proxy has not received its permit
        # in that case and must be reaped directly, before it starts a child.
        if proc is not None and proc.poll() is None:
            if proc.pid not in owned: proc.kill()
            proc.wait(timeout=15)
        limit = time.monotonic()+10
        while job.pids() and time.monotonic() < limit: time.sleep(.05)
        snapshot_owned(root, job, "owner-cleanup-end")
        clean = not job.pids(); job.close()
    result = dict(schema_version=SCHEMA, ledger_scope=SCOPE, request=bound, host_identity=me,
                  ok=not failure and clean, error=failure, owned_cleanup_complete=clean,
                  command_exit_code=None if proc is None else proc.returncode, elapsed_seconds=time.monotonic()-start,
                  lifecycle_receipts=[D.binding(p) for p in sorted(root.glob('owner-*.json'))],
                  primary=outputs, logs=[D.binding(root/n) for n in ('command.stdout.txt', 'command.stderr.txt') if (root/n).exists()],
                  official_qualification=False, physical_acceptance_authority=False, release_authority=False)
    D.write_new(root/'host-result.json', result)
    D.write_new(root/'published.json', dict(request=bound, result=D.binding(root/'host-result.json')))
    return 0 if result['ok'] else 1


def status(root):
    root = Path(root).resolve(); path = root/'request.json'; request(path, live=False)
    launch_record = D.read(root/'launch.json'); D.require(launch_record['request'] == D.binding(path), 'HOST_STATUS_REQUEST')
    alive = W.alive(launch_record['host_identity']); result = root/'host-result.json'
    if result.exists():
        value = D.read(result)
        D.require(value['request'] == D.binding(path) and value['host_identity'] == launch_record['host_identity'], 'HOST_STATUS_IDENTITY')
        D.require(D.read(root/'published.json') == dict(request=D.binding(path), result=D.binding(result)), 'HOST_PUBLICATION')
        for binding in value['primary']+value['logs']+value['lifecycle_receipts']: D.verify_binding(binding)
        return dict(state='complete' if value['ok'] else 'failed', host_alive=alive, result=value)
    return dict(state='running' if alive else 'lost_without_terminal', host_alive=alive)


if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('action', choices=('start', 'host', 'worker', 'status'))
    p.add_argument('path', type=Path); p.add_argument('--mode', choices=('run',), default='run')
    p.add_argument('--maximum', type=int, default=1); p.add_argument('--workers', type=int, default=1)
    a = p.parse_args()
    if a.action == 'host': raise SystemExit(run_host(a.path))
    if a.action == 'worker': raise SystemExit(worker(a.path))
    if a.action == 'start': print(__import__('json').dumps(launch(prepare(a.mode, a.path, a.maximum, a.workers))))
    else: print(__import__('json').dumps(status(a.path)))
