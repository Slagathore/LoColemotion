"""Exact finite-campaign declarations and the last gate before world construction."""
import argparse
import copy
import json
import os
from pathlib import Path
import sys
import uuid
import r10dh_contract as C
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D
import r10v_windows_job as W

INHERITED = ('schema_version', 'maximum_precondition_steps', 'walking_prefix_steps', 'interaction_steps',
             'after_interaction_steps', 'maximum_steps_per_child', 'maximum_passive_descent_steps',
             'step_cost_profile_id', 'context_cache_profile_id', 'context_cache_call_sites',
             'diagnostic_schedule_id', 'passive_entry_runtime', 'candidate_profile',
             'comparative_authority', 'baseline_reused', *C.FLAGS)


def clean_environment():
    return {k: v for k, v in D.clean_environment().items() if not k.startswith('SPORESPORE_R10DH_')}


def declaration(batch, manifest, cell, mode, attempt, child_id, nonce, source):
    template = C.read(D.TEMPLATE)
    value = {k: copy.deepcopy(template[k]) for k in INHERITED}
    folder = C.EVIDENCE/('development-recovery-smoke-'+attempt)
    context = dict(schema_version='sporespore_r10dh_campaign_child_context_v1', mode=mode,
        campaign_root=batch.as_posix(), cell_id=cell['cell_id'], role=cell['role'], seed=cell['seed'],
        manifest=D.binding(batch/'manifest.json'), task_contract=D.binding(C.TASK),
        design=D.binding(C.DESIGN), production_route_key=manifest['production_route_key'])
    value.update(attempt_id=attempt, children=[dict(role=cell['role'], child_attempt_id=child_id,
        termination_nonce=nonce, evidence_path=(folder/'children'/cell['role']).as_posix())],
        source_snapshot=source, runtime=manifest['runtime'], seed=cell['seed']['seed'],
        worker_resource=C.WORKER, campaign_kind='r10dh_finite_recovery_v1', r10dh_campaign=context,
        ledger_scope=C.SCOPE, timeout_seconds_per_child=1800, reader_timeout_seconds=1200,
        development_execution_mode='r10dh_fresh_role_v1', report_publication='direct_file_v1',
        coverage_question='Complete finite prone recovery, fresh walking and settled stop through the production route',
        uncovered_paths=C.read(C.DESIGN)['uncovered'],
        telemetry_profile=C.read(C.TASK)['telemetry'])
    return value


def prepare(mode, *, qualification_only=True):
    D.repository(); C.validate_design(C.read(C.DESIGN)); C.validate_task(C.read(C.TASK))
    C.require(mode in C.MODES, 'MODE')
    # Preparation is zero-world. The independent authority gate is checked at
    # launch and again at construction; a prepared file never grants a world.
    if not qualification_only:
        import r10dh_authority as A
        A.validate_launch(mode)
    batch = C.EVIDENCE/('r10dh-'+mode+'-'+uuid.uuid4().hex)
    batch.mkdir()
    manifest = M.snapshot(); D.write_new(batch/'manifest.json', manifest)
    archive = M.archive(batch, manifest)
    source = dict(head=D.git('rev-parse', 'HEAD'), dirty=bool(D.git('status', '--short')),
                  status=D.git('status', '--short').splitlines())
    rows = []
    for cell in C.population(mode):
        attempt, child_id, nonce = (uuid.uuid4().hex for _ in range(3))
        value = declaration(batch, manifest, cell, mode, attempt, child_id, nonce, source)
        folder = C.EVIDENCE/('development-recovery-smoke-'+attempt)
        Path(value['children'][0]['evidence_path']).mkdir(parents=True)
        D.write_new(folder/'declaration.json', value)
        rows.append(dict(cell=cell, folder=folder.as_posix(), declaration=D.binding(folder/'declaration.json')))
    D.write_new(batch/'cells.json', rows)
    D.write_new(batch/'prepared.json', dict(mode=mode, qualification_only=qualification_only,
        source_snapshot=source, manifest=D.binding(batch/'manifest.json'), source_archive=archive,
        cells=D.binding(batch/'cells.json'), world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False))
    return batch


def validate_cell(path, qualification_only=False):
    D.repository(); path = Path(path).resolve()
    C.require(path.name == 'declaration.json' and path.parent.parent == C.EVIDENCE
              and path.parent.name.startswith('development-recovery-smoke-'), 'DECLARATION_PATH')
    value = C.read(path); context = value['r10dh_campaign']; mode = context['mode']
    C.require(mode in C.MODES, 'MODE')
    batch = Path(context['campaign_root']).resolve()
    C.require(batch.parent == C.EVIDENCE and batch.name.startswith('r10dh-'+mode+'-'), 'CAMPAIGN_PATH')
    prepared = C.read(batch/'prepared.json')
    D.verify_binding(prepared['cells']); D.verify_binding(prepared['manifest'])
    C.require(prepared['cells'] == D.binding(batch/'cells.json') and prepared['manifest'] == D.binding(batch/'manifest.json'), 'PREPARED_PATHS')
    manifest = C.read(batch/'manifest.json'); M.validate(manifest)
    rows = C.read(batch/'cells.json'); C.validate_population([r['cell'] for r in rows], mode)
    selected = [r for r in rows if r['folder'] == path.parent.as_posix()]
    C.require(len(selected) == 1 and selected[0]['declaration'] == D.binding(path), 'EXACT_DECLARATION')
    row = selected[0]; child = value['children'][0]
    for name in (value['attempt_id'], child['child_attempt_id'], child['termination_nonce']):
        C.require(type(name) is str and len(name) == 32 and all(c in '0123456789abcdef' for c in name), 'ATTEMPT_ID')
    C.require(path.parent.name == 'development-recovery-smoke-'+value['attempt_id'], 'ATTEMPT_PATH')
    expected = declaration(batch, manifest, row['cell'], mode, value['attempt_id'],
                           child['child_attempt_id'], child['termination_nonce'], prepared['source_snapshot'])
    C.require(C.same(value, expected), 'DECLARATION_CONTRACT')
    C.validate_design(C.read(C.DESIGN)); C.validate_task(C.read(C.TASK))
    if not qualification_only:
        C.require(prepared['qualification_only'] is False, 'QUALIFICATION_HAS_NO_WORLD_PERMISSION')
        import r10dh_authority as A
        A.validate_running(batch, value)
    return value


