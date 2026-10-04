"""Reusable development-only batches. Fresh identities, exact bytes, bounded worlds.

The retained V28 binary has its own historical source binding; the current tree
manifest binds the host scripts, not a claim that today's Rust built that DLL.
"""
import argparse
import copy
import ctypes
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
HERE = ROOT / 'sdk/discovery'
WORKER = 'res://sdk/discovery/recovery_discovery_worker_v1.gd'
ROLE = 'kick_passive_recovery_resume'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json'
TEMPLATE = EVIDENCE / 'development-recovery-smoke-0f483029e5e649ddad83f0d83eb7e138/declaration.json'
ENV = 'SPORESPORE_DISCOVERY_DECLARATION'
FLAGS = ('official_qualification', 'physical_acceptance_authority', 'release_authority')


def require(value, code):
    if not value:
        raise ValueError(code)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def digest(data):
    return 'sha256:' + hashlib.sha256(data).hexdigest()


def binding(path):
    path = Path(path)
    with path.open('rb') as stream:
        sha = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size,
                raw_sha256=sha)


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())


def verify_binding(value, base=None):
    path = (base / value['path']) if base else Path(value['path'])
    current = binding(path)
    require(current['raw_sha256'] == value['raw_sha256'] and current['byte_length'] == value['byte_length'],
            'BINDING:' + str(path))


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def repository():
    require(git('rev-parse', '--show-toplevel').replace('\\', '/') == ROOT.as_posix(), 'REPO_ROOT')
    require(git('remote', 'get-url', 'origin') == 'https://github.com/Slagathore/LoColemotion.git', 'REPO_REMOTE')


def validate_design(value):
    require(value['schema_version'] == 'sporespore_recovery_discovery_batch_v1', 'SCHEMA')
    require(all(value.get(k) is False for k in FLAGS), 'CLAIM')
    phases = value['phases']
    require(len(phases) == len(set(phases)) and 1 <= len(phases) <= 360, 'PHASES')
    require(all(type(p) is int and 0 <= p < 360 for p in phases), 'PHASE')
    require(value['actuation_modes'] == ['passive', 'zero_velocity_brake'], 'ACTUATION')
    require(value['impulses_ns'] == [0.0, 0.25], 'IMPULSES')
    require(value['direction'] == 'positive_task_lateral', 'DIRECTION')
    require(value['tail_steps'] == 240 and value['maximum_solver_steps'] == 592, 'BOUNDS')
    require(value['physics_hz'] == 120 and value['prefix_steps'] == 30, 'TIMING')
    require(value['timeout_seconds'] == 900 and 1 <= value['initial_workers'] <= value['maximum_workers'] <= 4, 'HOST_BOUNDS')
    return value


def cells(design):
    validate_design(design)
    return [dict(cell_id=f'p{p:03d}_i{int(i*100):02d}_{m}', phase=p, impulse_ns=i,
                 actuation=m, direction=design['direction'], tail_steps=design['tail_steps'])
            for p, i, m in itertools.product(design['phases'], design['impulses_ns'], design['actuation_modes'])]


