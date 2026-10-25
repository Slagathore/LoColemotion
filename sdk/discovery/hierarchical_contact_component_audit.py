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
import hierarchical_contact_component as component
import contact_priority_component as oldcomponent
import switching_contact_component_audit as prior
from dynamic_qp_solver_v2 import settings
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

CONTRACT=HERE/"hierarchical_contact_component_v1.json"
PARENT_RESULT=HERE/"switching_contact_component_result_v1.json"
PARENT_SHA="25dfcb3aa345c0c61287e8271c36171b978914cb5a3c8e818e9ad51613a7764e"
SOURCES=("hierarchical_least_squares_qp.py","hierarchical_contact_component.py","test_hierarchical_contact_component.py",
    "hierarchical_force_policy.py","hierarchical_hold_control.py","test_hierarchical_force_policy.py",
    "hierarchical_contact_component_audit.py","run_hierarchical_contact_component.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),("dynamics","test_floating_base_dynamics",22),
    ("native-inputs","test_floating_base_dynamics_inputs",9),("qp","test_dynamic_qp_solver_v2",12),
    ("inverse","test_dynamic_inverse_dynamics_v2",14),("priority","test_contact_priority_component",20),("switching","test_switching_contact_component",20),("hierarchy","test_hierarchical_contact_component",20),
    ("hierarchical-policy","test_hierarchical_force_policy",17))
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
    return dict(schema_version="locolemotion_hierarchical_contact_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="conditional_retained_feasibility",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        inherited_bindings={n:sha(HERE/n) for n in ("dynamic_inverse_dynamics_v2.py","dynamic_qp_solver_v2.py",
            "floating_base_dynamics.py","actuation_recovery_mechanics.py","dynamic_response_diagnostic_metrics.py","contact_priority_component.py","contact_priority_component_audit.py","switching_contact_component.py","switching_contact_component_audit.py","recovery_hold_control.py")},
        input_bindings={t:{n:sha(EVIDENCE/ORIGINAL/"physical"/t/n) for n in INPUTS} for t in TRIALS},
        original_attempt=ORIGINAL,trials=list(TRIALS),start_command=60,end_command_exclusive=119,
        states=118,state_mode_evaluations=118,parameters=component.parameters(),
        hierarchy_levels=["support_error_least_squares","body_and_posture_at_fixed_attained_support"],
        original_contact_target_is_hard=False,hard_motor_joint_force_bounds=True,
        first_level_has_no_regularization=True,public_handoff_ghosts=4,ghost_commands_per_host=62,
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
    require(sha(PARENT_RESULT)==PARENT_SHA,"Switching previous component result identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"];receipt=read(folder/"receipt.json");decl=read(folder/"declaration.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==122
        and receipt["worlds_opened"]==receipt["solver_steps"]==0
        and result["states"]==118 and result["state_mode_evaluations"]==472
        and result["strict_contact_handoff_accepted"] is False and result["motor_joint_handoff_accepted"] is True,"Switching complete prior component and refusal")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Switching prior artifact digest")
    require(sha(folder/"audit.json")==sha(folder/"reconstruction.json"),"Switching prior reader agreement")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(decl["binding"])
    require(result["contract_sha256"]==sha(prior.CONTRACT) and receipt["contract"]==prior.declaration(),
        "Switching immutable predecessor declaration")
    for name,_,count in prior.GATES:verify_tests(folder/(name+"-controls"),count)
    prior.verify_parent(evidence,core,baseline)
    return result

def audit(evidence,core,baseline):
    c=declaration();verify_parent(evidence,core,baseline);rows=[];trials=[]
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
    return dict(schema_version="locolemotion_hierarchical_contact_component_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_complete_native_reconstruction_verified=True,states=118,state_mode_evaluations=118,trials=trials,rows=rows,
        public_ghosts=verify_public_handoffs(evidence,core,baseline),
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def verify_public_handoffs(evidence,core_path,baseline_path):
    from hierarchical_force_policy import make_profile
    from hierarchical_hold_control import HierarchicalHoldController
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
            for core_file in (core_path,baseline_path):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core)
                host=HierarchicalHoldController(core,compiled,controller_contract(hold_declaration(),model),model,trial,profile)
                rows=[]
                try:
                    for index,old in enumerate(originals):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
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
                        rows.append(row)
                finally:host.close()
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
    args=p.parse_args();value=audit(EVIDENCE,args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,states=118,evaluations=118,worlds_opened=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
