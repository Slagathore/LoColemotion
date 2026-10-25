"""Retained geometric diagnosis and two-core synthetic reach-aware hold integration."""
import argparse,copy,hashlib,json,math,xml.etree.ElementTree as ET
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import audit_support_reach_native_closure as parent
import hold_horizon_task as native
from hold_horizon_task import ROOT,HERE,read,sha,require,bridge,controller_contract,frozen_model
from audit_gpu_batch_execution import read_jsonl,same_bits
from support_reach_geometry import ReachModel,reference_parameters
from contact_posture_force_policy import make_profile,HANDOFF
from contact_posture_reference import parameters as posture_parameters,retract,point_jacobian
from collections import Counter
from contact_posture_control import ContactPostureController
from causal_force_control import terminal_error
from gpu_measurement_probe import write_new

CONTRACT=HERE/"contact_posture_component_v1.json"
SOURCES=("bounded_posture_solver.py","contact_posture_reference.py","contact_posture_force_policy.py","contact_posture_control.py",
    "audit_contact_posture_component.py","test_bounded_posture_solver.py","test_contact_posture.py","run_contact_posture_component.py")
CONTROLS=46
GATES=(("reach-regression","test_support_reach",18),("posture-solver","test_bounded_posture_solver",15),("posture-reference","test_contact_posture",13))
DENIALS=("physical_launch_authority","physical_acceptance_authority","training_data_authority","release_authority",
    "equivalence_authority","dynamic_feasibility_established","collision_free_path_established",
    "alternative_actions_generated_observations","recovery_benefit_established","tier2_qualified",
    "tier3_benefit_established","capability_estimated","total_target_slew_guaranteed")
TRIALS=("reach_hold_left_075_train_001","reach_hold_nominal_train_001")
INHERITED=("recovery_hold_control.py","recovery_hold_composition.py","causal_force_policy.py",
    "causal_force_allocator.py","actuation_recovery_mechanics.py")
SAMPLES=(60,90,119,132,137,138)


