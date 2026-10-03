"""Full-route discovery successor. Shares custody utilities, not Batch A claims."""
import argparse
import copy
import itertools
import json
from pathlib import Path
import sys
import uuid
import recovery_discovery as D

KIND = 'full_recovery_panel_v1'
SCHEMA = 'sporespore_full_recovery_discovery_panel_v1'
FILE_SCHEMA = 'sporespore_full_recovery_discovery_panel_v2'
SCHEMAS = (SCHEMA, FILE_SCHEMA)
WORKER = 'res://sdk/discovery/recovery_panel_worker_v1.gd'
ROLES = ('kick_passive_recovery_resume', 'matched_no_kick_continuation')


def validate_design(value):
    D.require(value['schema_version'] in SCHEMAS, 'PANEL_SCHEMA')
    expected_publication = 'direct_file_v1' if value['schema_version'] == FILE_SCHEMA else 'stdout_json_line_v1'
    D.require(value.get('report_publication','stdout_json_line_v1') == expected_publication, 'PANEL_PUBLICATION')
    D.require(all(value.get(k) is False for k in D.FLAGS + ('baseline_reused',)), 'PANEL_CLAIM')
    phases = value['phases']
    D.require(1 <= len(phases) <= 12 and len(set(phases)) == len(phases)
              and all(type(p) is int and 0 <= p < 360 for p in phases), 'PANEL_PHASES')
    expected = dict(roles=list(ROLES), controller_variant='retained_v28',
                    allowed_recovery_entry_kinds=['partial','prone','upright'], physics_hz=120,
                    prefix_steps=30, impulse_ns=.25, direction='positive_task_lateral',
                    maximum_solver_steps=3752, maximum_no_kick_solver_steps=2552,
                    timeout_seconds=1800, reader_timeout_seconds=1200, maximum_workers=2, initial_workers=1)
    D.require(all(value.get(k) == v for k,v in expected.items()), 'PANEL_FIXED_CONTRACT')
    return value


def cells(design):
    validate_design(design)
    return [dict(cell_id=f'p{phase:03d}_'+('kick' if role == ROLES[0] else 'no_kick'),
                 phase=phase, role=role, controller_variant=design['controller_variant'])
            for phase,role in itertools.product(design['phases'],design['roles'])]


def prepare(path):
    D.repository()
    design = validate_design(D.read(path))
    batch = D.EVIDENCE/('recovery-discovery-'+uuid.uuid4().hex)
    batch.mkdir()
    source = D.manifest(batch,design)
    bound = D.binding(batch/'manifest.json')
    rows = []
    inherited = ('schema_version','maximum_precondition_steps','walking_prefix_steps','interaction_steps',
                 'after_interaction_steps','maximum_steps_per_child','maximum_passive_descent_steps',
                 'step_cost_profile_id','context_cache_profile_id','context_cache_call_sites',
                 'diagnostic_schedule_id','passive_entry_runtime','candidate_profile',
                 'comparative_authority','baseline_reused',*D.FLAGS)
    for cell in cells(design):
        template = D.read(D.TEMPLATE)
        value = {k:copy.deepcopy(template[k]) for k in inherited}
        attempt,child_id,nonce = [uuid.uuid4().hex for _ in range(3)]
        folder = D.EVIDENCE/('development-recovery-smoke-'+attempt)
        child = folder/'children'/cell['role']
        child.mkdir(parents=True)
        value.update(attempt_id=attempt, children=[dict(role=cell['role'],child_attempt_id=child_id,
                         termination_nonce=nonce,evidence_path=child.as_posix())],
                     source_snapshot=dict(head=source['head'],dirty=bool(source['owned_status']),status=source['owned_status'].splitlines()),
                     runtime=source['runtime'],seed=90000+cell['phase'],worker_resource=WORKER,
                     discovery_kind=KIND,discovery_batch=batch.as_posix(),discovery_manifest=bound,discovery_cell=cell,
                     ledger_scope=design['ledger_scope'],timeout_seconds_per_child=design['timeout_seconds'],
                     reader_timeout_seconds=design['reader_timeout_seconds'],development_execution_mode='discovery_fresh_role_v1',
                     report_publication=design.get('report_publication','stdout_json_line_v1'),
                     coverage_question=design['question'],uncovered_paths=design['uncovered'],telemetry_profile=design['telemetry'])
        D.write_new(folder/'proposal.json',value)
        rows.append(dict(cell=cell,folder=folder.as_posix()))
    D.write_new(batch/'cells.json',rows)
    print(json.dumps(dict(batch=batch.as_posix(),cells=len(rows))),flush=True)


