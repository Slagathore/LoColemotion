"""Finite force/momentum cohort, sharing native ownership, capture and readers."""
import copy
import hashlib
import json
from pathlib import Path

from creature_batch import require
from creature_contact_envelope import body_population
import creature_body_moment as moment
import creature_joint_braking_search as braking
import creature_righting as righting
import creature_trajectory_search as trajectory

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "creature_torso_target_v1.json":"edc5bcf58dc07ebb125e1a8fbaed44002f322e9493ca9242a376629952166097",
    "creature_contact_envelope_v1.json":"34a686183b67fc7facbd2567c7cd82dcc36967e1165137b7c38f23127bbeffce",
    "creature_contact_moment_result_v1.json":"dbb39a0802b9a357778671b6b9b33848b85f2e15b899f548d79b9a2ef43a1cd5",
    "creature_contact_moment_v1.json":"b519575fedf74a2700a472666bf4688ec253b308e8972f6139caf7fe73148fd2"}
RECIPE = dict(schema_version="locolemotion_body_moment_search_v1",seed=1061135,
    body_indices=[10,20,21,28,31,97,127,139,186,244,292,327,
                  0,1,2,6,16,32,78,150,200,250,300,333],
    route_body_index=1,route_profile_indices=[0,1,2,11,20,5,14,23,8,17],route_outer_steps=720)


def source(name):
    raw=(ROOT/"sdk/discovery"/name).read_bytes()
    require(hashlib.sha256(raw).hexdigest()==SOURCES[name],"Moment predecessor binding")
    return json.loads(raw)


def proposals():
    result=[]
    for family,(friction,load,weight) in enumerate(((0.,.75,.3),(.5,1.,.5),(.9,2.,.8))):
        for strategy in ("drive","rock"):
            for axis_index,axis in enumerate(moment.AXES):
                result.append(moment.profile(dict(id=f"{strategy}{family}_axis{axis_index}",mode=moment.MODE,
                    axis_body=axis,strategy=strategy,friction_ratio=friction,normal_load_ratio=load,
                    moment_weight_length_ratio=weight,pose_distance_weight_m=.025,
                    target_update_steps=6,minimum_hold_steps=30,maximum_hold_steps=180,
                    rate_deadband_rad_s=.05,position_gain_s_inv=10.,maximum_speed_rad_s=3.5,
                    maximum_slew_rad_s_per_step=.2,joint_braking=braking.POLICY)))
    return result


def spec(recipe, *, route=False):
    require(recipe==RECIPE,"Moment frozen recipe")
    original=source("creature_torso_target_v1.json")["righting_spec"]
    recipe_body=source("creature_contact_envelope_v1.json")["body_population"]
    population,_=body_population(original["descriptors"],recipe_body["corner_fields"],
                                recipe_body["generated_seed_start"],recipe_body["generated_count"])
    selected=source("creature_contact_moment_result_v1.json")["geometric_proposal_groups"]["body_indices"]["friction_pitch_every_sample_both"]
    require(all(i in selected for i in RECIPE["body_indices"][:12])
            and all(i not in selected for i in RECIPE["body_indices"][12:]),"Moment inside/outside body strata")
    pool=source("creature_contact_moment_v1.json")["pose_pool"]
    require(moment.POOL==dict(states=pool["limb_states"],**{k:v for k,v in pool.items() if k!="limb_states"}),
            "Moment exposed pose-bank identity")
    result=dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=[population[i]["descriptor"] for i in RECIPE["body_indices"]],
        profiles=copy.deepcopy(original["profiles"][:2])+proposals(),
        conditions=copy.deepcopy(original["conditions"]),starts=copy.deepcopy(original["starts"]),
        profiles_by_body=[[0,1]+sorted(2+(body+3*k)%24 for k in range(8)) for body in range(24)])
    if route:
        result.update(schema_version=righting.SCHEMA,descriptors=[result["descriptors"][RECIPE["route_body_index"]]],
                      profiles=[result["profiles"][i] for i in RECIPE["route_profile_indices"]])
        del result["profiles_by_body"]
    return result


def source_dependencies(c):
    return ([ROOT/"sdk/discovery"/name for name in SOURCES]
            +[ROOT/"sdk/discovery"/name for name in ("creature_body_moment_v1.json","creature_body_moment_route_v1.json")]
            if "body_moment_search" in c else [])


def validate(c):
    opted=any(p["mode"]==moment.MODE for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or any(k in c for k in ("body_moment_search","moment_handoff_search","support_exchange_search","support_sharing_search","torque_map_search")),"Moment requires declared search gate")
    if "body_moment_search" not in c:return
    require(c["body_moment_search"]==RECIPE and c["mode"] in ("route_ghost","development_discovery")
            and c["trajectory_screen"]==trajectory.POLICY
            and not any(k in c for k in ("trajectory_proposal","trajectory_retiming","joint_braking_search",
                                        "contact_reach_search","torso_target_search")),"Moment declaration scope")
    route=c["mode"]=="route_ghost"
    require(c["righting_spec"]==spec(RECIPE,route=route) and c["seed"]==RECIPE["seed"]
            and c["outer_steps"]==(RECIPE["route_outer_steps"] if route else 1440)
            and c["maximum_worlds_per_batch"]==10,"Moment population, clocks or batch drift")


def verify_route(folder, receipt):
    require(receipt["contract"]["mode"]=="route_ghost" and receipt["audit"]["capture"]["controller_replay_verified"]
            and receipt["audit"]["capture"]["within_run_projection_verified"],"Moment requires full route replay")
    counts=dict(rows=0,clear_targets=0,contact_force=0,tangent_force=0,bounded_reversal=0)
    inventory={r["path"]:r for r in receipt.get("artifacts",[])}
    for batch in receipt["audit"]["batches"]:
        relative=f"native/{batch['batch_id']}/controller.jsonl";path=Path(folder)/relative
        if inventory:
            require(path.stat().st_size==inventory[relative]["bytes"]
                    and hashlib.sha256(path.read_bytes()).hexdigest()==inventory[relative]["sha256"],"Moment route stream binding")
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                row=json.loads(line);d=row["resolution"].get("body_moment")
                if d is None:continue
                counts["rows"]+=1;counts["contact_force"]+=bool(d["active_limbs"])
                counts["bounded_reversal"]+=d["selection_reason"]=="bounded_reversal"
                target=d["state_after"]["target"]
                if target is not None:
                    require(target["target_nonadjacent_gap_m"]>=-1e-9,"Moment overlapping target")
                    counts["clear_targets"]+=1
                counts["tangent_force"]+=any(abs(w["force"][0])+abs(w["force"][2])>1e-9 for w in d["requested_wrenches"])
    require(all(counts.values()),"Moment route command-path coverage incomplete")
    return dict(counts=counts,complete=True,recovery_qualified=False)
