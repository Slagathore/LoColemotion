"""Factored upright steering and support-handoff discovery with fresh references."""
import copy
import hashlib
import json
import math
from pathlib import Path

import creature_body_moment as moment
import creature_body_moment_search as parent
import creature_righting as righting
import creature_trajectory_search as trajectory
from creature_batch import require

ROOT = parent.ROOT
SOURCES = dict(parent.SOURCES, **{
    "creature_body_moment_native_result_v1.json": "924055e85319fa4104e8f94a17f1dbc6f17fe2476dc66a3ba4319ff74b227515",
    "creature_body_moment_geometry_result_v1.json": "5b2fb4102ad19cfc8ef1fb6c42cc7b63ce4e8fb301851190cabfac1ee4aa3bc3"})
RECIPE = dict(schema_version="locolemotion_moment_handoff_search_v1", seed=1061137,
    body_indices=parent.RECIPE["body_indices"], route_body_index=16,
    route_proposal_indices=[0,5,10,15,16,21,26,31,32], route_outer_steps=720,
    steering_biases=[-.65,0.,.65], schedules=["continuous","clock","stall"])
PATH_SCREEN = dict(schema_version="locolemotion_prospective_retained_path_screen_v1",
    population="raw_progress_leads_and_fresh_reference", overlap_tolerance_m=1e-9,
    native_joint_angles_unclipped=True, include_initial_state=True,
    required_before_lead_promotion=True, continuous_clearance_authority=False)


def source(name):
    raw=(ROOT/"sdk/discovery"/name).read_bytes()
    require(hashlib.sha256(raw).hexdigest()==SOURCES[name], "Handoff predecessor binding")
    return json.loads(raw)


def references():
    """Choose exposed design comparators; their future worlds must be fresh."""
    path=source("creature_body_moment_geometry_result_v1.json")["path_diagnosis"]["outcomes"]
    native=source("creature_body_moment_native_result_v1.json")
    observations=native["outcomes"]["all_outcomes"]
    profiles=parent.spec(parent.RECIPE)["profiles"]
    indices={p["id"]:i for i,p in enumerate(profiles)}
    selected=[]
    for body in range(24):
        rows=[r for r in path if r["body_index"]==body and r["role"]=="raw_progress_lead"]
        clear=[r for r in rows if r["sampled_path_clear"]]
        if clear:
            row=max(clear,key=lambda r:(r["peak_rotation_degrees"],-indices[r["candidate_id"]]))
            reason="sampled_clear_lead"
        elif rows:
            row=max(rows,key=lambda r:(r["peak_before_first_overlap_degrees"] or 0.,-indices[r["candidate_id"]]))
            reason="exposed_clear_prefix_only"
        else:
            row=max((r for r in observations if r["body_index"]==body and r["candidate_index"]>=2),
                    key=lambda r:(r["peak_rotation_degrees"],-r["candidate_index"]))
            reason="exposed_raw_reference_path_unexamined"
        selected.append(dict(body_index=body,candidate_index=indices[row["candidate_id"]],
                             candidate_id=row["candidate_id"],reason=reason))
    return selected


def proposals():
    bases=parent.proposals();result=[]
    for bias_index,bias in enumerate(RECIPE["steering_biases"]):
        for schedule in RECIPE["schedules"]:
            for axis in range(4):
                p=copy.deepcopy(bases[16+axis])
                family={"continuous":"steady","clock":"pulse","stall":"stall"}[schedule]
                p.update(id=f"{family}_b{bias_index}_axis{axis}",handoff=dict(
                    schema_version="locolemotion_moment_handoff_v1",steering_bias=bias,
                    minimum_tilt_sine=math.sin(math.radians(5.)),axis_slew_rad_per_step=.05,
                    schedule=schedule,minimum_push_steps=45,maximum_push_steps=90 if schedule=="clock" else 180,
                    release_steps=30 if schedule=="clock" else 24,stall_steps=24,progress_deadband_rad_s=.05))
                result.append(moment.profile(p))
    return result


