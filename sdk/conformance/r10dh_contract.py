"""Prospective R10DH finite population. This module never authorizes execution."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10dh_held_out_finite_decision_design_v2.json'
TASK = ROOT / 'sdk/recovery/r10dh_finite_prone_recovery_contract_v1.json'
EXPOSURE = ROOT / 'sdk/recovery/r10dh_phase_exposure_inventory_v1.json'
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')
MODES = ('development_ghost', 'held_out')
FLAGS = ('official_qualification', 'physical_acceptance_authority', 'release_authority')
WORKER = 'res://sdk/adapters/godot/gdscript/r10dh_campaign_worker_v1.gd'
ENV = 'SPORESPORE_R10DH_DECLARATION'
SCOPE = dict(subsystem='recovery', engine_scope='godot_jolt',
             authority_mode='prospective_finite_recovery', question_class='finite decision')


def require(condition, reason):
    if not condition:
        raise ValueError('R10DH_' + reason)


def parse(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'DUPLICATE_JSON_KEY')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=pairs,
                      parse_constant=lambda value: require(False, 'NONFINITE_JSON'))


def read(path):
    return parse(Path(path).read_text(encoding='utf-8-sig'))


def same(left, right):
    return json.dumps(left, sort_keys=True, allow_nan=False) == json.dumps(right, sort_keys=True, allow_nan=False)


def sha(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def seed_identity(phase, mode):
    require(mode in MODES, 'MODE')
    require(type(phase) is int and phase in ((71,) if mode == MODES[0] else (72, 73, 74)), 'PHASE')
    seed = 93600 + phase
    label = f'R10DH-{mode.upper()}-PREFIX-{phase}-SEED-{seed}-V1'
    return dict(seed=seed, label=label, sha256=sha(label.encode()), prefix_phase=phase)


def population(mode):
    require(mode in MODES, 'MODE')
    phases = (71,) if mode == MODES[0] else (72, 73, 74)
    return [dict(cell_id=f'{93600+phase}:{role}', seed=seed_identity(phase, mode), role=role,
                 maximum_world_attempts=1, maximum_world_builds=1,
                 maximum_solver_steps=2552 if role == ROLES[0] else 3752)
            for phase in phases for role in ROLES]


def validate_population(cells, mode):
    require(same(cells, population(mode)), 'EXACT_POPULATION')


def validate_design(value):
    require(value.get('schema_version') == 'sporespore_r10dh_finite_decision_design_v1', 'DESIGN_SCHEMA')
    require(value.get('campaign_id') == 'R10DH-HELD-OUT-FINITE-DECISION-V1', 'DESIGN_ID')
    revision=value.get('infrastructure_revision', {})
    require(same(revision.get('revision'),2) and revision.get('previous_failure') == 'R10DH_REPORT_IDENTITY'
        and all(revision.get(k) is False for k in ('controller_changed','physical_conditions_changed',
            'task_or_thresholds_changed','held_out_conditions_changed','original_attempt_regraded')), 'INFRASTRUCTURE_REVISION')
    from r10dh_dependency_manifest import D
    require(revision.get('previous_attempt_closure') == D.binding(ROOT/'sdk/recovery/r10dh_production_ghost_closure_v1.json'),
        'INFRASTRUCTURE_ORIGINAL_CLOSURE')
    for mode in MODES:
        validate_population(value[mode]['cells'], mode)
    ghost = value['development_ghost']; held = value['held_out']
    for key in ('fresh_setup_and_both_roles_required', 'all_tasks_positive_required', 'original_workflow_success_required'):
        require(ghost.get(key) is True, 'GHOST_' + key)
    require(type(ghost.get('attempt_limit')) is int and ghost['attempt_limit'] == 1
            and ghost.get('baseline_reuse_permitted') is False, 'GHOST_ATTEMPTS')
    expected = dict(maximum_campaign_attempts=1, maximum_world_attempts=6, maximum_solver_steps=18912,
                    all_cells_must_pass=True, all_cells_run_regardless_of_behavior=True,
                    retry_permitted=False, cell_replacement_permitted=False,
                    baseline_reuse_permitted=False, threshold_override_permitted=False)
    require(all(same(held.get(k), v) for k, v in expected.items()), 'DECISION_RULE')
    require(all(value.get(k) is False for k in ('physical_execution_authorized', 'physical_acceptance_authority', 'release_authority')), 'DESIGN_AUTHORITY')
    return value


def validate_task(value):
    require(value.get('schema_version') == 'sporespore_r10dh_finite_prone_recovery_contract_v1', 'TASK_SCHEMA')
    expected = dict(required_kicked_entry_kind='prone', physics_hz=120, walking_prefix_steps=30,
                    impulse_ns=.25, impulse_direction='positive_task_lateral', physical_timeout_seconds=1800,
                    reader_timeout_seconds=1200, maximum_workers=1)
    require(all(same(value.get(k), v) for k, v in expected.items()), 'TASK_SETTINGS')
    require(value['limits']['child_wall_time_limit_seconds'] == value['physical_timeout_seconds'], 'TASK_TIMEOUT_CONSISTENCY')
    require(value['required_predicates'] == ['entry_ready', 'planned_cycles', 'forward_advance', 'settled_stop',
        'whole_walking_envelope', 'recovery_completed', 'declared_entry_kind'], 'TASK_PREDICATES')
    require(all(value.get(k) is False for k in ('physical_execution_authorized', 'physical_acceptance_authority', 'release_authority')), 'TASK_AUTHORITY')
    return value


def decide(cells, mode, workflow_ok):
    """Missing, repeated or reordered cells never produce a positive decision."""
    expected = population(mode)
    complete = len(cells) == len(expected) and all(same(row.get('cell'), cell)
        for row, cell in zip(cells, expected))
    valid = complete and workflow_ok is True and all(row.get('valid') is True for row in cells)
    positive = valid and all(row.get('measurement', {}).get('finite_task_predicates_passed') is True for row in cells)
    return dict(complete_population=complete, execution_valid=valid, all_finite_tasks_passed=positive,
                sdk1_m07_satisfied=positive and mode == 'held_out',
                physical_acceptance_authority=False, release_authority=False)
