"""Validate portable mechanics against retained prepared-state geometry and forces."""
import argparse
import copy
from contextlib import ExitStack
import json
import hashlib
from pathlib import Path
from unittest.mock import patch

import mujoco
import numpy as np
import actuation_recovery_mechanics as mechanics
import audit_contact_force_observer_closure as parent
from audit_gpu_batch_execution import same_bits,read_jsonl
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require,bridge

CONTRACT=HERE/"actuation_recovery_mechanics_v1.json"
SOURCES=("actuation_recovery_mechanics.py","actuation_recovery_mechanics_audit.py",
    "test_actuation_recovery_mechanics.py","run_actuation_recovery_mechanics.py")
TRIALS=("observer_on_left_075_train_001","observer_on_nominal_train_001")
C=np.array([[1.,0.,0.],[0.,0.,1.],[0.,-1.,0.]])
CONTROLS=25


def expected_contract():
    return dict(schema_version="locolemotion_actuation_recovery_mechanics_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_mechanical_component_validation",question_class="development"),
        parent_closure_path=parent.CLOSURE.relative_to(ROOT).as_posix(),parent_closure_sha256=sha(parent.CLOSURE),
        trials=list(TRIALS),commands_per_trial=120,expected_frames=240,expected_joint_entries=1920,
        controls_required=CONTROLS,geometry_absolute_tolerance=2e-12,geometry_relative_tolerance=2e-12,
        finite_difference_step_rad=1e-6,derivative_absolute_tolerance=2e-7,
        derivative_relative_tolerance=2e-7,actuation_absolute_tolerance=1e-12,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        capability_source="declared_configured_native_model_for_reference_only",
        torque_scope="instantaneous_at_prepared_velocity",
        force_scope="original_current_solve_joined_to_its_prepared_geometry",
        projection_scope="noncausal_posthoc_algebra_check_not_a_control_trial",
        original_fallback_preserved=True,resolver_projection_is_fresh_synthetic_provider=True,
        current_solve_force_available_before_control=False,capability_estimated=False,
        held_interval_force_guaranteed=False,dynamic_feasibility_established=False,
        controller_changed=False,physical_worlds_opened=0,solver_steps=0,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,
        training_data_authority=False,release_authority=False,equivalence_authority=False)


def declaration():
    value=read(CONTRACT)
    require(value==expected_contract(),"Mechanics exact component declaration")
    return value


def compare_values(actual,expected,absolute,relative,label):
    actual=np.asarray(actual,dtype=np.float64);expected=np.asarray(expected,dtype=np.float64)
    require(actual.shape==expected.shape and np.isfinite(actual).all() and np.isfinite(expected).all()
        and np.all(np.abs(actual-expected)<=absolute+relative*np.maximum(np.abs(actual),np.abs(expected))),label)
    return float(np.max(np.abs(actual-expected),initial=0.))


def join_frame(control,sample,trace,index):
    native=control["native_observation"]
    require(control["outer_step"]==control["request"]["state"]["semantic_step"]==index
        and sample["step"]==trace["step"]==5*index+1
        and sample["prepared_time_s"]==native["time_s"]
        and sample["integrated_time_s"]==trace["time_s"]
        and all(same_bits(sample[key],native[other]) for key,other in
                (("before_qpos","qpos"),("before_qvel","qvel")))
        and all(same_bits(sample[key],trace[key]) for key in ("before_qpos","before_qvel","ctrl")),
        "Mechanics exact prepared-state/force join")
    require(same_bits(sample["ctrl"],control["native_targets"]),"Mechanics force belongs to original command")


def contact_wrenches(sample):
    result=[]
    for contact in sample["contacts"]:
        point=C @ mechanics.array(contact["position_m"],(3,),"Mechanics raw contact position")
        for side,sign in ((0,-1.),(1,1.)):
            if contact["body_ids"][side]==0:
                require(contact["body_names"][side]=="world","Mechanics world body attribution")
                continue
            result.append(dict(body_id=contact["body_names"][side],point=point,
                force=sign*np.array(contact["force_on_geom2_canonical_n"]),
                torque=sign*np.array(contact["torque_on_geom2_canonical_nm"])))
    return result


def native_geometry(model,frame,native,c):
    require(len(native["xpos"])==len(native["xipos"])==len(native["xmat"])==len(model.bodies)+1
        and len(native["xanchor"])==len(native["xaxis"])==model.n+1,"Mechanics native population")
    expected=dict(positions=np.array(native["xpos"][1:]) @ C.T,
        centers=np.array(native["xipos"][1:]) @ C.T,
        rotations=np.array([C @ np.array(row).reshape(3,3) @ C.T for row in native["xmat"][1:]]),
        anchors=np.array(native["xanchor"][1:]) @ C.T,axes=np.array(native["xaxis"][1:]) @ C.T,
        whole_body_com=C @ np.array(native["subtree_com"][1]))
    return {key:compare_values(frame[key],value,c["geometry_absolute_tolerance"],
        c["geometry_relative_tolerance"],"Mechanics native "+key) for key,value in expected.items()}


