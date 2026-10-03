"""Exact, prospective identity of the sole R10DG development diagnostic."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10dg-finite-reference-v1.json'
DESIGN = ROOT / 'sdk/recovery/r10dg_finite_reference_development_design_v1.json'
HOST = ROOT / 'sdk/development/r10dg_host_runtime_contract_v1.json'
ROLE = 'kick_passive_recovery_resume'
SEED = 71248
LABEL = 'R10DG-FINITE-REFERENCE-PREFIX-248-V1'
CONTEXT = 'r10dg_development'
WORKER = 'res://sdk/adapters/godot/gdscript/r10dg_development_worker_v1.gd'
TOKEN = EVIDENCE / 'r10dg_finite_reference_71248_consumption_v1.json'
CLAIM = 'r10dg_native_world_claim_v1.json'
LAUNCH = 'r10dg_launch.json'


def require(value, code):
    if not value:
        raise ValueError('R10DG_' + code)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def binding(path):
    path = Path(path).resolve()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=sha(path))


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, indent=2) + '\n')
        stream.flush()
        os.fsync(stream.fileno())


def reference():
    return dict(resource='res://' + PROFILE.relative_to(ROOT).as_posix(), raw_sha256=sha(PROFILE))


def seed_identity():
    return dict(seed=SEED, label=LABEL, sha256='sha256:' + hashlib.sha256(LABEL.encode()).hexdigest(), prefix_phase=248)


def context(head):
    return dict(schema_version='sporespore_r10dg_development_child_context_v1', source_commit=head,
                candidate_profile=reference(), design_binding=dict(resource='res://' + DESIGN.relative_to(ROOT).as_posix(), raw_sha256=sha(DESIGN)),
                seed=seed_identity(), required_entry_kind='partial', stage='finite_reference_recovery_diagnostic',
                classification_frame_profile_id='godot_jolt_distal_contact_detection_frame_v1',
                contact_source_schema='sporespore_r10af_godot_detection_frame_contact_source_v1',
                physical_acceptance_authority=False, release_authority=False)


def validate(value, physical=False):
    require(isinstance(value, dict), 'DECLARATION_TYPE')
    for flag in ['comparative_authority', 'baseline_reused', 'official_qualification', 'physical_acceptance_authority', 'release_authority']:
        require(value.get(flag) is False, 'CLAIM:' + flag)
    head = value.get('source_snapshot', {}).get('head')
    require(isinstance(head, str) and re.fullmatch('[0-9a-f]{40}', head), 'SOURCE_HEAD')
    require(value['source_snapshot'] == dict(head=head, dirty=False, status=[], changed_file_bindings=[]), 'SOURCE_SNAPSHOT')
    require(type(value.get('seed')) is int and value['seed'] == SEED, 'SEED')
    require(value.get('candidate_profile') == reference() and value.get(CONTEXT) == context(head), 'IDENTITY')
    require(value.get('development_execution_mode') == 'single_kick_controller_diagnostic_v1', 'SINGLE_ROLE_MODE')
    require(value.get('worker_resource') == WORKER, 'WORKER')
    require(value.get('runtime') == read(HOST), 'HOST')
    for key in ['maximum_precondition_steps', 'walking_prefix_steps', 'interaction_steps', 'maximum_passive_descent_steps', 'after_interaction_steps', 'maximum_steps_per_child']:
        require(type(value.get(key)) is int and value[key] == read(DESIGN)['limits'][key], 'LIMIT:' + key)
    require(value.get('diagnostic_schedule_id') == 'r10dg_finite_reference_tracking_v1', 'SCHEDULE')
    require(value.get('timeout_seconds_per_child') == 2400 and value.get('independent_replay_timeout_seconds') == 1200, 'WALL_LIMIT')
    children = value.get('children')
    require(isinstance(children, list) and len(children) == 1 and isinstance(children[0], dict) and children[0].get('role') == ROLE, 'CHILD_POPULATION')
    ids = [value.get('attempt_id'), children[0].get('child_attempt_id'), children[0].get('termination_nonce')]
    require(all(isinstance(x, str) and re.fullmatch('[0-9a-f]{32}', x) for x in ids) and len(set(ids)) == 3, 'UUIDS')
    require(children[0].get('evidence_path') == (EVIDENCE / ('development-recovery-smoke-' + ids[0]) / 'children' / ROLE).as_posix(), 'CHILD_PATH')
    require(not any(re.fullmatch(r'r10[a-z]+_(development|campaign|host)', k) and k != CONTEXT for k in value), 'COMPETING_IDENTITY')
    if physical:
        require('report_fixture_only' not in value and not any(x.startswith('ffffffff') for x in ids), 'SYNTHETIC_IDENTITY')
    return value


def verify_images():
    host = read(HOST)
    profile = read(PROFILE)
    for item in host['images'].values():
        require(binding(item['path']) == item, 'IMAGE:' + item['path'])
    for field in ['diagnostic_design', 'observer_component', 'classification_component']:
        item = host[field]
        path = ROOT / item['path']
        require(sha(path) == item['raw_sha256'] and path.stat().st_size == item['byte_length'], 'HOST_SOURCE:' + field)
    for field in ['runtime_binding', 'extension']:
        require(sha(ROOT / profile[field][6:]) == profile[field + '_sha256'], 'PROFILE_SOURCE:' + field)
    runtime = read(ROOT / profile['runtime_binding'][6:])
    require(binding(runtime['runtime']['path']) == runtime['runtime'], 'CANDIDATE_IMAGE')
    require(sha(ROOT / runtime['local_build_path']) == profile['runtime_sha256'], 'CANDIDATE_LOCAL_IMAGE')
    for item in runtime['source_files']:
        require(sha(ROOT / item['path']) == item['raw_sha256'], 'CANDIDATE_BUILD_SOURCE:' + item['path'])
    return host


def freeze(head):
    # This predecessor routine is identity-independent: it checks this canonical
    # root, origin, clean main, tracking ref, and the live GitHub ref using captured IO.
    from r10ap_startup_preflight import current_freeze
    return current_freeze(head)
