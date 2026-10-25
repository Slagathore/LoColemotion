"""Verify contact-first hierarchy and the real public controller handoff."""
import argparse,copy,json
from pathlib import Path
from contextlib import ExitStack
from unittest.mock import patch
from collections import Counter
import mujoco
import numpy as np
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as old
import dynamic_response_diagnostic as parent
import generic_proximal_contact_component as component
import contact_priority_component as oldcomponent
import audit_proximal_repeatability as prior
from generic_proximal_contact_component import solver_settings as settings
from dynamic_response_diagnostic_metrics import configured_model
from floating_dynamics_oracle_math import canonical_state
from audit_gpu_batch_execution import read_jsonl
from causal_force_policy import plain
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_dynamic_control_native_failure import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

CONTRACT=HERE/"hierarchical_contact_component_v5.json"
DEPENDENCIES=HERE/"proxqp_dependencies_v1.json"
LOCK=ROOT/"sdk/adapters/mujoco/requirements-proxqp-lock.txt"
PARENT_RESULT=HERE/"proximal_repeatability_result_v1.json"
PARENT_SHA="ac2da533147d5878954d0612cce47e21109de2372959f54fdb83711f8f2e9668"
SOURCES=("generic_proxqp_backend.py","generic_proximal_qp_solver.py","test_generic_proximal_qp_solver.py",
    "generic_proximal_contact_component.py","test_generic_proximal_contact_component.py",
    "hierarchical_force_policy_v5.py","hierarchical_hold_control_v5.py","test_hierarchical_force_policy_v5.py",
    "hierarchical_contact_component_audit_v5.py","run_hierarchical_contact_component_v5.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),("dynamics","test_floating_base_dynamics",22),
    ("native-inputs","test_floating_base_dynamics_inputs",9),("qp","test_dynamic_qp_solver_v2",12),
    ("inverse","test_dynamic_inverse_dynamics_v2",14),("priority","test_contact_priority_component",20),("switching","test_switching_contact_component",20),("hierarchy","test_hierarchical_contact_component",20),
    ("hierarchical-policy","test_hierarchical_force_policy",17),
    ("nullspace","test_hierarchical_nullspace_component",12),("conditioning","test_conditioned_contact_component",12),("proximal-qp","test_proximal_qp_solver",14),("proximal-hierarchy","test_proximal_contact_component",20),("hierarchical-policy-v4","test_hierarchical_force_policy_v4",17),
    ("generic-qp","test_generic_proximal_qp_solver",16),("generic-hierarchy","test_generic_proximal_contact_component",20),
    ("hierarchical-policy-v5","test_hierarchical_force_policy_v5",17))
CONTROLS=sum(n for _,_,n in GATES)
DENIALS=("alternative_actions_generated_observations","recovery_benefit_established","capability_estimated",
    "dynamic_feasibility_established","tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority","physical_launch_authority",
    "recursive_feasibility_established","held_contact_guaranteed","complete_saturation_regime_search")
TRIALS=("reach_hold_left_075_train_001","dynamic_hold_left_075_train_001")
ORIGINAL="sdk2-dynamic-control-native-9beec4b5fe564f4bb985cce8fb8c5e1b"
INPUTS=("controller.jsonl","force-profile.json","model.xml","compiled.json","inputs.json")
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"