def assignments():
    rows=[[] for _ in range(24)]
    for bias in range(3):
        for schedule in range(3):
            for axis in range(4):
                proposal=axis+4*(schedule+3*bias);first=(3*axis+schedule+4*bias)%12
                for body in (first,(first+5)%12,12+(first+2)%12,12+(first+7)%12):
                    rows[body].append(proposal)
    return rows


def reference_indices(*, route=False):
    if route:return [2]
    refs=references();used=sorted({r["candidate_index"] for r in refs})
    return [2+used.index(r["candidate_index"]) for r in refs]


def spec(*, route=False):
    result=parent.spec(parent.RECIPE)
    refs=references();new=proposals()
    if route:
        body=RECIPE["route_body_index"]
        result.update(schema_version=righting.SCHEMA,descriptors=[result["descriptors"][body]],
            profiles=result["profiles"][:2]+[result["profiles"][refs[body]["candidate_index"]]]
                +[new[i] for i in RECIPE["route_proposal_indices"]])
        del result["profiles_by_body"]
    else:
        used=[0,1]+sorted({r["candidate_index"] for r in refs})
        result["profiles"]=[result["profiles"][i] for i in used]+new
        result["profiles_by_body"]=[[0,1,ref]+sorted(len(used)+i for i in row)
                                   for ref,row in zip(reference_indices(),assignments(),strict=True)]
    return result


def source_dependencies(c):
    return ([ROOT/"sdk/discovery"/n for n in SOURCES]
        +[ROOT/"sdk/discovery"/n for n in ("creature_body_moment_v1.json","creature_body_moment_route_v1.json",
            "creature_moment_handoff_v1.json","creature_moment_handoff_route_v1.json")]
        if "moment_handoff_search" in c else [])


def validate(c):
    opted=any("handoff" in p for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or "moment_handoff_search" in c, "Handoff requires declared search")
    if "moment_handoff_search" not in c:return
    route=c["mode"]=="route_ghost"
    refs=reference_indices(route=route)
    require(c["moment_handoff_search"]==RECIPE and c["mode"] in ("route_ghost","development_discovery")
        and c["righting_spec"]==spec(route=route) and c["trajectory_reference_by_body"]==refs
        and c["reference_selection"]==references()
        and c["trajectory_screen"]==trajectory.POLICY and c["post_native_path_screen"]==PATH_SCREEN
        and c["seed"]==RECIPE["seed"] and c["outer_steps"]==(720 if route else 1440)
        and c["maximum_worlds_per_batch"]==12
        and not any(k in c for k in ("body_moment_search","trajectory_proposal","trajectory_retiming",
                                     "joint_braking_search","contact_reach_search","torso_target_search")),
        "Handoff population, references, clocks or scope")


def verify_route(folder,receipt):
    require(receipt["contract"]["mode"]=="route_ghost" and receipt["audit"]["capture"]["controller_replay_verified"]
        and receipt["audit"]["capture"]["within_run_projection_verified"], "Handoff full route required")
    counts=dict(rows=0,steered=0,release=0,reacquire=0,measured_stall_release=0,bounded_release=0,contact_force=0)
    inventory={r["path"]:r for r in receipt.get("artifacts",[])}
    for batch in receipt["audit"]["batches"]:
        name=f"native/{batch['batch_id']}/controller.jsonl";path=Path(folder)/name
        if inventory:
            require(path.stat().st_size==inventory[name]["bytes"]
                and hashlib.sha256(path.read_bytes()).hexdigest()==inventory[name]["sha256"], "Handoff route stream binding")
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                d=json.loads(line)["resolution"].get("body_moment",{});h=d.get("handoff")
                if h is None:continue
                counts["rows"]+=1;counts["steered"]+=h["upright_steering_available"]
                counts["release"]+=h["phase"]=="release"
                counts["contact_force"]+=bool(d["active_limbs"])
                if h["reason"] in counts:counts[h["reason"]]+=1
                if h["phase"]=="release":require(not d["active_limbs"] and not d["requested_wrenches"],"Handoff unreleased force")
                target=d["state_after"]["inner"]["target"]
                require(target is None or target["target_nonadjacent_gap_m"]>=-1e-9,"Handoff overlapping target")
    require(all(counts.values()),"Handoff route coverage incomplete")
    return dict(counts=counts,complete=True,recovery_qualified=False)