def expected_contract():
    return dict(schema_version="locolemotion_contact_posture_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="retained_contact_posture_and_synthetic_integration",question_class="development"),
        parent_closure_sha256=sha(parent.CLOSURE),implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(HERE/n) for n in INHERITED},reference_parameters=reference_parameters(),posture_parameters=posture_parameters(),
        diagnostic_result_sha256=sha(HERE/"reach_tracking_diagnostic_result_v1.json"),
        trials=list(TRIALS),commands_per_trial=1440,core_reconstructions=2,commands=2880,
        geometry_samples_per_trial=1440,limbs_per_sample=4,geometry_tolerance_m=2e-10,
        positive_clearance_reporting_tolerance_m=1e-9,posthoc_selected_commands=list(SAMPLES),
        observation_source="complete retained reach-hold trajectories; synthetic alternative actions do not produce observations",
        unchanged_prefix_commands_per_trial=60,hold_motion_and_composition_unchanged=True,
        configured_force_and_actuator_limits_unchanged=True,synthetic=True,
        maximum_stream_bytes=2**30,minimum_free_storage_bytes=8*2**30,
        controls_required=CONTROLS,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        world_build_count=0,solver_steps=0,**{k:False for k in DENIALS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Reach component exact declaration/source bindings");return c


class Stream:
    def __init__(self,path,limit):
        self.file=path.open("xb");self.path=path;self.limit=limit;self.bytes=0;self.rows=0;self.digest=hashlib.sha256()
    def append(self,row):
        raw=(json.dumps(row,sort_keys=True,separators=(",",":"),allow_nan=False)+"\n").encode()
        require(self.bytes+len(raw)<=self.limit,"Reach retained stream byte limit")
        self.file.write(raw);self.digest.update(raw);self.bytes+=len(raw);self.rows+=1
    def close(self):
        self.file.close()
        return dict(path=self.path.name,sha256=self.digest.hexdigest(),byte_length=self.bytes,rows=self.rows)


def native_clearances(metadata,row,model):
    observation=row["native_observation"];results=[]
    # Native z-up and canonical y-up heights are identical.
    for leg in model.legs:
        body=leg["limb"]+"_distal";i=metadata["ordered_bodies"].index(body)
        length=leg["lengths"][1];ends=np.array([[0.,0.,length/2],[0.,0.,-length/2]])
        world=np.array(observation["xpos"][i])+ends @ np.array(observation["xmat"][i]).reshape(3,3).T
        results.append(float(world[:,2].min()-leg["radius"]))
    return results


def geometry(folder,original,output,c,failure):
    compiled=read(folder/"compiled.json");model=ReachModel(compiled["morphology"]["morphology_spec"])
    xml=ET.fromstring((folder/"model.xml").read_text(encoding="utf-8"));metadata=read(folder/"native-model.json")
    for leg in model.legs:
        geom=xml.find(".//body[@name='"+leg["limb"]+"_distal']/geom")
        length=leg["lengths"][1]
        require(geom.get("type")=="capsule" and float(geom.get("size"))==leg["radius"]
            and [float(x) for x in geom.get("fromto").split()]==[0.,0.,-length/2,0.,0.,length/2],"Reach XML capsule binding")
    stream=Stream(output,c["maximum_stream_bytes"]);samples=[];max_error=0.;statistics={}
    for limb in model.legs:
        statistics[limb["limb"]+"_foot"]=dict(post_handoff_commands=0,pre_failure_commands=0,
            pre_failure_positive_minimum_clearance=0,post_handoff_positive_minimum_clearance=0,
            first_geometrically_reachable_command=None)
    try:
        for step,row in enumerate(original):
            state=row["request"]["state"]
            require(row["outer_step"]==state["semantic_step"]==step,"Reach original complete clock")
            pose=state["base_pose_world"];q=[v["position_rad"] for v in state["ordered_joint_observations"]]
            values=model.evaluate([pose["position_m"][k] for k in "xyz"],[pose["orientation_xyzw"][k] for k in "xyzw"],q)
            measured=native_clearances(metadata,row,model)
            for value,height in zip(values,measured,strict=True):
                error=abs(value["current_clearance_m"]-height);max_error=max(max_error,error)
                require(error<=c["geometry_tolerance_m"],"Reach canonical/native capsule geometry join")
                if step>=60:
                    stat=statistics[value["contact_site_id"]];stat["post_handoff_commands"]+=1
                    positive=value["minimum_clearance_m"]>c["positive_clearance_reporting_tolerance_m"]
                    stat["post_handoff_positive_minimum_clearance"]+=int(positive)
                    if not positive and stat["first_geometrically_reachable_command"] is None:stat["first_geometrically_reachable_command"]=step
                    before=failure is None or step*5<failure["internal_step"]
                    if before:
                        stat["pre_failure_commands"]+=1;stat["pre_failure_positive_minimum_clearance"]+=int(positive)
            record=dict(command=step,time_s=state["sample_time_s"],body_pose_held_fixed=True,feet=values)
            stream.append(record)
            if step in SAMPLES:samples.append(record)
    finally:info=stream.close()
    require(info["rows"]==1440,"Reach full geometry denominator")
    return dict(stream=info,maximum_native_geometry_error_m=max_error,statistics=statistics,posthoc_samples=samples,
        posthoc=True,full_window_may_include_post_failure_states=True,geometric_reach_is_not_dynamic_feasibility=True)


def verify_posture(posture,state,decision,profile,contacts):
    """Rejoin the recorded virtual reference to raw prepared state and contact points."""
    from actuation_recovery_mechanics import RigidTree,xyz
    tree=RigidTree(profile["morphology_spec"])
    q=np.array([x["position_rad"] for x in state["ordered_joint_observations"]])
    bounds=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in tree.joints])
    reference=np.array(posture["reference_joint_positions_rad"])
    require(reference.shape==(8,) and np.isfinite(reference).all()
        and (reference>=bounds[:,0]-2e-9).all() and (reference<=bounds[:,1]+2e-9).all(),"Posture bounded reference")
    outside=np.where((q<bounds[:,0])|(q>bounds[:,1]))[0].tolist()
    active=[r for r in contacts if r["bears_support"]]
    require(posture["observed_out_of_bounds_joint_indices"]==outside
        and posture["active_sites"]==[r["contact_site_id"] for r in active]
        and posture["reference_only"] is True and posture["root_motion_issued"] is False
        and posture["dynamic_feasibility_established"] is False
        and posture["held_interval_contact_guaranteed"] is False,"Posture scope/observation join")
    if outside or not active:
        require(posture["status"]==("observed_joint_limit_violation" if outside else "unsupported")
            and posture["legacy_bounded_reference_used"] is True and posture["linear_contact_verified"] is False
            and posture["nonlinear_contact_verified"] is False
            and np.array_equal(reference,decision["support_reference"]["reference_joint_positions_rad"]),
            "Posture explicit legacy fallback")
        return dict(contact_drift_m=0.,joint_increment_rad=0.)
    require(posture["status"]=="solved" and posture["legacy_bounded_reference_used"] is False
        and posture["linear_contact_verified"] is True and posture["nonlinear_contact_verified"] is True
        and posture["nonlinear_priority_guaranteed"] is False
        and posture["virtual_base_is_not_actuated"] is True,"Posture solved scope")
    pose=state["base_pose_world"];position=xyz(pose["position_m"])
    orientation=[pose["orientation_xyzw"][k] for k in "xyzw"]
    frame=tree.kinematics(position,orientation,q);w=posture["nonlinear_witness"]
    fraction=w["fraction"];require(fraction==2.**(-w["backtracks"]) and 0<=w["backtracks"]<=16,"Posture backtrack identity")
    delta=np.array(posture["linear_solution"]["delta"])
    limits=np.array([.025]*3+[.08]*3+[.25]*8)
    require(delta.shape==(14,) and np.isfinite(delta).all() and (np.abs(delta)<=limits+2e-9).all(),"Posture reference increment bounds")
    pos,ori,joints=retract(position,orientation,q,fraction*delta)
    require(np.array_equal(reference,joints) and np.array_equal(pos,w["virtual_root_position_m"])
        and np.array_equal(ori,w["virtual_root_orientation_xyzw"]),"Posture retraction identity")
    after=tree.kinematics(pos,ori,joints);sites={r["contact_site_id"]:r for r in tree.spec["contact_sites"]}
    displacements=[];linear=[]
    for contact in active:
        body=sites[contact["contact_site_id"]]["body_id"];i=tree.index[body];point=xyz(contact["point_world_m"])
        local=frame["rotations"][i].T@(point-frame["positions"][i])
        displacements.append(after["positions"][i]+after["rotations"][i]@local-point)
        linear.extend(point_jacobian(tree,frame,body,point)@(fraction*delta))
    drift=float(np.max(np.linalg.norm(displacements,axis=1),initial=0.))
    require(np.max(np.abs(linear),initial=0.)<=2e-9 and np.allclose(displacements,w["contact_displacements_m"],rtol=0,atol=2e-12)
        and abs(drift-w["maximum_contact_displacement_m"])<=2e-12 and drift<=.0005,"Posture complete nonlinear contact witness")
    require(np.allclose(after["whole_body_com"]-decision["target_com"],posture["nonlinear_com_error_m"],rtol=0,atol=2e-12),"Posture COM witness")
    return dict(contact_drift_m=drift,joint_increment_rad=float(np.max(np.abs(reference-q))))