def source_files():
    names = subprocess.check_output(['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
    extensions = {'.gd', '.gdextension', '.json', '.py', '.ps1', '.cs', '.rs', '.toml', '.godot', '.tscn', '.tres'}
    return sorted({n for n in names if n and ((Path(n).suffix in extensions and
                   (n.startswith(('sdk/', 'tests/', 'scripts/')) or n == 'project.godot'))
                   or n in ['AGENTS.md', '.gitattributes', 'sdk/Cargo.lock'])})


def manifest(folder, design):
    rows = []
    with zipfile.ZipFile(folder / 'source.zip', 'x', zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        for name in source_files():
            data = (ROOT / name).read_bytes()
            rows.append(dict(path=name, byte_length=len(data), raw_sha256=digest(data)))
            archive.writestr(name, data)
    host = read(ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json')
    runtime = read(ROOT / read(PROFILE)['runtime_binding'][6:])
    images = {k: v for k, v in host['images'].items() if k != 'sdk_adapter'}
    images['candidate_dll'] = runtime['runtime']
    for value in images.values():
        verify_binding(value)
    value = dict(schema_version='sporespore_discovery_manifest_v1', head=git('rev-parse', 'HEAD'),
                 owned_status=git('status', '--short'), source_files=rows, source_archive=binding(folder / 'source.zip'),
                 runtime=dict(images=images), design=design, retained_binary_provenance=read(PROFILE),
                 physical_acceptance_authority=False, release_authority=False)
    write_new(folder / 'manifest.json', value)
    return value


def verify_manifest(path):
    value = read(path)
    require(value['head'] == git('rev-parse', 'HEAD'), 'SOURCE_HEAD')
    require([r['path'] for r in value['source_files']] == source_files(), 'SOURCE_INVENTORY')
    for row in value['source_files']:
        verify_binding(row, ROOT)
    for row in value['runtime']['images'].values():
        verify_binding(row)
    return value


def validate_cell(path, qualification_only=False):
    if read(path).get('discovery_kind') == 'full_recovery_panel_v1':
        import recovery_panel
        return recovery_panel.validate_cell(path, qualification_only)
    repository()
    path = Path(path).resolve()
    require(path.parent.parent == EVIDENCE and path.parent.name.startswith('development-recovery-smoke-'), 'CELL_PATH')
    value = read(path)
    require(all(value.get(k) is False for k in FLAGS), 'CELL_CLAIM')
    batch = Path(value['discovery_batch']).resolve()
    require(batch.parent == EVIDENCE and batch.name.startswith('recovery-discovery-'), 'BATCH_PATH')
    verify_binding(value['discovery_manifest'])
    source = verify_manifest(batch / 'manifest.json')
    require(value['discovery_manifest']['path'] == (batch / 'manifest.json').as_posix(), 'MANIFEST_PATH')
    require(value['discovery_cell'] in cells(source['design']), 'UNDECLARED_CELL')
    require(value['seed'] == 80000 + value['discovery_cell']['phase'], 'SEED_PHASE')
    require(value['worker_resource'] == WORKER and value['runtime'] == source['runtime'], 'ROUTE_RUNTIME')
    require(value['source_snapshot']['head'] == source['head'], 'SOURCE')
    require(len(value['children']) == 1 and value['children'][0]['role'] == ROLE, 'CHILDREN')
    require(value['attempt_id'] == path.parent.name.removeprefix('development-recovery-smoke-'), 'ATTEMPT')
    child = value['children'][0]
    require(child['evidence_path'] == (path.parent / 'children' / ROLE).as_posix(), 'CHILD_PATH')
    require(value['candidate_profile'] == dict(resource='res://' + PROFILE.relative_to(ROOT).as_posix(), raw_sha256=binding(PROFILE)['raw_sha256']), 'PROFILE')
    if not qualification_only:
        gate = read(batch / 'qualification.json')
        require(gate['ok'] is True and gate['manifest'] == value['discovery_manifest'], 'GATE')
        verify_binding(gate['test_receipt'])
        require(read(gate['test_receipt']['path'])['ok'] is True, 'TEST_RECEIPT')
    return value


def clean_environment():
    return {k: v for k, v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_', 'SPORESPORE_DISCOVERY_', 'SPORE_R10'))}


def process(folder, name, command, environment=None, timeout=180, test_stderr=False):
    start = time.monotonic()
    outpath, errpath = folder / (name + '.stdout.txt'), folder / (name + '.stderr.txt')
    with outpath.open('xb') as out, errpath.open('xb') as err:
        with subprocess.Popen(list(map(str, command)), cwd=ROOT, env=environment or clean_environment(), stdout=out, stderr=err,
                              creationflags=subprocess.CREATE_NO_WINDOW) as proc:
            timed_out = False
            try:
                code = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                proc.kill()
                code = proc.wait()
    receipt = dict(exit_code=code, timed_out=timed_out, seconds=time.monotonic()-start, stdout=binding(outpath), stderr=binding(errpath))
    write_new(folder / (name + '.process.json'), receipt)
    require(code == 0 and not timed_out and (test_stderr or errpath.stat().st_size == 0), 'PROCESS:' + name)
    return receipt


def prepare(design_path):
    repository()
    design = validate_design(read(design_path))
    folder = EVIDENCE / ('recovery-discovery-' + uuid.uuid4().hex)
    folder.mkdir()
    source = manifest(folder, design)
    source_binding = binding(folder / 'manifest.json')
    children = []
    for cell in cells(design):
        template = read(TEMPLATE)
        inherited = ['schema_version', 'maximum_precondition_steps', 'walking_prefix_steps', 'interaction_steps',
                     'after_interaction_steps', 'maximum_steps_per_child', 'maximum_passive_descent_steps',
                     'step_cost_profile_id', 'context_cache_profile_id', 'context_cache_call_sites',
                     'diagnostic_schedule_id', 'passive_entry_runtime', 'candidate_profile',
                     'development_execution_mode', 'comparative_authority', 'baseline_reused', *FLAGS]
        value = {k: copy.deepcopy(template[k]) for k in inherited}
        attempt, child_id, nonce = [uuid.uuid4().hex for _ in range(3)]
        cell_folder = EVIDENCE / ('development-recovery-smoke-' + attempt)
        child_folder = cell_folder / 'children' / ROLE
        child_folder.mkdir(parents=True)
        value.update(attempt_id=attempt, children=[dict(role=ROLE, child_attempt_id=child_id, termination_nonce=nonce, evidence_path=child_folder.as_posix())],
                     source_snapshot=dict(head=source['head'], dirty=bool(source['owned_status']), status=source['owned_status'].splitlines()),
                     runtime=source['runtime'], seed=80000+cell['phase'], worker_resource=WORKER,
                     discovery_batch=folder.as_posix(), discovery_manifest=source_binding, discovery_cell=cell,
                     ledger_scope=design['ledger_scope'], timeout_seconds_per_child=design['timeout_seconds'])
        # Internal setup profile is inherited; the discovery cell separately owns
        # actual disturbance inputs and a smaller enforced total-step ceiling.
        value.update(coverage_question=design['question'], uncovered_paths=design['uncovered'],
                     telemetry_profile=design['telemetry'], maximum_discovery_solver_steps=design['maximum_solver_steps'])
        proposal = cell_folder / 'proposal.json'
        write_new(proposal, value)
        children.append(dict(cell=cell, folder=cell_folder.as_posix()))
    write_new(folder / 'cells.json', children)
    print(json.dumps(dict(batch=folder.as_posix(), cells=len(children))))


def qualify(folder):
    folder = Path(folder)
    source = verify_manifest(folder / 'manifest.json')
    rows = read(folder / 'cells.json')
    # Actual candidate load, runtime preparation and exact launch-context transfer.
    # No world may be constructed by either probe.
    shared_prepared = None
    for index, row in enumerate(rows):
        cell_folder = Path(row['folder'])
        value = read(cell_folder / 'proposal.json')
        write_new(cell_folder / 'declaration.json', value)
        environment = clean_environment()
        environment[ENV] = (cell_folder / 'declaration.json').as_posix()
        if index == 0:
            process(cell_folder, 'prepare', [source['runtime']['images']['godot_engine']['path'], '--headless', '--path', ROOT,
                    '--script', WORKER, '--', 'prepare', cell_folder / 'prepared-context.json'], environment)
            shared_prepared = read(cell_folder / 'prepared-context.json')
        else:
            # This is immutable zero-world context data, never a physical baseline.
            write_new(cell_folder / 'prepared-context.json', shared_prepared)
        # Declaration bytes never overwritten; prepared expectation is supplied by
        # the launch environment and separately bound by the qualification receipt.
        prepared = read(cell_folder / 'prepared-context.json')
        require(prepared['ok'] is True and prepared['world_build_count'] == prepared['solver_step_count'] == 0, 'PREPARED')
    process(folder, 'environment-batch', [source['runtime']['images']['powershell_host']['path'], '-NoProfile', '-File',
            HERE / 'recovery_discovery_environment.ps1', '-Batch', folder])
    first = Path(rows[0]['folder'])
    environment = clean_environment()
    environment.update(read(first / 'environment.json')['environment'])
    process(first, 'preworld', [source['runtime']['images']['godot_engine']['path'], '--headless', '--path', ROOT,
            '--script', WORKER, '--', 'preworld', first / 'preworld.json'], environment)
    require(read(first / 'preworld.json')['ok'] is True, 'PREWORLD')
    print(f'BOUND_AND_PREWORLD_CHECKED {len(rows)} cells', flush=True)
    process(folder, 'safety-tests', [sys.executable, '-B', '-X', 'utf8', HERE / 'test_recovery_discovery.py', folder], timeout=600)
    verify_manifest(folder / 'manifest.json')
    write_new(folder / 'qualification.json', dict(ok=True, manifest=binding(folder / 'manifest.json'),
              test_receipt=binding(folder / 'safety-tests.json'), cells=rows, world_build_count=0, solver_step_count=0,
              physical_acceptance_authority=False, release_authority=False))


def image_path(pid):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.restype = ctypes.c_void_p
    handle = kernel.OpenProcess(0x1000, False, pid)
    require(handle, 'PROCESS_HANDLE')
    try:
        buffer = ctypes.create_unicode_buffer(32768)
        length = ctypes.c_ulong(len(buffer))
        require(kernel.QueryFullProcessImageNameW(ctypes.c_void_p(handle), 0, buffer, ctypes.byref(length)), 'PROCESS_IMAGE')
        return Path(buffer.value).as_posix()
    finally:
        kernel.CloseHandle(ctypes.c_void_p(handle))


def claim(path, pid):
    value = validate_cell(path)
    require(pid == os.getppid(), 'WORKER_PARENT')
    require(image_path(pid).lower() == value['runtime']['images']['godot_engine']['path'].lower(), 'WORKER_IMAGE')
    child = value['children'][0]
    require(os.environ.get('SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE') == child['termination_nonce'], 'NONCE')
    sys.path.insert(0, str(ROOT / 'sdk/conformance'))
    import r10v_windows_job as jobs
    permit = read(Path(child['evidence_path']) / 'job-permit.json')
    require(permit['job_bound'] is True and permit['child_attempt_id'] == child['child_attempt_id'], 'JOB_PERMIT')
    require(jobs.alive(permit['leaf_identity']) and jobs.alive(permit['coordinator_identity']) and jobs.current_in_job(), 'JOB_OWNER_LIFETIME')
    require(image_path(permit['leaf_pid']).lower() == value['runtime']['images']['powershell_host']['path'].lower(), 'LEAF_IMAGE')
    receipt = dict(worker_pid=pid, declaration=binding(path), world_build_limit=1,
                   physical_acceptance_authority=False, release_authority=False)
    write_new(Path(child['evidence_path']) / 'world-claim.json', receipt)
    print(json.dumps(dict(ok=True)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'qualify', 'verify-cell', 'claim', 'audit'])
    parser.add_argument('path', type=Path)
    parser.add_argument('--qualification-only', action='store_true')
    parser.add_argument('--worker-pid', type=int)
    parser.add_argument('--cell-id')
    args = parser.parse_args()
    if args.action == 'prepare': prepare(args.path)
    elif args.action == 'qualify': qualify(args.path)
    elif args.action == 'verify-cell':
        validate_cell(args.path, args.qualification_only)
        print(json.dumps(dict(ok=True, declaration_sha256=binding(args.path)['raw_sha256'])))
    elif args.action == 'claim': claim(args.path, args.worker_pid)
    elif args.action == 'audit':
        if read(args.path/'manifest.json')['design']['schema_version'] in ('sporespore_full_recovery_discovery_panel_v1','sporespore_full_recovery_discovery_panel_v2'):
            from recovery_panel_reader import audit_batch
        else:
            from recovery_discovery_reader import audit_batch
        audit_batch(args.path, args.cell_id)


if __name__ == '__main__':
    main()