def finite_difference_torques(model,position,orientation,q,frame,wrenches,gravity,c):
    h=c["finite_difference_step_rad"];observed=np.zeros(model.n);gravity_observed=np.zeros(model.n)
    local=[(model.index[w["body_id"]],frame["rotations"][model.index[w["body_id"]]].T
        @ (w["point"]-frame["positions"][model.index[w["body_id"]]]),w) for w in wrenches]
    for i in range(model.n):
        delta=np.eye(model.n)[i]*h
        plus=model.kinematics(position,orientation,q+delta);minus=model.kinematics(position,orientation,q-delta)
        for body,point,w in local:
            velocity=(plus["positions"][body]+plus["rotations"][body] @ point
                     -minus["positions"][body]-minus["rotations"][body] @ point)/(2*h)
            skew=((plus["rotations"][body]-minus["rotations"][body])/(2*h)) @ frame["rotations"][body].T
            angular=np.array([skew[2,1],skew[0,2],skew[1,0]])
            observed[i]+=float(velocity @ w["force"]+angular @ w["torque"])
        gravity_observed[i]=float(np.sum(model.mass*((plus["centers"]-minus["centers"]) @ gravity)))/(2*h)
    errors=[]
    for actual,expected,label in ((model.wrench_torques(frame,wrenches),observed,"contact"),
        (model.gravity_torques(frame,gravity),gravity_observed,"gravity")):
        errors.append(compare_values(actual,expected,c["derivative_absolute_tolerance"],
            c["derivative_relative_tolerance"],"Mechanics virtual-work derivative "+label))
    return errors


def command_limits(control):
    request=control["resolution_request"]["provider_request"]
    limits=request["safety_envelope"]["ordered_actuator_limits"]
    commands=control["resolution"]["ordered_commands"]
    require([x["actuator_id"] for x in commands]==[x["actuator_id"] for x in limits],
        "Mechanics ordered command envelope")
    return mechanics.command_envelope(
        [x["baseline_canonical_target_velocity_rad_s"] for x in commands],
        [x["maximum_target_speed_rad_s"] for x in commands],
        [x["previous_applied_correction_rad_s"] for x in limits],
        [x["maximum_absolute_correction_rad_s"] for x in limits],
        [x["maximum_slew_per_step_rad_s"] for x in limits])


def projection_fixture(core,control):
    from portable_search_control import initial_memory,EMPTY_CORPUS
    request=copy.deepcopy(control["resolution_request"]["provider_request"])
    request.update(provider_id="actuation_mechanics_algebra",
        expected_provider_version="untrained_mechanics_algebra_v1",
        expected_model_id="actuation_mechanics_resolver_fixture_v1",
        expected_model_sha256=core.canonicalize_json(dict(kind="actuation_mechanics_resolver_fixture_v1",
            component_contract_sha256=sha(CONTRACT)))["sha256"],
        expected_training_corpus_id="untrained_no_training_corpus",
        expected_training_corpus_sha256=core.canonicalize_json(EMPTY_CORPUS)["sha256"],
        history=dict(schema_version="sporespore_adaptation_history_v1",ordered_entries=[]),
        provider_memory=initial_memory(core))
    request["provider_memory"]["provider_id"]=request["provider_id"]
    return request


def original_command(envelope,control,c):
    resolved=control["resolution"]
    if resolved["deterministic_baseline_fallback_used"]:
        require(resolved["fallback_reason"] is not None
            and all(x["applied_correction_rad_s"]==0. for x in resolved["ordered_commands"]),
            "Mechanics preserved original fallback")
        return np.clip(envelope["baseline"],-envelope["speeds"],envelope["speeds"])
    require(resolved["provider_status"]=="applied","Mechanics original applied status")
    proposed=[x["proposed_correction_rad_s"] for x in resolved["ordered_commands"]]
    return mechanics.resolve_correction(envelope,proposed)[1]


def verify_projection_with_core(core,control,projection,c):
    from portable_search_control import proposal
    request=projection_fixture(core,control)
    response=proposal(core,request,dict(factor=0.))
    response["diagnostics"]=["synthetic mechanics resolver check; not an actor output or physical control"]
    for row,value in zip(response["ordered_corrections"],projection["proposal"],strict=True):
        row["canonical_velocity_delta_rad_s"]=float(value)
    resolved=core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
        provider_request=request,provider_response=response))
    require(resolved["provider_status"]=="applied" and not resolved["deterministic_baseline_fallback_used"],
        "Mechanics synthetic projection resolver refusal")
    return compare_values([x["final_canonical_target_velocity_rad_s"] for x in resolved["ordered_commands"]],
        projection["target"],c["actuation_absolute_tolerance"],0.,"Mechanics projected target/core join")