def validate_cell(path, qualification_only=False):
    D.repository()
    path = Path(path).resolve()
    D.require(path.parent.parent == D.EVIDENCE and path.parent.name.startswith('development-recovery-smoke-'), 'PANEL_PATH')
    value = D.read(path)
    D.require(value.get('discovery_kind') == KIND and all(value.get(k) is False for k in D.FLAGS), 'PANEL_CELL')
    batch = Path(value['discovery_batch']).resolve()
    D.require(batch.parent == D.EVIDENCE and batch.name.startswith('recovery-discovery-'), 'PANEL_BATCH')
    D.verify_binding(value['discovery_manifest'])
    source = D.verify_manifest(batch/'manifest.json')
    D.require(value['discovery_manifest'] == D.binding(batch/'manifest.json'), 'PANEL_MANIFEST')
    D.require(value['discovery_cell'] in cells(source['design']), 'PANEL_UNDECLARED_CELL')
    cell = value['discovery_cell']
    D.require(value['seed'] == 90000+cell['phase'] and value['worker_resource'] == WORKER
              and value['runtime'] == source['runtime'] and value['source_snapshot']['head'] == source['head'], 'PANEL_SOURCE')
    D.require(len(value['children']) == 1 and value['children'][0]['role'] == cell['role'], 'PANEL_ROLE')
    D.require(value['attempt_id'] == path.parent.name.removeprefix('development-recovery-smoke-'), 'PANEL_ATTEMPT')
    D.require(value['children'][0]['evidence_path'] == (path.parent/'children'/cell['role']).as_posix(), 'PANEL_CHILD_PATH')
    D.require(value['candidate_profile'] == dict(resource='res://'+D.PROFILE.relative_to(D.ROOT).as_posix(),raw_sha256=D.binding(D.PROFILE)['raw_sha256']), 'PANEL_PROFILE')
    D.require(value['timeout_seconds_per_child'] == 1800 and value['reader_timeout_seconds'] == 1200, 'PANEL_BOUNDS')
    if not qualification_only:
        D.require(not (batch/'commission-closed.json').exists(),'PANEL_RETIRED')
        gate = D.read(batch/'qualification.json')
        D.require(gate['ok'] is True and gate['manifest'] == value['discovery_manifest'], 'PANEL_GATE')
        D.verify_binding(gate['test_receipt'])
        D.require(D.read(gate['test_receipt']['path'])['ok'] is True, 'PANEL_TESTS')
    D.require(value.get('report_publication','stdout_json_line_v1') == source['design'].get('report_publication','stdout_json_line_v1'), 'PANEL_PUBLICATION_BINDING')
    return value


def qualify(batch):
    batch = Path(batch)
    source = D.verify_manifest(batch/'manifest.json')
    rows = D.read(batch/'cells.json')
    prepared = {}
    for index,row in enumerate(rows):
        folder=Path(row['folder'])
        D.write_new(folder/'declaration.json',D.read(folder/'proposal.json'))
        env=D.clean_environment();env[D.ENV]=(folder/'declaration.json').as_posix()
        role=row['cell']['role']
        if role not in prepared:
            D.process(folder,'prepare',[source['runtime']['images']['godot_engine']['path'],'--headless','--path',D.ROOT,
                       '--script',WORKER,'--','prepare',folder/'prepared-context.json'],env)
            prepared[role]=D.read(folder/'prepared-context.json')
            D.require(prepared[role]['ok'] is True and prepared[role]['world_build_count'] == prepared[role]['solver_step_count'] == 0,'PANEL_PREPARE')
        else:
            D.write_new(folder/'prepared-context.json',prepared[role])
    D.process(batch,'environment-batch',[source['runtime']['images']['powershell_host']['path'],'-NoProfile','-File',D.HERE/'recovery_discovery_environment.ps1','-Batch',batch])
    for row in rows[:2]:
        folder=Path(row['folder']);env=D.clean_environment();env.update(D.read(folder/'environment.json')['environment'])
        D.process(folder,'preworld',[source['runtime']['images']['godot_engine']['path'],'--headless','--path',D.ROOT,
                  '--script',WORKER,'--','preworld',folder/'preworld.json'],env)
        D.require(D.read(folder/'preworld.json')['ok'] is True,'PANEL_PREWORLD')
    # Includes the separately bounded 600-second durable-owner suite. The
    # complete preceding gate took 1,490 seconds on this host; preserve room
    # for all controls without changing any physical or reader deadline.
    D.process(batch,'panel-safety-tests',[sys.executable,'-B','-X','utf8',D.HERE/'test_recovery_panel.py',batch],timeout=2400,test_stderr=True)
    D.verify_manifest(batch/'manifest.json')
    D.write_new(batch/'qualification.json',dict(ok=True,manifest=D.binding(batch/'manifest.json'),
                test_receipt=D.binding(batch/'panel-safety-tests.json'),cells=rows,world_build_count=0,solver_step_count=0,
                physical_acceptance_authority=False,release_authority=False))


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','qualify','audit']);parser.add_argument('path',type=Path)
    args=parser.parse_args()
    if args.action=='prepare':prepare(args.path)
    elif args.action=='qualify':qualify(args.path)
    else:
        from recovery_panel_reader import audit_batch
        audit_batch(args.path)