def claim(path, pid):
    value = validate_cell(path)
    C.require(type(pid) is int and pid == os.getppid(), 'WORLD_WORKER_PARENT')
    C.require(D.image_path(pid).lower() == value['runtime']['images']['godot_engine']['path'].lower(), 'WORLD_WORKER_IMAGE')
    child = value['children'][0]; folder = Path(child['evidence_path'])
    C.require(os.environ.get('SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE') == child['termination_nonce'], 'WORLD_NONCE')
    permit = C.read(folder/'job-permit.json')
    C.require(permit['job_bound'] is True and permit['child_attempt_id'] == child['child_attempt_id'], 'WORLD_JOB_PERMIT')
    C.require(W.alive(permit['leaf_identity']) and W.alive(permit['coordinator_identity']) and W.current_in_job(), 'WORLD_OWNER_LIFETIME')
    C.require(D.image_path(permit['leaf_pid']).lower() == value['runtime']['images']['powershell_host']['path'].lower(), 'WORLD_LEAF_IMAGE')
    D.write_new(folder/'world-claim.json', dict(worker_identity=W.identity(pid), declaration=D.binding(path),
        permit=D.binding(folder/'job-permit.json'), world_build_limit=1,
        physical_acceptance_authority=False, release_authority=False))


def interfaces(batch):
    batch = Path(batch); rows = C.read(batch/'cells.json')
    engine = C.read(batch/'manifest.json')['runtime']['images']['godot_engine']['path']
    for row in rows:
        folder = Path(row['folder']); path = folder/'declaration.json'
        validate_cell(path, True)
        env = clean_environment(); env[C.ENV] = path.as_posix()
        D.process(folder, 'prepare', [engine, '--headless', '--path', C.ROOT, '--script', C.WORKER,
                    '--', 'prepare', folder/'prepared-context.json'], env, timeout=180)
        v = C.read(folder/'prepared-context.json')
        C.require(v['ok'] is True and v['world_build_count'] == v['solver_step_count'] == 0, 'PREPARE_WORLD_FREE')
        import r10dh_header_wire as HeaderWire
        HeaderWire.run(folder, engine)
    D.process(batch, 'environment', [str(M.runtime()['images']['powershell_host']['path']), '-NoProfile', '-File',
        C.ROOT/'sdk/conformance/r10dh_environment.ps1', '-Batch', batch], timeout=180)
    for row in rows:
        folder = Path(row['folder']); env = clean_environment()
        env.update(C.read(folder/'environment.json')['environment'])
        D.process(folder, 'preworld', [engine, '--headless', '--path', C.ROOT, '--script', C.WORKER,
                    '--', 'preworld', folder/'preworld.json'], env, timeout=180)
        v = C.read(folder/'preworld.json')
        C.require(v['ok'] is True and v['world_build_count'] == v['solver_step_count'] == 0
                  and v['guard']['failure_code'] == 'R10DH_WORLD_PERMISSION_REFUSED', 'PREWORLD_GUARD')
    M.validate(C.read(batch/'manifest.json'))
    D.write_new(batch/'interfaces.json', dict(ok=True, cells=D.binding(batch/'cells.json'),
        artifacts=[D.binding(Path(r['folder'])/name) for r in rows for name in
                   ('prepared-context.json', 'environment.json', 'preworld.json', 'header-wire.json', 'header-wire-audit.json')],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))


def start(mode):
    import recovery_discovery_host_v2 as Host
    batch=prepare(mode,qualification_only=False)
    interfaces(batch)
    request=Host.prepare('r10dh',batch,maximum=len(C.population(mode)),workers=1)
    D.write_new(batch/'original-host.json',dict(request=D.binding(request)))
    return dict(batch=batch.as_posix(),owner=Host.launch(request))


if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('action', choices=('prepare', 'interfaces', 'verify-cell', 'claim', 'start'))
    p.add_argument('path'); p.add_argument('--qualification-only', action='store_true'); p.add_argument('--worker-pid', type=int)
    a = p.parse_args()
    if a.action == 'prepare': print(prepare(a.path).as_posix())
    elif a.action == 'start': print(json.dumps(start(a.path)),flush=True)
    elif a.action == 'interfaces': interfaces(a.path)
    elif a.action == 'verify-cell':
        validate_cell(a.path, a.qualification_only)
        print(json.dumps(dict(ok=True, declaration_sha256=D.binding(a.path)['raw_sha256'])))
    else: claim(a.path, a.worker_pid); print(json.dumps(dict(ok=True)))