def expected_contract():
    return dict(schema_version="locolemotion_hierarchical_contact_component_contract_v5",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="conditional_retained_feasibility",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        inherited_bindings={n:sha(HERE/n) for n in ("dynamic_inverse_dynamics_v2.py","dynamic_qp_solver_v2.py",
            "floating_base_dynamics.py","actuation_recovery_mechanics.py","dynamic_response_diagnostic_metrics.py","contact_priority_component.py","contact_priority_component_audit.py","switching_contact_component.py","switching_contact_component_audit.py","recovery_hold_control.py","hierarchical_contact_component.py","hierarchical_least_squares_qp.py",
            "hierarchical_contact_component_audit.py","hierarchical_force_policy.py","hierarchical_hold_control.py","hierarchical_nullspace_component.py","audit_hierarchical_nullspace_refusal.py","audit_conditioned_contact_refusal.py")},
        input_bindings={t:{n:sha(EVIDENCE/ORIGINAL/"physical"/t/n) for n in INPUTS} for t in TRIALS},
        original_attempt=ORIGINAL,trials=list(TRIALS),start_command=60,end_command_exclusive=119,
        states=118,state_mode_evaluations=118,parameters=component.parameters(),
        hierarchy_levels=["support_error_least_squares","body_and_posture_at_fixed_attained_support"],
        original_contact_target_is_hard=False,hard_motor_joint_force_bounds=True,
        first_level_has_no_regularization=True,secondary_support_equalities_eliminated=False,
        secondary_hessian_conditioned_by_invertible_coordinates=False,secondary_objective_regularization=0.,
        secondary_backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",closest_feasible_relaxation=False,
        dependency_manifest_sha256=sha(DEPENDENCIES),dependency_lock_sha256=sha(LOCK),
        provision_attempt="sdk2-proxqp-runtime-231b1e9834634bcd946c132f0ef52b30",
        provision_receipt_sha256=sha(EVIDENCE/"sdk2-proxqp-runtime-231b1e9834634bcd946c132f0ef52b30/receipt.json"),
        generic_extension="proxsuite_pywrap.cp311-win_amd64.pyd",automatic_simd_selection=False,
        conflicting_loaded_backend_refused=True,intermediate_outputs_retained_before_comparison=True,
        output_rounding=False,replay_criteria_unchanged=True,
        original_full_duals_and_certificates_required=True,public_handoff_ghosts=4,ghost_commands_per_host=62,
        ghost_unchanged_prefix_commands=60,ghost_hierarchical_commands_per_host=2,ghost_core_builds=2,
        solver_settings=settings(),controls_required=CONTROLS,complete_reader_invocations=2,
        full_original_coordinate_certificate_required=True,maximum_patterns_per_state_mode=8,maximum_qp_solves_per_state_mode=16,
        reduced_objective_preserves_full_objective_up_to_constant=True,
        derivative_reference="https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_derivative.c",
        contact_target_source="existing fixed damped support task; no retuning",
        task_reference_source="original command reference; each state conditions on its original applied correction",
        joint_speed_cap_is_new_planning_constraint_not_motor_speed_guarantee=True,
        joint_margin_basis="one native step at planning speed cap",
        infeasibility_handling="return no command; solver status is not a complete impossibility proof",
        model_scope="frozen M, bias, contact J and forces over five implicit motor steps; no native prediction",
        outside_native_joint_range="refuse because the model has no joint-limit reaction",
        regime_scope="up to eight five-step patterns; strict certificates only; proposals cannot issue commands",
        observation_source="shared complete pre-failure retained states selected after the original outcomes",
        initial_optimal_attained_contact_vector_is_frozen_for_secondary_tasks=True,
        hierarchy_reference="https://gepettoweb.laas.fr/uploads/Publications/2014_escande_ijrr.pdf",
        endpoint_joint_constraints_apply_to_all_five_predicted_steps=True,
        sources=dict(contact_priority="https://arxiv.org/html/1909.06586v1",
            task_constraints="https://www.frontiersin.org/journals/robotics-and-ai/articles/10.3389/frobt.2018.00024/full",
            joint_viability_limits="https://iris.unitn.it/retrieve/handle/11572/402854/744191/2023_IROS___Robust_joint_bounds.pdf"),
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Priority exact declaration");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Generic previous diagnostic result identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"];receipt=read(folder/"receipt.json");decl=read(folder/"declaration.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==36
        and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and result["original_component_acceptance_granted"] is False,"Generic complete prior diagnostic only")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Generic prior artifact digest")
    a=read(folder/"audit.json");b=read(folder/"reconstruction.json")
    require(a["ok"] is True and b["ok"] is True and a["declared_inputs"]==b["declared_inputs"],
        "Generic prior diagnostic declared population agreement")
    require(a["original_component_acceptance_granted"] is False and b["original_component_acceptance_granted"] is False,
        "Generic prior diagnostic grants no acceptance")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(decl["binding"])
    require(result["contract_sha256"]==sha(prior.CONTRACT) and receipt["contract"]==prior.declaration(),
        "Generic immutable predecessor declaration")
    for name,_,count in prior.GATES:verify_tests(folder/(name+"-controls"),count)
    prior.verify_failed(evidence)
    prior.failed.verify_parent(evidence,core,baseline)
    return result


