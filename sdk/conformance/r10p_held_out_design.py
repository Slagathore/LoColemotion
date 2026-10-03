"""Audit the prospective R10P selection; no execution authority or native call."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess

import qsdk_r10f_l15_collection_retention as packet
from v52_extended_support_transfer import ROOT, read, verify

DESIGN = ROOT / 'sdk/recovery/r10p_held_out_finite_decision_graph_design_v1.json'
DESIGN_SHA = '82377247ad5678fdce4f5c6c884a7ed1b4f40d2e747e378a7d8c748b047eef42'
CAMPAIGN_ID = 'R10P-HELD-OUT-FINITE-DECISION-V1'
SEEDS = (50644, 50645, 50646)
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')


def require(value, code):
    if not value:
        raise ValueError('R10P_HELD_OUT_DESIGN_' + code)


def population():
    cells = []
    for seed in SEEDS:
        label = f'{CAMPAIGN_ID}/godot/prefix-phase-{seed % 360}/seed-{seed}'
        identity = dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(),
                        prefix_phase=seed % 360)
        for role, steps in zip(ROLES, (2552, 3512)):
            cells.append(dict(cell_id=f'{seed}:{role}', seed=identity, role=role,
                              maximum_world_attempts=1, maximum_world_builds=1, maximum_solver_steps=steps))
    return dict(cells=cells, maximum_campaign_attempt_count=1, maximum_world_attempt_count=6,
        maximum_solver_step_count=18192, all_cells_run_regardless_of_behavior=True,
        all_cells_must_pass=True, baseline_reuse_permitted=False, cell_replacement_permitted=False,
        retry_permitted=False, threshold_override_permitted=False)


def validate_population(value):
    require(packet.same(value, population()), 'EXACT_POPULATION')


def audit():
    require(ROOT == Path('C:/Users/Cole/CodeStuff/games/SporeSpore')
        and Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT).decode().strip()) == ROOT
        and subprocess.check_output(['git', 'remote', 'get-url', 'origin'], cwd=ROOT).decode().strip()
            == 'https://github.com/Slagathore/sporespore.git', 'REPOSITORY')
    raw = DESIGN.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == DESIGN_SHA, 'DESIGN_DRIFT')
    value = packet.parse_json(raw.decode('utf-8'))
    require(value['campaign_id'] == CAMPAIGN_ID and value['status'] == 'declared_not_implemented_no_execution_authority', 'IDENTITY')
    validate_population(value['population'])
    for item in value['bound_sources']:
        verify(item)
    component_path = ROOT / 'sdk/recovery/r10p_consecutive_prone_reader_component_v1.json'
    committed = subprocess.check_output(['git', 'show', value['source_parent_commit'] + ':' +
        component_path.relative_to(ROOT).as_posix()], cwd=ROOT)
    require(committed == component_path.read_bytes(), 'COMMITTED_PREREQUISITE')
    component = read(component_path)
    require(component['status'] == 'verified_post_exposure_reader_component'
        and component['counter_tests']['test_count'] == 8
        and [cell['original_measurement']['finite_task_predicates_passed'] for cell in component['cells']] == [True, True, False]
        and all(cell['r10p_measurement']['finite_task_predicates_passed'] is True for cell in component['cells'])
        and component['claim_boundary']['original_attempt_reclassified'] is False, 'READER_PREREQUISITE')
    runtime = read(ROOT / 'sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.runtime.json')
    verify(runtime['runtime'])
    require(runtime['runtime']['raw_sha256'] == value['preserved_task']['native_dll_sha256'], 'RUNTIME')
    rows = value['selection']['historical_declaration_inventory']
    require(len(rows) == 64 and len({row['declaration']['path'] for row in rows}) == 64, 'EXPOSURE_INVENTORY')
    phases = set()
    for row in rows:
        path = verify(row['declaration'])
        require(path.parent.parent == ROOT.parent / 'SporeSpore_Evidence'
                and path.name == 'declaration.json', 'EXPOSURE_PATH')
        declaration = read(path)
        require(declaration['seed'] == row['seed'], 'EXPOSURE_SEED')
        if row['context'] == 'legacy_development_seed_modulo_360':
            require(row['seed'] == 40200 and row['prefix_phase'] == 240, 'LEGACY_PHASE')
        else:
            require(declaration[row['context']]['seed']['prefix_phase'] == row['prefix_phase'], 'EXPLICIT_PHASE')
        phases.add(row['prefix_phase'])
    require(phases == {240, 241, 242, 243} and not phases.intersection(seed % 360 for seed in SEEDS), 'EXPOSED_PHASE_REUSE')
    require(packet.same(value['claim_boundary'], dict(held_out_population_selected=True, held_out_worlds_opened=0,
        authority_created=False, new_world_count=0, new_solver_step_count=0, original_attempt_reclassified=False,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        sdk1_score='14/20')), 'CLAIMS')
    controls = []
    for name in ('reused_phase', 'missing_cell', 'duplicate_role', 'larger_step_budget', 'second_attempt', 'reused_baseline'):
        changed = copy.deepcopy(value['population'])
        if name == 'reused_phase': changed['cells'][0]['seed']['prefix_phase'] = 243
        elif name == 'missing_cell': changed['cells'].pop()
        elif name == 'duplicate_role': changed['cells'][1]['role'] = ROLES[0]
        elif name == 'larger_step_budget': changed['cells'][0]['maximum_solver_steps'] += 1
        elif name == 'second_attempt': changed['maximum_campaign_attempt_count'] = 2
        else: changed['baseline_reuse_permitted'] = True
        try:
            validate_population(changed)
        except ValueError:
            controls.append(name)
        else:
            require(False, 'CONTROL_ACCEPTED:' + name)
    return dict(ok=True, campaign_id=CAMPAIGN_ID, seeds=list(SEEDS), prefix_phases=[seed % 360 for seed in SEEDS],
        planned_cells=6, bound_historical_declarations=64, refusal_controls=controls,
        physical_execution_authorized=False, new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    print(json.dumps(audit(), separators=(',', ':'), allow_nan=False))