def audit(evidence,core_path,baseline_path,output_dir):
    c=declaration();output_dir.mkdir()
    verified=parent.verify_record(parent.CLOSURE,evidence,core_path,baseline_path)
    attempt=parent.header(read(parent.CLOSURE),evidence);old_audit=read(attempt/"audit.json")
    failure={t["trial_id"]:t["diagnostic_metrics"]["first_physical_violation"] for t in old_audit["trials"]}
    trials=[];streams=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Reach component opens no world")))
        for identity in TRIALS:
            folder=attempt/"physical"/identity;original=list(read_jsonl(folder/"controller.jsonl"))
            require(len(original)==1440,"Reach original full denominator")
            geo=geometry(folder,original,output_dir/(identity+"-geometry.jsonl"),c,failure[identity])
            streams.append(geo["stream"]);compiled=read(folder/"compiled.json")
            profile=make_profile(compiled,read(folder/"inputs.json"));runs=[]
            for core_number,core_file in enumerate((core_path,baseline_path)):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core)
                host=ContactPostureController(core,compiled,controller_contract(native.declaration(),model),model,identity,profile)
                stream=Stream(output_dir/(identity+"-core-"+str(core_number)+".jsonl"),c["maximum_stream_bytes"])
                previous_row=None;first_height=None;last_height=None;max_delta=0.;min_height=math.inf;max_target=0.;unresolved=0;statuses=Counter();task_ranks={};max_contact_drift=0.;max_joint_increment=0.
                try:
                    for step,old in enumerate(original):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        if terminal_error(row) is not None:
                            stream.append(dict(synthetic=True,alternative_actions_generated_observations=False,controller=row))
                            raise ValueError(f"Posture successor terminal refusal at command {step}: {terminal_error(row)}")
                        if step<60:require(all(same_bits(v,old[k]) for k,v in row.items()),"Reach unchanged original prefix")
                        else:
                            request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
                            reference=decision["support_reference"];height=reference["target_com_height_m"]
                            nominal=host.force_policy.height
                            if first_height is None:first_height=nominal;last_height=nominal
                            require(nominal-.10-1e-12<=height<=last_height+1e-12
                                and last_height-height<=.20/120.+1e-12,"Reach monotone bounded reference and rate")
                            max_delta=max(max_delta,last_height-height);min_height=min(min_height,height);last_height=height
                            unresolved+=int(reference["remaining_fixed_pose_gap_m"]>1e-9)
                            posture=decision["posture_reference"];status=posture["status"];statuses[status]+=1
                            check=verify_posture(posture,row["request"]["state"],decision,profile,
                                request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"])
                            max_contact_drift=max(max_contact_drift,check["contact_drift_m"])
                            max_joint_increment=max(max_joint_increment,check["joint_increment_rad"])
                            if status=="solved":
                                for report in posture["linear_solution"]["tasks"]:
                                    task_ranks.setdefault(report["name"],Counter())[str(report["attainable_rank"])]+=1
                            require(row["request"]["memory"]==previous_row["output"]["next_memory"],"Reach baseline memory continuity")
                            require(request["history"]["ordered_entries"][-1]["semantic_step"]==step-1,"Reach resolved history clock")
                            for before,command,limit in zip(previous_row["resolution"]["ordered_commands"],row["resolution"]["ordered_commands"],
                                    request["safety_envelope"]["ordered_actuator_limits"],strict=True):
                                prior=before["applied_correction_rad_s"]
                                require(limit["previous_applied_correction_rad_s"]==prior
                                    and limit["maximum_absolute_correction_rad_s"]==3.5 and limit["maximum_slew_per_step_rad_s"]==.08
                                    and abs(command["applied_correction_rad_s"]-prior)<=.08+1e-12
                                    and abs(command["applied_correction_rad_s"])<=3.5
                                    and abs(command["final_canonical_target_velocity_rad_s"])<=3.5,"Reach unchanged resolved limits")
                            max_target=max(max_target,max(abs(x) for x in row["native_targets"]))
                        stream.append(dict(synthetic=True,alternative_actions_generated_observations=False,controller=row))
                        previous_row=row
                    require(host.next_step==1440 and host.force_memory["sequence"]==1380,"Reach complete controller memory")
                finally:
                    host.close();info=stream.close();streams.append(info)
                require(host.closed and info["rows"]==1440,"Reach complete closed host")
                runs.append(dict(stream=info,nominal_com_reference_m=first_height,minimum_com_reference_m=min_height,
                    final_com_reference_m=last_height,maximum_reference_step_m=max_delta,
                    maximum_absolute_final_target_rad_s=max_target,unresolved_fixed_pose_gap_commands=unresolved,
                    posture_status_counts=dict(sorted(statuses.items())),task_attainable_rank_counts={k:dict(sorted(v.items())) for k,v in task_ranks.items()},
                    maximum_nonlinear_contact_drift_m=max_contact_drift,maximum_joint_reference_increment_rad=max_joint_increment))
            require(runs[0]["stream"]["sha256"]==runs[1]["stream"]["sha256"],"Reach every synthetic row other-core identity")
            trials.append(dict(trial_id=identity,observation_sha256=sha(folder/"controller.jsonl"),
                geometry=geo,synthetic_runs=runs,original_failure=failure[identity],controller_profile_sha256=core.canonicalize_json(profile)["sha256"],
                alternative_trajectory_simulated=False,recovery_effectiveness_measured=False))
    return dict(schema_version="locolemotion_contact_posture_component_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_closure_sha256=sha(parent.CLOSURE),parent_reconstruction_verified=verified["ok"],
        parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",synthetic=True,trials=trials,streams=streams,
        commands=2880,core_reconstructions=2,unchanged_prefix_commands=120,geometry_limb_observations=11520,
        world_build_count=0,solver_steps=0,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core,args.output.with_suffix(""))
    write_new(args.output,result);print(json.dumps(dict(ok=True,commands=2880,world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
