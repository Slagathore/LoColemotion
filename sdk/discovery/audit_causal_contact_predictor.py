"""Measure a causal one-step predictor on a complete retained population."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import causal_contact_predictor as component
from audit_held_dynamics_diagnostic_v2 import ROOT,HERE,ATTEMPT,RECEIPT_SHA,read,sha,require
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"causal_contact_predictor_v1.json"
SOURCES=("causal_contact_predictor.py","audit_causal_contact_predictor.py",
    "test_causal_contact_predictor.py","run_causal_contact_predictor.py")
CONTROLS=22
GATES=(("contact","test_causal_contact_predictor",CONTROLS),)
CLOSURE="sdk2-held-dynamics-diagnostic-v2-eaba37fce54247f5967e1d27901c1920"
CLOSURE_SHA="5f8adc8d0f7b5978ab2abd4c922b928215a71d51d42011bdba15dba83166fffb"
CLOSURE_RESULT=HERE/"held_dynamics_diagnostic_result_v2.json"
RESULT_SHA="e18f1405bcb3890c94137ff565175c734dd0dc19ba5913d4ec4df91053369ac8"


def expected_contract():
    return dict(schema_version="locolemotion_causal_contact_predictor_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_causal_single_step_component",question_class="development"),
        original_attempt=ATTEMPT,original_receipt_sha256=RECEIPT_SHA,
        closure_attempt=CLOSURE,closure_receipt_sha256=CLOSURE_SHA,closure_result_sha256=RESULT_SHA,
        controls_required=CONTROLS,settings=component.SETTINGS,
        commands=list(range(60,119)),internal_steps=list(range(301,596)),joint_comparisons=2360,
        causal_fields=["prepared qpos","prepared qvel","prepared contact geom, distance, position and frame","candidate velocity command"],
        configured_parameters="Exact retained XML, profile and MuJoCo 3.11 defaults; not estimated or fitted",
        contact_model="Strictly convex dual with circular Coulomb cones, positive impedance regularization and scalar limits",
        optimization="Cold-start accelerated projected gradient with independent cone KKT checks",
        integration="Unmodified continuous contact solve followed by direct-servo implicitfast velocity update",
        reference_weights="Body COM inverse-inertia trace and joint inverse-inertia diagonal at configured qpos0",
        first_step_comparison_commands=59,future_forces_used=False,post_step_state_used=False,
        native_accuracy_acceptance_threshold=None,accuracy_is_descriptive_not_qualification=True,
        new_native_calls=0,worlds_opened=0,physics_solver_steps=0,trained=False,controller_changed=False,
        full_hold_prediction_established=False,contact_detection_implemented=False,portable_contact_law_established=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        research_sources=["https://mujoco.readthedocs.io/en/3.11.0/computation/index.html#dual-problem",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_core_constraint.c",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_setconst.c",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_forward.c"])


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Contact exact prospective declaration");return c


def measure(model,control,trace,contact):
    require(trace["step"]==contact["step"] and all(trace[k]==contact[k] for k in
        ("before_qpos","before_qvel","qpos","qvel","ctrl","nefc")),"Contact exact prepared/post-step join")
    packet=component.prepared_packet(trace["before_qpos"],trace["before_qvel"],contact["contacts"],trace["ctrl"])
    first=(trace["step"]-1)%5==0
    if first:
        ob=control["native_observation"]
        require(same_bits(packet,component.prepared_packet(ob["qpos"],ob["qvel"],ob["contacts"],control["native_targets"])),
            "Contact packet available at original control boundary")
    problem=model.problem(packet);prediction=model.predict(packet)
    require(prediction["accepted"] is True,"Contact numerical refusal retained")
    actual=[]
    for item in problem["identities"]:
        if item["kind"]=="contact":
            row=contact["contacts"][item["native_index"]]
            require(row["dim"]==3 and row["exclude"]==0 and row["adhesion_n"]==0.,"Contact observed qualified cone")
            actual.extend(row["local_force_n"])
        else:
            joint=model.model.tree.joint_ids.index(item["joint_id"])+1
            matches=[f for typ,identity,f in zip(contact["efc_type"],contact["efc_id"],contact["efc_force"],strict=True) if typ==3 and identity==joint]
            require(len(matches)==1,"Contact observed scalar limit identity");actual.extend(matches)
    require(len(actual)==contact["nefc"],"Contact complete observed constraint population")
    force=np.array(prediction["solution"]["force"]);actual=np.array(actual)
    old=control["force_reference"]["decision"]["allocation"]["prediction"]["predicted_steps"][(trace["step"]-1)%5]
    post=np.array(trace["qpos"][7:]);velocity=np.array(trace["qvel"])
    result=dict(command=(trace["step"]-1)//5,internal_step=trace["step"],first_step=first,
        prepared_packet=packet,prediction=prediction,observed_local_constraint_force=actual.tolist(),
        local_constraint_force_error=(force-actual).tolist(),
        joint_position_error_rad=(np.array(prediction["post_joint_position"])-post).tolist(),
        joint_velocity_error_rad_s=(np.array(prediction["post_velocity"])[6:]-velocity[6:]).tolist(),
        root_linear_velocity_error_m_s=(np.array(prediction["post_velocity"])[:3]-velocity[:3]).tolist(),
        root_angular_velocity_error_rad_s=(np.array(prediction["post_velocity"])[3:6]-velocity[3:6]).tolist(),
        previous_held_position_error_rad=(np.array(old["joint_position"])-post).tolist(),
        native_force_kkt=component.certificate(problem["matrix"],problem["linear"],actual,problem["blocks"]))
    return result


def summarize(rows):
    def stats(values):
        a=np.concatenate([np.array(v) for v in values]);return dict(maximum_absolute=float(np.max(np.abs(a))),rms=float(np.sqrt(np.mean(a*a))))
    first=[r for r in rows if r["first_step"]]
    summary={key:stats([r[key] for r in rows]) for key in ("local_constraint_force_error","joint_position_error_rad",
        "joint_velocity_error_rad_s","root_linear_velocity_error_m_s","root_angular_velocity_error_rad_s")}
    summary["same_initial_state_first_step_comparison"]=dict(commands=len(first),joint_comparisons=len(first)*8,
        causal_contact_predictor=stats([r["joint_position_error_rad"] for r in first]),
        previous_frozen_force_predictor=stats([r["previous_held_position_error_rad"] for r in first]))
    summary["optimization"]=dict(total_iterations=sum(r["prediction"]["solution"]["iterations"] for r in rows),
        maximum_iterations=max(r["prediction"]["solution"]["iterations"] for r in rows),
        maximum_certificate_errors={key:max(r["prediction"]["solution"]["certificate"][key] for r in rows)
            for key in ("primal_violation","dual_violation","maximum_complementarity")})
    summary["native_force_certificate_pass_count"]=sum(r["native_force_kkt"]["accepted"] for r in rows)
    summary["native_force_maximum_certificate_errors"]={key:max(r["native_force_kkt"][key] for r in rows)
        for key in ("primal_violation","dual_violation","maximum_complementarity")}
    return summary


def audit(evidence):
    contract=declaration();original=evidence/ATTEMPT;closure=evidence/CLOSURE
    require(sha(original/"receipt.json")==RECEIPT_SHA and sha(closure/"receipt.json")==CLOSURE_SHA
        and sha(CLOSURE_RESULT)==RESULT_SHA,"Contact immutable parent identities")
    for folder in (original,closure):verify_population(read(folder/"receipt.json")["artifacts"],inventory(folder))
    receipt=read(closure/"receipt.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==18
        and sha(closure/"audit.json")==sha(closure/"reconstruction.json")==receipt["audit_sha256"]==receipt["reconstruction_sha256"],
        "Contact complete prior diagnostic closure")
    folder=original/"physical/hierarchy_hold_left_075_train_001"
    controls=list(read_jsonl(folder/"controller.jsonl"));trace=list(read_jsonl(folder/"trace.jsonl"))
    contact=list(read_jsonl(folder/"contact-force.jsonl"));profile=read(folder/"force-profile.json")
    require(len(controls)==120 and len(trace)==len(contact)==595,"Contact exact retained denominator")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Contact predictor opens no world")))
        model=component.ContactPredictor(profile,(folder/"model.xml").read_text(encoding="utf-8"))
        rows=[measure(model,controls[index//5],trace[index],contact[index]) for index in range(300,595)]
    return dict(schema_version="locolemotion_causal_contact_predictor_audit_v1",ok=True,
        ledger_scope=contract["ledger_scope"],contract_sha256=sha(CONTRACT),summary=summarize(rows),rows=rows,
        body_inverse_weights=model.body_weight,joint_inverse_weights=model.dof_weight.tolist(),
        original_receipt_sha256=RECEIPT_SHA,closure_receipt_sha256=CLOSURE_SHA,
        inputs={name:sha(folder/name) for name in ("controller.jsonl","trace.jsonl","contact-force.jsonl","force-profile.json","model.xml")},
        predictions=295,original_control_boundary_packets_verified=59,joint_comparisons=2360,
        worlds_opened=0,physics_solver_steps=0,future_forces_used=False,post_step_state_used=False,
        full_hold_prediction_established=False,contact_detection_implemented=False,controller_changed=False,
        trained=False,tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();write_new(args.output,audit(ROOT.parent/"SporeSpore_Evidence"))
    print(json.dumps(dict(ok=True,output=str(args.output))))
