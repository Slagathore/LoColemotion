"""Post-hoc fixed-torso distal-capsule ground reach from immutable native evidence.

This geometric witness establishes reach at a frozen torso pose, not a feasible
trajectory, force distribution, stability guarantee, or causal explanation.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

from adaptation_provider import stance_feedback_v1 as geometry
from audit_cpu_body_gain_closure import verify_record as verify_parent, read
from audit_gpu_batch_execution import read_jsonl
from cpu_body_gain_task import ROOT, sha, require

PARENT = ROOT/"sdk/discovery/cpu_body_gain_discovery_closure_v1.json"
PARENT_SHA = "c677917a4b21d1b59823ec41aaf68db4e67e6d01573ec0496dbd072b565dc9ab"
PREFIX = 180
MARGIN = 1e-6
TOL = 1e-9
SAMPLES = [0,30,60,90,120,150,179]
AUTHORITY = dict(physical_acceptance_authority=False,release_authority=False,training_data_authority=False,
    selection_authority=False,causal_authority=False,population_inference=False)


def bound(pose,leg,radius,hip_limits,knee_limits):
    """Exact minimum height when the straight-leg witness is within joint limits.

    With (A,B,C) = world-y row of the torso rotation, each planar segment
    contributes L*(A*sin(theta)-B*cos(theta)) >= -L*hypot(A,B).
    Both segments attain the bound at hip=-atan2(A,B), knee=0.
    Every point on the distal capsule has shorter or equal total reach.
    """
    a,b,c=geometry.rotation(pose["orientation_xyzw"])[1]
    rho=math.hypot(a,b); require(rho>0,"Degenerate ground projection")
    hip=-math.atan2(a,b)
    require(hip_limits[0] <= hip <= hip_limits[1] and knee_limits[0] <= 0. <= knee_limits[1],
        "Ground-reach witness outside joint limits")
    anchor=geometry.vector(leg["hip_anchor_body_m"])
    minimum=pose["position_m"]["y"]+sum(x*y for x,y in zip([a,b,c],anchor)) \
        -(leg["upper_length_m"]+leg["lower_length_m"])*rho-radius
    point,_=geometry.foot_geometry(leg,hip,0.)
    witness=pose["position_m"]["y"]+geometry.transform(geometry.rotation(pose["orientation_xyzw"]),point)[1]-radius
    require(abs(minimum-witness)<=TOL,"Ground-reach witness equality")
    return dict(minimum_clearance_m=minimum,attaining_hip_rad=hip,attaining_knee_rad=0.,
        ground_below_geometric_minimum=minimum>MARGIN)


def geometry_inputs(physical):
    compiled=read(physical/"compiled.json");model=geometry.definition();geometry.validate_geometry(compiled,model)
    spec=compiled["morphology"]["morphology_spec"]
    joints={j["joint_id"]:j for j in spec["joints"]};sites={s["contact_site_id"]:s for s in spec["contact_sites"]}
    tree=ET.fromstring((physical/"model.xml").read_text(encoding="utf-8"));ground=tree.find("worldbody/geom[@name='ground']")
    require(not tree.findall("default") and ground is not None and ground.attrib["type"]=="plane"
        and ground.get("pos","0 0 0").split()==["0","0","0"]
        and not any(k in ground.attrib for k in ["quat","euler","axisangle","xyaxes","zaxis"]),"Ground plane domain")
    for leg in model["legs"]:
        geom=tree.find(".//geom[@name='"+leg["id"]+"_distal_geom']")
        radius=sites[leg["id"]+"_foot"]["radius_m"];half=leg["lower_length_m"]/2
        require(geom is not None and geom.attrib["type"]=="capsule"
            and list(map(float,geom.attrib["size"].split()))==[radius]
            and list(map(float,geom.attrib["fromto"].split()))==[0.,0.,-half,0.,0.,half],"Native distal capsule geometry")
    return model,joints,sites


def frame(row,model,joints,sites):
    state=row["request"]["state"];pose=state["base_pose_world"];rotate=geometry.rotation(pose["orientation_xyzw"])
    origin=geometry.vector(pose["position_m"])
    angles={j["joint_id"]:j["position_rad"] for j in state["ordered_joint_observations"]}
    bodies={b["body_id"]:b["pose_world"] for b in row["stability"]["ordered_body_states"]}
    contacts={c["contact_site_id"]:c for c in state["ordered_contact_observations"]}
    legs=[];error=0.
    for leg in model["legs"]:
        name=leg["id"];h,k=[angles[name+"_"+j] for j in ["hip","knee"]]
        radius=sites[name+"_foot"]["radius_m"]
        hip_joint,knee_joint=[joints[name+"_"+j] for j in ["hip","knee"]]
        reach=bound(pose,leg,radius,[hip_joint["lower_limit_rad"],hip_joint["upper_limit_rad"]],
            [knee_joint["lower_limit_rad"],knee_joint["upper_limit_rad"]])
        far,_=geometry.foot_geometry(leg,h,k)
        anchor=geometry.vector(leg["hip_anchor_body_m"])
        near=[anchor[0]+leg["upper_length_m"]*math.sin(h),anchor[1]-leg["upper_length_m"]*math.cos(h),anchor[2]]
        predicted=[[x+y for x,y in zip(origin,geometry.transform(rotate,point))] for point in [near,far]]
        distal=bodies[name+"_distal"];dr=geometry.rotation(distal["orientation_xyzw"]);dp=geometry.vector(distal["position_m"])
        measured=[[x+y for x,y in zip(dp,geometry.transform(dr,[0.,sign*leg["lower_length_m"]/2,0.]))] for sign in [1.,-1.]]
        error=max(error,max(abs(x-y) for a,b in zip(predicted,measured) for x,y in zip(a,b)))
        actual=min(p[1] for p in measured)-radius
        require(actual+TOL>=reach["minimum_clearance_m"],"Observed capsule below geometric bound")
        contact=contacts[name+"_foot"]
        legs.append(dict(limb_id=name,**reach,actual_capsule_clearance_m=actual,
            supported=contact["presence"] and contact["bears_support"],normal_load_available=contact["normal_load_n"] is not None,
            current_hip_rad=h,current_knee_rad=k))
    require(error<TOL,"Native/FK endpoint mismatch")
    transfer=row["composition"]["scheduled_load_transfer"]
    return dict(outer_step=row["outer_step"],time_s=row["outer_step"]/120,body_pose=pose,
        body_twist=state["base_twist_world"],legs=legs,maximum_native_endpoint_error_m=error,
        support_count=sum(l["supported"] for l in legs),
        phase_progression_mode=row["request"]["memory"]["phase_progression_mode"],
        ordered_gait_steps={m["limb_id"]:m["gait_step"] for m in row["request"]["memory"]["ordered_limb_memory"]},
        scheduled_transfer_active=transfer["active"],planning_outcome_code=transfer["planning_outcome_code"])


def analyze(evidence_root):
    require(sha(PARENT)==PARENT_SHA,"Parent closure changed")
    parent=read(PARENT);physical=evidence_root/parent["attempt_id"]/"physical"
    observed=read(physical.parent/"independent-audit.json");model,joints,sites=geometry_inputs(physical)
    artifacts={a["evidence_relative_path"]:a["sha256"] for a in parent["artifacts"]}
    files=[physical/n for n in ["compiled.json","model.xml","inputs.json"]]+[physical.parent/"independent-audit.json"]
    require(len(observed["trials"])==10,"Reach source population")
    trials=[]
    for trial in observed["trials"]:
        if trial["candidate_indices"]==[0]:continue
        first=trial["metrics"][0]["first_physical_violation"]
        require(first is None or first["internal_step"]>PREFIX*5,"Reach prefix crosses first violation")
        folder=physical/trial["trial_id"];files.extend([folder/"controller.jsonl",folder/"trace.jsonl"])
        rows=list(read_jsonl(folder/"controller.jsonl"));trace=list(read_jsonl(folder/"trace.jsonl"))
        require(len(rows)==480 and len(trace)==2400 and [r["outer_step"] for r in rows]==list(range(480))
            and [r["step"] for r in trace]==list(range(1,2401)),"Reach raw population/order")
        frames=[frame(row,model,joints,sites) for row in rows[:PREFIX]]
        front=[next(leg for leg in f["legs"] if leg["limb_id"]=="front_right") for f in frames]
        require(all(not leg["normal_load_available"] for f in frames for leg in f["legs"]),
            "Unexpected retained normal load")
        require(all(set(contact)=={"native_index","world","geom","distance_m","position_m","frame"}
            for sample in trace[:PREFIX*5] for contact in sample["contacts"]), "Native contact measurement fields")
        torque=[sample["actuator_force_nm"] for sample in trace[:PREFIX*5]]
        require(all(len(v)==8 for v in torque),"Torque denominator")
        trials.append(dict(trial_id=trial["trial_id"],start_id=trial["start_id"],candidate_index=trial["candidate_indices"][0],
            original_outcome=trial["episodes"][0]["outcome"],controller_rows=PREFIX,completed_internal_samples=PREFIX*5,
            leg_reach_evaluations=4*PREFIX,normal_load_observations_available=sum(l["normal_load_available"] for f in frames for l in f["legs"]),
            front_right_ground_below_minimum_rows=sum(f["ground_below_geometric_minimum"] for f in front),
            front_right_maximum_minimum_clearance_m=max(f["minimum_clearance_m"] for f in front),
            front_right_supported_rows=sum(f["supported"] for f in front),
            support_count_histogram=dict(sorted(Counter(f["support_count"] for f in frames).items())),
            planning_outcome_counts=dict(sorted(Counter(f["planning_outcome_code"] for f in frames).items())),
            scheduled_transfer_active_rows=sum(f["scheduled_transfer_active"] for f in frames),
            maximum_native_endpoint_error_m=max(f["maximum_native_endpoint_error_m"] for f in frames),
            actuator_torques=dict(measurement_stage="completed_substep",sample_count=PREFIX*5,
                mean_absolute_nm=[sum(abs(v[i]) for v in torque)/(PREFIX*5) for i in range(8)],
                maximum_absolute_nm=[max(abs(v[i]) for v in torque) for i in range(8)],
                force_cap_samples=[sum(t["on_force_cap"][i] for t in trace[:PREFIX*5]) for i in range(8)]),
            snapshots=[frames[i] for i in SAMPLES]))
    require(len(trials)==8,"Reach feedback denominator")
    bindings=[]
    for p in files:
        rel=p.relative_to(evidence_root).as_posix();digest=sha(p)
        require(digest==artifacts[rel],"Original reach input changed")
        bindings.append(dict(evidence_relative_path=rel,sha256=digest,byte_length=p.stat().st_size))
    return dict(schema_version="locolemotion_support_reach_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="retained_evidence_diagnostic",question_class="development"),
        parent_closure=dict(path=PARENT.relative_to(ROOT).as_posix(),sha256=PARENT_SHA),
        original_source_commit=parent["source_commit"],source_attempt=parent["attempt_id"],
        reader=dict(path=Path(__file__).relative_to(ROOT).as_posix(),sha256=sha(Path(__file__))),
        post_hoc=True,prefix_chosen_after_outcome=True,source_trial_count=10,analyzed_feedback_trial_count=8,
        common_prefix_outer_rows=PREFIX,controller_rows_analyzed=8*PREFIX,completed_internal_samples_analyzed=8*PREFIX*5,
        leg_reach_evaluations=8*PREFIX*4,ground_height_m=0.,geometry_tolerance_m=TOL,reach_discrimination_margin_m=MARGIN,
        witness="hip=-atan2(R_yx,R_yy); knee=0; verified inside compiled joint limits",
        minimum_clearance_formula="base_y + row_y(R)*hip_anchor - (L1+L2)*hypot(R_yx,R_yy) - capsule_radius",
        interpretation="Exact rigid distal-capsule minimum at fixed torso pose; no trajectory, actuation, force-distribution or causal guarantee.",
        normal_contact_forces_retained=False,actuator_torques_are_contact_forces=False,
        baseline_excluded_from_common_prefix=True,world_build_count=0,solver_steps=0,
        original_ranking=observed["ranking"],trials=trials,source_artifacts=bindings,**AUTHORITY)


def verify_record(record_path,evidence_root,core,baseline):
    verify_parent(PARENT,evidence_root,core,baseline)
    value=read(record_path);computed=analyze(evidence_root)
    # JSON object keys for count histograms have their canonical string form.
    require(value==json.loads(json.dumps(computed,allow_nan=False)),"Reach diagnostic record changed")
    return dict(ok=True,world_build_count=0,solver_steps=0,controller_rows=1440,internal_samples=7200,
        leg_reach_evaluations=5760,maximum_native_endpoint_error_m=max(t["maximum_native_endpoint_error_m"] for t in computed["trials"]),
        **AUTHORITY)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record",type=Path,default=Path(__file__).with_name("support_reach_diagnostic_v1.json"))
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--write",action="store_true");a=p.parse_args()
    if a.write:
        verify_parent(PARENT,a.evidence_root,a.core,a.baseline_core)
        result=analyze(a.evidence_root)
        with a.record.open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")
        print(json.dumps(dict(ok=True,record=str(a.record),world_build_count=0,leg_reach_evaluations=result["leg_reach_evaluations"])))
    else:print(json.dumps(verify_record(a.record,a.evidence_root,a.core,a.baseline_core)))
