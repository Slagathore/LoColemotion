"""Validate R10X's prospective finite population; no execution authority."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
import qsdk_r10f_l15_collection_retention as packet

DESIGN = ROOT/'sdk/recovery/r10x_held_out_finite_decision_graph_design_v1.json'
DESIGN_SHA = 'sha256:e8f3b7b274a570c060acd6d376db55ad8cc586bd420dd36e06772ca7766e3c49'
CAMPAIGN = 'R10X-HELD-OUT-FINITE-DECISION-V1'
SEEDS = (51007,51008,51009)
ROLES = ('matched_no_kick_continuation','kick_passive_recovery_resume')


def require(value, code):
    if not value: raise ValueError('R10X_DESIGN_'+code)


def population():
    cells = []
    for seed in SEEDS:
        label = f'{CAMPAIGN}/godot/prefix-phase-{seed%360}/seed-{seed}'
        identity = dict(seed=seed,label=label,sha256='sha256:'+hashlib.sha256(label.encode()).hexdigest(),prefix_phase=seed%360)
        for role,steps in zip(ROLES,(2552,3752)):
            cells.append(dict(cell_id=f'{seed}:{role}',seed=identity,role=role,
                maximum_world_attempts=1,maximum_world_builds=1,maximum_solver_steps=steps))
    return dict(cells=cells,maximum_campaign_attempt_count=1,maximum_world_attempt_count=6,
        maximum_solver_step_count=18912,all_cells_run_regardless_of_behavior=True,all_cells_must_pass=True,
        baseline_reuse_permitted=False,cell_replacement_permitted=False,retry_permitted=False,threshold_override_permitted=False)


def validate_population(value):
    require(packet.same(value,population()),'EXACT_POPULATION')


def validate_native_observer(value):
    expected = dict(launcher_parameter='R10xNativeProcessObservation', default_enabled=False,
        campaign_requires_explicit_selection=True, requires_l15_context=True,
        cim_fallback_permitted=False, maximum_ancestry_nodes=16,
        receipt_schema_changed=False, required_component_tests=13, production_adoption_pending=True)
    require(all(packet.same(value.get(k), v) for k,v in expected.items()), 'NATIVE_OBSERVER_CONTRACT')


def audit(verify_selection_inventory=False):
    require(Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=ROOT,text=True).strip()).resolve()==ROOT.resolve()
        and subprocess.check_output(['git','remote','get-url','origin'],cwd=ROOT,text=True).strip()
        == 'https://github.com/Slagathore/sporespore.git','REPOSITORY')
    require(bind(DESIGN)['raw_sha256']==DESIGN_SHA,'DESIGN_BYTES')
    value=read(DESIGN)
    require(value['campaign_id']==CAMPAIGN and value['status']=='declared_not_implemented_no_execution_authority','IDENTITY')
    validate_population(value['population'])
    for binding in value['bound_sources']: verify(binding)
    native=value['native_process_observation'];validate_native_observer(native)
    verify(native['component']);verify(native['module'])
    component=read(native['component']['path'])
    require(component['current_component_tests_passed']==13 and component['attempts'][-1]['passed'] is True
        and component['attempts'][-1]['source_unchanged'] is True and component['official_qualification'] is False
        and component['world_build_count']==0 and component['solver_step_count']==0, 'NATIVE_COMPONENT')
    for item in component['validated_source_bindings']:
        verify(dict(path=(ROOT/item['path']).as_posix(),byte_length=item['byte_length'],raw_sha256='sha256:'+item['raw_sha256']))
    prior=value['preserved_r10w']
    for key in ('positive_development_closure','qualification_wrapper','qualification_host_terminal','qualification_host_publication'):
        verify(prior[key])
    positive=read(prior['positive_development_closure']['path'])
    failure=read(prior['qualification_host_terminal']['path'])
    wrapper=read(prior['qualification_wrapper']['path'])
    require(positive['all_tasks_positive'] is True and positive['production_route_ghost_passed'] is True
        and positive['owned_cleanup_complete'] is True and positive['held_out_worlds_opened']==0, 'PRESERVED_POSITIVE')
    require(failure['ok'] is False and failure['owned_cleanup_complete'] is True and failure['source_unchanged'] is True
        and wrapper['passed'] is False and wrapper['retry_authorized'] is False, 'PRESERVED_QUALIFICATION_REFUSAL')
    require(prior['original_results_reclassified'] is False and prior['old_development_population_retried'] is False
        and prior['old_held_out_worlds_opened']==0, 'PREDECESSOR_SCOPE')

    closure_path=ROOT/'sdk/recovery/r10v_development_population_closure_v1.json'
    committed=subprocess.check_output(['git','show',value['source_parent_commit']+':'+closure_path.relative_to(ROOT).as_posix()],cwd=ROOT)
    require(committed==closure_path.read_bytes(),'COMMITTED_DEVELOPMENT_CLOSURE')
    closure=read(closure_path);observed=closure['observed']
    require(observed['classification']=='valid_positive_complete_development_population'
        and observed['cell_count']==5 and observed['total_physical_worlds']==5
        and observed['total_physical_solver_steps']==10438 and observed['all_tasks_positive'] is True
        and observed['held_out_design_precondition_satisfied'] is True,'DEVELOPMENT_PRECONDITION')
    require(observed['branch_coverage']==dict(no_kick=True,upright_bounded_hold=True,upright_direct=True,partial_direct=True,prone_direct=True)
        and observed['original_results_reclassified'] is False and observed['physical_acceptance_authority'] is False,'DEVELOPMENT_SCOPE')
    task=read(value['preserved_task']['task_contract']['path'])
    for field in ('controller_composition','native_interaction','limits','finite_walking_observable','settled_tail','whole_walking_envelope'):
        require(packet.same(value['preserved_task'][field],task[field]),'UNCHANGED_TASK_'+field)
    runtime=read(ROOT/'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
    verify(runtime['runtime'])
    require(runtime['runtime']['raw_sha256']==value['preserved_task']['native_dll_sha256'],'NATIVE_RUNTIME')
    rows=value['selection']['historical_declaration_inventory'];paths=set();phases=set()
    require(len(rows)==83,'EXPOSURE_COUNT')
    for row in rows:
        verify(row['declaration']);path=Path(row['declaration']['path'])
        require(path.parent.parent==EVIDENCE and path.name=='declaration.json' and path not in paths,'EXPOSURE_PATH')
        paths.add(path);declaration=read(path)
        require(declaration['seed']==row['seed'],'EXPOSURE_SEED')
        if row['context']=='legacy_development_seed_modulo_360':
            require(row['seed']==40200 and row['prefix_phase']==240,'LEGACY_PHASE')
        else:
            require(declaration[row['context']]['seed']['prefix_phase']==row['prefix_phase'],'EXPLICIT_PHASE')
        phases.add(row['prefix_phase'])
    require(phases==set(range(240,247)) and not phases.intersection(seed%360 for seed in SEEDS),'EXPOSED_PHASE_REUSE')
    if verify_selection_inventory:
        require(paths==set(EVIDENCE.glob('development-recovery-smoke-*/declaration.json')),'SELECTION_INVENTORY_INCOMPLETE')
    ghost=value['coverage_adequacy']['fresh_development_ghost']
    require(ghost['seed']==42445 and ghost['seed'] not in {r['seed'] for r in rows}
        and ghost['prefix_phase']==245 and ghost['roles']==list(ROLES) and ghost['attempt_limit']==1
        and ghost['maximum_world_attempts']==2 and ghost['maximum_solver_steps']==6304
        and ghost['complete_finite_horizon'] is True and ghost['baseline_reuse'] is False
        and ghost['required_kicked_entry_kind']=='upright' and ghost['required_kicked_handoff']=='bounded_hold','FRESH_GHOST')
    require(value['claim_boundary']==dict(held_out_population_selected=True,held_out_worlds_opened=0,authority_created=False,
        new_world_count=0,new_solver_step_count=0,original_attempt_reclassified=False,physical_execution_authorized=False,
        physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25'),'CLAIMS')
    controls=[]
    for name in ('exposed_phase','missing_cell','duplicate_role','larger_step_budget','second_attempt','reused_baseline','replacement','omitted_negative_tail'):
        changed=copy.deepcopy(value['population'])
        if name=='exposed_phase':changed['cells'][0]['seed']['prefix_phase']=246
        elif name=='missing_cell':changed['cells'].pop()
        elif name=='duplicate_role':changed['cells'][1]['role']=ROLES[0]
        elif name=='larger_step_budget':changed['cells'][1]['maximum_solver_steps']+=1
        elif name=='second_attempt':changed['maximum_campaign_attempt_count']=2
        elif name=='reused_baseline':changed['baseline_reuse_permitted']=True
        elif name=='replacement':changed['cell_replacement_permitted']=True
        else:changed['all_cells_run_regardless_of_behavior']=False
        try:validate_population(changed)
        except ValueError:controls.append(name)
        else:require(False,'CONTROL_ACCEPTED_'+name)
    for field,replacement in (('campaign_requires_explicit_selection',False),('requires_l15_context',False),('cim_fallback_permitted',True)):
        changed=copy.deepcopy(native);changed[field]=replacement
        try:validate_native_observer(changed)
        except ValueError:controls.append('native_'+field)
        else:require(False,'CONTROL_ACCEPTED_NATIVE_'+field)
    return dict(ok=True,design=bind(DESIGN),campaign_id=CAMPAIGN,seeds=list(SEEDS),prefix_phases=[s%360 for s in SEEDS],
        planned_held_out_cells=6,maximum_held_out_solver_steps=18912,historical_declarations=83,
        selection_inventory_verified=verify_selection_inventory,development_ghost_seed=42445,refusal_controls=controls,
        physical_execution_authorized=False,new_world_count=0,new_solver_step_count=0,sdk1_score='14/20',full_program_score='14/25')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--verify-selection-inventory',action='store_true');args=parser.parse_args()
    print(json.dumps(audit(args.verify_selection_inventory),allow_nan=False))
