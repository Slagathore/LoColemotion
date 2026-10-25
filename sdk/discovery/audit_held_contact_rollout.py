"""Bind and measure complete five-step forecasts without intermediate observations."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import held_contact_rollout as component
from audit_causal_contact_predictor import ROOT,HERE,ATTEMPT,RECEIPT_SHA,read,sha,require
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_residual_training_closure import verify_population
from posture_factorial_diagnostic import physical_violation
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"held_contact_rollout_v1.json"
SOURCES=("held_contact_rollout.py","audit_held_contact_rollout.py",
    "test_held_contact_rollout.py","run_held_contact_rollout.py")
CONTROLS=44
GATES=(("contact","test_causal_contact_predictor",22),("rollout","test_held_contact_rollout",22))
CLOSURE="sdk2-causal-contact-predictor-v1-4fa0f636af0a4aac88bcc657b76d5c3d"
CLOSURE_SHA="bad687e4e526f781356a3f0fae0cc2afefe6c0652d0ccfd07d9b781b5062dfb1"
CLOSURE_RESULT=HERE/"causal_contact_predictor_result_v1.json"
RESULT_SHA="7e446edcc7fbe42ebcb3cf314839bd5bf4f8753d2281b48aeb48e45d39be2582"
NATIVE_CONTRACT=HERE/"hierarchical_native_v6.json"


def expected_contract():
    return dict(schema_version="locolemotion_held_contact_rollout_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="configured_causal_held_prediction_component",question_class="development"),
        original_attempt=ATTEMPT,original_receipt_sha256=RECEIPT_SHA,
        closure_attempt=CLOSURE,closure_receipt_sha256=CLOSURE_SHA,closure_result_sha256=RESULT_SHA,
        native_contract_sha256=sha(NATIVE_CONTRACT),selection=read(NATIVE_CONTRACT)["selection"],
        controls_required=CONTROLS,command_interval_inclusive=[60,118],commands=59,
        internal_step_interval_inclusive=[301,595],predicted_internal_steps=295,joint_comparisons=2360,
        geometry_validation_rows=595,integration_validation_rows=595,
        geometry_componentwise_tolerance=1e-10,pose_integration_componentwise_tolerance=1e-12,
        steps_per_forecast=5,timestep_s=component.H,
        causal_fields=["starting qpos","starting qvel","one held velocity command"],
        collision_scope="Fixed zero-height plane, one box and eight symmetric local-z capsules from exact XML",
        tangent_frame="Fixed native x/y tangents; circular isotropic friction covariance checked",
        orientation_update="Normalize initial quaternion, right-multiply body-local angular increment using post velocity",
        intermediate_observations_used=False,measured_contact_geometry_used=False,measured_forces_used=False,
        parameters_fitted=False,native_accuracy_acceptance_threshold=None,accuracy_is_descriptive_not_qualification=True,
        worlds_opened=0,native_physics_steps=0,controller_changed=False,trained=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        research_sources=["https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_collision_primitive.c",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_collision_driver.c",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_util_spatial.c",
            "https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_support.c"])


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Rollout exact prospective contract");return c


def orientation_error(left,right):
    a=np.array(left)/np.linalg.norm(left);b=np.array(right)/np.linalg.norm(right)
    scalar=a @ b;vector=a[0]*b[1:]-b[0]*a[1:]-np.cross(a[1:],b[1:])
    return float(2*np.arctan2(np.linalg.norm(vector),abs(scalar)))


def validate_primitives(model,trace,contacts):
    require(len(trace)==len(contacts)==595,"Rollout primitive denominator")
    geometry=integration=0.;count=0
    for index,(row,sample) in enumerate(zip(trace,contacts,strict=True)):
        require(row["step"]==sample["step"]==index+1 and all(same_bits(row[k],sample[k]) for k in
            ("before_qpos","before_qvel","qpos","qvel","ctrl","nefc")),"Rollout original force/pose join")
        geometry=max(geometry,component.compare_geometry(model.detect(row["before_qpos"]),sample["contacts"]))
        count+=len(sample["contacts"])
        predicted=component.integrate_position(row["before_qpos"],row["qvel"])
        integration=max(integration,float(np.max(np.abs(predicted-row["qpos"]))))
    require(integration<=1e-12,"Rollout native pose integration mismatch")
    return dict(geometry_rows=595,matched_contacts=count,maximum_geometry_error=geometry,
        pose_integration_rows=595,maximum_pose_component_error=integration,
        intermediate_native_values_used_only_for_primitive_validation=True)


def measure_command(model,control,actual,selection):
    command=control["outer_step"];ob=control["native_observation"]
    require(len(actual)==5 and all(r["step"]==command*5+i+1 for i,r in enumerate(actual)),"Rollout complete held interval")
    require(ob["qpos"]==actual[0]["before_qpos"] and ob["qvel"]==actual[0]["before_qvel"]
        and all(r["ctrl"]==control["native_targets"] for r in actual),"Rollout identical initial state and held command")
    start=dict(qpos=ob["qpos"],qvel=ob["qvel"],target_velocity=control["native_targets"])
    forecast=model.predict(start)
    result=dict(command=command,starting_state=start,forecast=forecast,comparisons=[])
    if not forecast["accepted"]:return result
    previous=control["force_reference"]["decision"]["allocation"]["prediction"]["predicted_steps"]
    limits=model.contact_model.limits
    for predicted,row,old in zip(forecast["rows"],actual,previous,strict=True):
        pq=np.array(predicted["qpos"]);aq=np.array(row["qpos"])
        pv=np.array(predicted["qvel"]);av=np.array(row["qvel"])
        native_event=physical_violation(row,selection)
        predicted_event=physical_violation(dict(predicted,step=row["step"],time_s=row["time_s"]),selection)
        out=lambda q:[model.model.tree.joint_ids[j] for j in range(8) if q[7+j]<limits[j,0] or q[7+j]>limits[j,1]]
        result["comparisons"].append(dict(command=command,internal_step=row["step"],hold_step=predicted["step"],
            joint_position_error_rad=(pq[7:]-aq[7:]).tolist(),joint_velocity_error_rad_s=(pv[6:]-av[6:]).tolist(),
            root_position_error_m=(pq[:3]-aq[:3]).tolist(),root_orientation_error_rad=orientation_error(pq[3:7],aq[3:7]),
            root_linear_velocity_error_m_s=(pv[:3]-av[:3]).tolist(),root_angular_velocity_error_rad_s=(pv[3:6]-av[3:6]).tolist(),
            previous_held_position_error_rad=(np.array(old["joint_position"])-aq[7:]).tolist(),
            native_physical_violation=native_event,predicted_physical_violation=predicted_event,
            native_joints_outside_limits=out(aq),predicted_joints_outside_limits=out(pq),
            native_contact_geom_pairs=[c["geom"] for c in row["contacts"]],
            predicted_contact_geom_pairs=[c["geom"] for c in predicted["contacts"]]))
    return result


def summarize(results):
    rows=[r for result in results for r in result["comparisons"]]
    def first_event(key):
        row=next((r for r in rows if r[key]),None)
        if row is None:return None
        fields=("command","internal_step","hold_step","native_physical_violation","predicted_physical_violation",
            "native_joints_outside_limits","predicted_joints_outside_limits")
        return {name:row[name] for name in fields}
    def stats(key):
        a=np.concatenate([np.atleast_1d(r[key]) for r in rows])
        return dict(maximum_absolute=float(np.max(np.abs(a))),rms=float(np.sqrt(np.mean(a*a))))
    summary={key:stats(key) for key in ("joint_position_error_rad","joint_velocity_error_rad_s","root_position_error_m",
        "root_orientation_error_rad","root_linear_velocity_error_m_s","root_angular_velocity_error_rad_s","previous_held_position_error_rad")}
    summary.update(compared_steps=len(rows),joint_comparisons=len(rows)*8,
        physical_violation_classification_mismatches=sum(r["native_physical_violation"]!=r["predicted_physical_violation"] for r in rows),
        joint_limit_classification_mismatches=sum(r["native_joints_outside_limits"]!=r["predicted_joints_outside_limits"] for r in rows),
        contact_identity_mismatches=sum(r["native_contact_geom_pairs"]!=r["predicted_contact_geom_pairs"] for r in rows),
        first_native_physical_violation=first_event("native_physical_violation"),
        first_predicted_physical_violation=first_event("predicted_physical_violation"),
        first_native_joint_limit=first_event("native_joints_outside_limits"),
        first_predicted_joint_limit=first_event("predicted_joints_outside_limits"))
    iterations=[row["prediction"]["solution"]["iterations"] for result in results for row in result["forecast"]["rows"]]
    summary["optimization"]=dict(total_iterations=sum(iterations),maximum_iterations=max(iterations))
    return summary


def audit(evidence):
    contract=declaration();original=evidence/ATTEMPT;closure=evidence/CLOSURE
    require(sha(original/"receipt.json")==RECEIPT_SHA and sha(closure/"receipt.json")==CLOSURE_SHA
        and sha(CLOSURE_RESULT)==RESULT_SHA,"Rollout immutable parent identities")
    for folder in (original,closure):verify_population(read(folder/"receipt.json")["artifacts"],inventory(folder))
    receipt=read(closure/"receipt.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==22
        and sha(closure/"audit.json")==sha(closure/"reconstruction.json")==receipt["audit_sha256"]==receipt["reconstruction_sha256"],
        "Rollout complete prior single-step closure")
    folder=original/"physical/hierarchy_hold_left_075_train_001"
    controls=list(read_jsonl(folder/"controller.jsonl"));trace=list(read_jsonl(folder/"trace.jsonl"))
    contacts=list(read_jsonl(folder/"contact-force.jsonl"));profile=read(folder/"force-profile.json")
    require(len(controls)==120 and len(trace)==len(contacts)==595,"Rollout complete retained population")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_integratePos","mju_quatIntegrate","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Rollout calls no native dynamics or geometry")))
        model=component.HeldContactRollout(profile,(folder/"model.xml").read_text(encoding="utf-8"))
        primitive=validate_primitives(model,trace,contacts)
        results=[measure_command(model,controls[i],trace[i*5:i*5+5],contract["selection"]) for i in range(60,119)]
    accepted=sum(r["forecast"]["accepted"] for r in results)
    summary=summarize(results) if accepted==59 else None
    if summary is not None:
        j=model.model.tree.joint_ids.index("rear_left_hip")
        summary["terminal_hip_witness"]=dict(command=118,internal_step=595,joint_id="rear_left_hip",
            actual_position_rad=trace[-1]["qpos"][7+j],predicted_position_rad=results[-1]["forecast"]["final_qpos"][7+j],
            previous_predicted_position_rad=controls[118]["force_reference"]["decision"]["allocation"]["prediction"]["predicted_steps"][-1]["joint_position"][j],
            unchanged_upper_limit_rad=float(model.contact_model.limits[j,1]))
    return dict(schema_version="locolemotion_held_contact_rollout_audit_v1",ok=accepted==59,
        ledger_scope=contract["ledger_scope"],contract_sha256=sha(CONTRACT),primitive_validation=primitive,
        summary=summary,forecasts=results,accepted_forecasts=accepted,
        original_receipt_sha256=RECEIPT_SHA,closure_receipt_sha256=CLOSURE_SHA,
        inputs={name:sha(folder/name) for name in ("controller.jsonl","trace.jsonl","contact-force.jsonl","force-profile.json","model.xml")},
        planned_forecasts=59,steps_per_forecast=5,predicted_steps=accepted*5,
        worlds_opened=0,native_physics_steps=0,intermediate_native_observations_used=False,
        measured_contact_geometry_used=False,measured_forces_used=False,controller_changed=False,
        trained=False,tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=audit(ROOT.parent/"SporeSpore_Evidence");write_new(args.output,result)
    print(json.dumps(dict(ok=result["ok"],output=str(args.output))))
    raise SystemExit(0 if result["ok"] else 1)