def audit(evidence,core,baseline,capture):
    c=declaration();verify_parent(evidence,core,baseline)
    provision=evidence/c["provision_attempt"];receipt=read(provision/"receipt.json")
    require(receipt["ok"] and receipt["pip_check_passed"] and receipt["manifest_sha256"]==sha(DEPENDENCIES),
        "ProxQP complete pinned provisioning")
    require(receipt["old_source_bindings_unchanged"]==832 and receipt["old_runtime_bindings_unchanged"]==3430,
        "ProxQP predecessor runtime unchanged")
    for name,digest in receipt["artifacts"].items():require(sha(provision/name)==digest,"ProxQP retained runtime artifact")
    rows=[];trials=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Priority component opens no worlds")))
        for trial in TRIALS:
            folder=evidence/ORIGINAL/"physical"/trial
            profile=read(folder/"force-profile.json")
            model,ranges=configured_model((folder/"model.xml").read_text(),profile)
            declared=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.spec["joints"]])
            require(np.array_equal(ranges,declared),"Priority native and morphology joint ranges")
            originals=list(read_jsonl(folder/"controller.jsonl"));summaries=Counter()
            handoff={};max_error=0.;max_bound=0.;solves=0;accepted=0
            for step in range(60,119):
                row=originals[step];require(row["outer_step"]==step,"Priority retained command clock")
                position,orientation,joints,velocity,gravity=canonical_state(row)
                frame=model.tree.kinematics(position,orientation,joints)
                request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
                contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
                items,active=old.tasks(model,frame,velocity,orientation,contacts,decision["target_com"],
                    np.array(decision["support_reference"]["reference_joint_positions_rad"])-joints,old.parameters())
                baseline_commands=request["deterministic_baseline"]["ordered_commands"]
                limits=request["safety_envelope"]["ordered_actuator_limits"]
                require([x["actuator_id"] for x in baseline_commands]==[x["actuator_id"] for x in limits]==profile["ordered_actuators"]
                    and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
                    "Priority unchanged public limits")
                envelope=m.command_envelope([x["combined_canonical_target_velocity_rad_s"] for x in baseline_commands],
                    [x["maximum_target_speed_rad_s"] for x in baseline_commands],
                    [x["previous_applied_correction_rad_s"] for x in limits],[3.5]*8,[.08]*8)
                base=oldcomponent.build(model,frame,velocity,gravity,joints,ranges,items,active,envelope,
                    profile["velocity_gains"],profile["force_ranges"],"combined")
                result=component.compute(base);summaries[result["status"]]+=1;solves+=len(result["attempts"])
                if result["accepted"]:
                    accepted+=1;max_error=max(max_error,result["prediction"]["maximum_errors"]["acceleration"])
                    max_bound=max(max_bound,result["selected"]["full_certificate"]["maximum_bound_violation"],
                        result["primary"]["full_certificate"]["maximum_bound_violation"])
                if step==60:handoff=dict(accepted=result["accepted"],status=result["status"],
                    patterns_tried=result["patterns_tried"],
                    transitions=result["prediction"]["transitions"] if result["accepted"] else None)
                rows.append(dict(trial_id=trial,command=step,supporting_sites=[r["contact_site_id"] for r in active],result=plain(result)))
            trials.append(dict(trial_id=trial,states=59,status_counts=dict(summaries),
                handoff=handoff,qp_solves=solves,accepted_model_solutions=accepted,
                maximum_recurrence_error=max_error,maximum_bound_violation=max_bound))
    require(len(rows)==118,"Priority complete state population")
    write_new(capture/"state-computation.json",dict(states=118,trials=trials,rows=rows,
        component_accepted=False,worlds_opened=0))
    return dict(schema_version="locolemotion_hierarchical_contact_component_audit_v5",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_complete_native_reconstruction_verified=True,states=118,state_mode_evaluations=118,trials=trials,rows=rows,
        public_ghosts=verify_public_handoffs(evidence,core,baseline,capture),
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def verify_public_handoffs(evidence,core_path,baseline_path,capture):
    from hierarchical_force_policy_v5 import make_profile
    from hierarchical_hold_control_v5 import HierarchicalHoldController
    from hold_horizon_task import bridge,controller_contract,frozen_model,declaration as hold_declaration
    from recovery_hold_control import terminal_error
    from audit_gpu_batch_execution import same_bits
    ghosts=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Hierarchy public ghost opens no worlds")))
        for trial in TRIALS:
            folder=evidence/ORIGINAL/"physical"/trial;compiled=read(folder/"compiled.json");inputs=read(folder/"inputs.json")
            originals=list(read_jsonl(folder/"controller.jsonl"))[:62];profile=make_profile(compiled,inputs)
            outputs=[]
            for core_index,core_file in enumerate((core_path,baseline_path)):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core)
                host=HierarchicalHoldController(core,compiled,controller_contract(hold_declaration(),model),model,trial,profile)
                rows=[]
                try:
                    for index,old in enumerate(originals):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        rows.append(row)
                        require(terminal_error(row) is None,"Hierarchy public ghost terminal refusal")
                        require(row["request"]["state"]==old["request"]["state"],"Hierarchy original ghost observations")
                        if index<60:require(all(same_bits(v,old[k]) for k,v in row.items()),"Hierarchy complete unchanged prefix")
                        else:
                            decision=row["force_reference"]["decision"];allocation=decision["allocation"]
                            require(row["resolution"]["provider_status"]=="applied" and allocation["accepted"] is True
                                and allocation["primary"]["full_certificate"]["accepted"] is True
                                and allocation["selected"]["full_certificate"]["accepted"] is True,"Hierarchy public acceptance")
                            targets=[x["final_canonical_target_velocity_rad_s"] for x in row["resolution"]["ordered_commands"]]
                            require(targets==decision["projection"]["target"],"Hierarchy original selected held target")
                            require(all(abs(x["applied_correction_rad_s"])<=3.5+1e-12 for x in row["resolution"]["ordered_commands"]),
                                "Hierarchy public correction bound")
                finally:
                    host.close()
                    write_new(capture/(trial+"-core"+str(core_index)+".json"),
                        dict(trial_id=trial,core_sha256=sha(core_file),profile=profile,rows=rows))
                require(len(rows)==62 and host.closed,"Hierarchy public ghost complete lifecycle")
                outputs.append(rows)
            require(same_bits(outputs[0],outputs[1]),"Hierarchy identical two-core public commands")
            ghosts.append(dict(trial_id=trial,core_sha256s=[sha(core_path),sha(baseline_path)],
                profile=profile,unchanged_prefix_commands=60,hierarchical_commands=2,
                commands_per_core=62,cores_identical=True,rows=outputs[0],
                synthetic=True,alternative_actions_generated_observations=False,worlds_opened=0))
    return ghosts


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    value=audit(EVIDENCE,args.core,args.baseline_core,capture)
    write_new(args.output,value);print(json.dumps(dict(ok=True,states=118,evaluations=118,worlds_opened=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