def audit(evidence,core_path,baseline_path):
    c=declaration();closure=read(parent.CLOSURE)
    # Verify the complete parent, including original force decoding, raw files
    # and controller replay, before selecting the two observer-on streams.
    parent_result=parent.verify_record(parent.CLOSURE,evidence,core_path,baseline_path)
    attempt=parent.header(closure,evidence);rows=[];trials=[];core=bridge.LocomotionCore(baseline_path)
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Mechanics reader opens no world")))
        for identity in TRIALS:
            folder=attempt/"physical"/identity
            compiled=read(folder/"compiled.json");spec=read(folder/"inputs.json");metadata=read(folder/"native-model.json")
            model=mechanics.RigidTree(compiled["morphology"]["morphology_spec"])
            require(metadata["ordered_bodies"]==["world"]+model.body_ids and spec["ordered_joints"]==model.joint_ids,
                "Mechanics compiled/native ordering")
            controls=list(read_jsonl(folder/"controller.jsonl"));samples=list(read_jsonl(folder/"contact-force.jsonl"))
            traces=list(read_jsonl(folder/"trace.jsonl"))
            require(len(controls)==120 and len(samples)==len(traces)==600,"Mechanics full retained denominator")
            geometry={};contact_error=gravity_error=force_error=target_error=projection_error=0.;contacts=clipped=0
            for index,control in enumerate(controls):
                sample=samples[5*index];trace=traces[5*index];join_frame(control,sample,trace,index)
                state=control["request"]["state"];pose=state["base_pose_world"]
                position=mechanics.xyz(pose["position_m"])
                orientation=[pose["orientation_xyzw"][key] for key in ("x","y","z","w")]
                q=np.array([x["position_rad"] for x in state["ordered_joint_observations"]])
                velocity=np.array([x["velocity_rad_s"] for x in state["ordered_joint_observations"]])
                frame=model.kinematics(position,orientation,q)
                for key,value in native_geometry(model,frame,control["native_observation"],c).items():
                    geometry[key]=max(geometry.get(key,0.),value)
                wrenches=contact_wrenches(sample);gravity=mechanics.xyz(state["gravity_world_m_s2"])
                errors=finite_difference_torques(model,position,orientation,q,frame,wrenches,gravity,c)
                contact_error=max(contact_error,errors[0]);gravity_error=max(gravity_error,errors[1])
                envelope=command_limits(control)
                original_target=original_command(envelope,control,c)
                target_error=max(target_error,compare_values(original_target,control["native_targets"],
                    c["actuation_absolute_tolerance"],0.,"Mechanics original target/core join"))
                measured=np.array(trace["actuator_force_nm"])
                predicted=mechanics.motor_torque(original_target,velocity,spec["velocity_gains"],spec["force_ranges"])
                force_error=max(force_error,compare_values(predicted,measured,c["actuation_absolute_tolerance"],0.,
                    "Mechanics original prepared motor force"))
                projection=mechanics.command_for_static_wrenches(model,frame,wrenches,gravity,
                    envelope,velocity,spec["velocity_gains"],spec["force_ranges"])
                projection_error=max(projection_error,verify_projection_with_core(core,control,projection,c))
                count=int(np.sum(np.abs(projection["torque_error"])>c["actuation_absolute_tolerance"]))
                clipped+=count;contacts+=len(sample["contacts"])
                value={key:value.tolist() if isinstance(value,np.ndarray) else value for key,value in projection.items()}
                rows.append(dict(trial_id=identity,command=index,native_prepared_time_s=sample["prepared_time_s"],
                    force_integrated_time_s=sample["integrated_time_s"],contact_count=len(sample["contacts"]),
                    noncausal_posthoc_projection=True,synthetic_response_used_only_for_core_check=True,
                    original_provider_status=control["resolution"]["provider_status"],
                    original_fallback_used=control["resolution"]["deterministic_baseline_fallback_used"],
                    original_measured_motor_torque_nm=measured.tolist(),projection=value))
            trials.append(dict(trial_id=identity,frames=120,joint_entries=120*model.n,
                source_model_sha256=sha(folder/"compiled.json"),native_xml_sha256=sha(folder/"model.xml"),
                geometry_max_absolute_error=geometry,contact_virtual_work_max_absolute_error_nm=contact_error,
                gravity_virtual_work_max_absolute_error_nm=gravity_error,motor_force_max_absolute_error_nm=force_error,
                original_target_max_absolute_error_rad_s=target_error,
                projected_target_core_max_absolute_error_rad_s=projection_error,
                selected_contact_count=contacts,clipped_posthoc_joint_requests=clipped))
    require(len(rows)==240 and sum(t["joint_entries"] for t in trials)==1920,"Mechanics complete component population")
    return dict(schema_version="locolemotion_actuation_recovery_mechanics_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_closure_sha256=sha(parent.CLOSURE),
        parent_reconstruction_sha256=hashlib.sha256(json.dumps(parent_result,sort_keys=True,
            separators=(",",":"),allow_nan=False).encode("utf-8")).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",
        parent_reconstruction_verified=parent_result["ok"],frames=240,joint_entries=1920,
        trials=trials,rows=rows,worlds_opened=0,solver_steps=0,controller_changed=False,
        capability_estimated=False,current_solve_force_available_before_control=False,
        dynamic_feasibility_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,equivalence_authority=False)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    value=audit(args.evidence_root,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,frames=value["frames"],worlds_opened=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
