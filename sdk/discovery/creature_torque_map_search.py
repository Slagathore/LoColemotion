"""Balanced torque-map recipes across exposed bodies with fresh comparators."""
import copy
import hashlib
import itertools
import json
from pathlib import Path

import creature_body_moment as moment
import creature_righting as righting
import creature_support_sharing_search as parent
import creature_torque_map as controller
import creature_trajectory_search as trajectory
from creature_batch import require

ROOT = parent.ROOT
SOURCES = dict(parent.SOURCES, **{
    "creature_support_sharing_native_result_v1.json":"c61f9ad7f2ef7aa03488f739029984ecf7f812ad6ef03df4284a8ad4b0cc409e",
    "creature_support_sharing_diagnosis_v1.json":"3aff52a15b7c0bf53375be4171d4369698e0956c696f97d15573b0eeba07b36e"})
RECIPE = dict(schema_version="locolemotion_torque_map_search_v1", seed=1061141,
    body_indices=parent.RECIPE["body_indices"], route_body_indices=[0,16], route_outer_steps=360,
    pose_scores=["visible_arm","bounded_moment"], normalizations=["moment","load"],
    contact_sets=["primary","all"], assignment="omit_complementary_pair_by_body_modulo_four",
    sharing_reference_rule="highest_exposed_reference_gain_per_body_then_lowest_index")
RECIPE_V2 = dict(RECIPE, schema_version="locolemotion_torque_map_search_v2")
V2_SOURCES = {
    "creature_torque_map_native_failure_v1.json":"cc988e71fe8c49ba4b0b96d0c8154efcc57c90c4fbbb2c2417a08e081d25759c",
    "creature_torque_map_numerical_witnesses_v1.json":"0559cfa995bd3d6bf50de43118431668554d6ed5accec82fef0ca146e4d37c40"}
PATH_SCREEN = copy.deepcopy(parent.PATH_SCREEN)


def stable(c):
    return c.get("torque_map_search", {}).get("schema_version") == RECIPE_V2["schema_version"]


def recipes(*, stable_basis=False):
    return [dict(controller.STABLE_POLICY if stable_basis else controller.DEFAULT_POLICY,
                 pose_score=s, normalization=n, contact_set=c)
            for s,n,c in itertools.product(RECIPE["pose_scores"], RECIPE["normalizations"], RECIPE["contact_sets"])]


def assignments():
    return [[i for i in range(8) if i not in (body%4, 7-body%4)] for body in range(24)]


def sharing_references():
    raw=(ROOT/"sdk/discovery/creature_support_sharing_native_result_v1.json").read_bytes()
    require(hashlib.sha256(raw).hexdigest()==SOURCES["creature_support_sharing_native_result_v1.json"],
            "Torque-map sharing comparator binding")
    old=parent.spec();outcomes=json.loads(raw)["outcomes"]["all_outcomes"];result=[]
    for body in range(24):
        rows=[r for r in outcomes if r["body_index"]==body
              and "support_sharing" in old["profiles"][r["candidate_index"]]]
        require(len(rows)==4 and all(not r["eligible"] and r["joint_limit_violation_steps"]==0 for r in rows),
                "Torque-map exposed sharing population")
        row=max(rows,key=lambda r:(r["peak_gain_against_reference_degrees"],-r["candidate_index"]))
        result.append(dict(body_index=body,candidate_index=row["candidate_index"],candidate_id=row["candidate_id"],
                           exposed_reference_gain_degrees=row["peak_gain_against_reference_degrees"]))
    return result


def population(*, route=False, stable_basis=False):
    old=parent.spec();old_refs=parent.reference_indices();sharing=sharing_references()
    bodies=RECIPE["route_body_indices"] if route else list(range(24))
    refs=sorted({old_refs[b] for b in bodies});failed=sorted({sharing[b]["candidate_index"] for b in bodies})
    rows=[list(range(8)) if route else assignments()[b] for b in bodies]
    pairs=sorted({(old_refs[b],i) for b,row in zip(bodies,rows,strict=True) for i in row})
    profiles=[copy.deepcopy(old["profiles"][i]) for i in [0,1]+refs+failed]
    offset=len(profiles);indices={pair:offset+i for i,pair in enumerate(pairs)}
    for ref,index in pairs:
        p=copy.deepcopy(old["profiles"][ref])
        p.update(id=f"cone{index}_{p['id']}",torque_map=recipes(stable_basis=stable_basis)[index]);profiles.append(moment.profile(p))
    references=[2+refs.index(old_refs[b]) for b in bodies]
    spec=dict(schema_version=righting.ASSIGNED_SCHEMA,descriptors=[old["descriptors"][b] for b in bodies],
        profiles=profiles,conditions=old["conditions"],starts=old["starts"],
        profiles_by_body=[[0,1,r,2+len(refs)+failed.index(sharing[b]["candidate_index"])]
            +[indices[(old_refs[b],i)] for i in row]
            for b,row,r in zip(bodies,rows,references,strict=True)])
    return spec,references


def source_dependencies(c):
    if "torque_map_search" not in c:return []
    extra = [*V2_SOURCES, "creature_torque_map_v2.json", "creature_torque_map_route_v2.json"] if stable(c) else []
    return list(dict.fromkeys(parent.source_dependencies({"support_sharing_search":parent.RECIPE})
        +[ROOT/"sdk/discovery"/name for name in [*SOURCES, *extra]]
        +[ROOT/"sdk/discovery"/name for name in ("creature_torque_map_v1.json","creature_torque_map_route_v1.json")]))


def validate(c):
    opted=any("torque_map" in p for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or "torque_map_search" in c,"Torque-map requires declared search")
    if "torque_map_search" not in c:return
    sources = dict(SOURCES, **V2_SOURCES) if stable(c) else SOURCES
    for name,digest in sources.items():
        require(hashlib.sha256((ROOT/"sdk/discovery"/name).read_bytes()).hexdigest()==digest,"Torque-map predecessor binding")
    route=c["mode"]=="route_ghost";spec,refs=population(route=route, stable_basis=stable(c))
    require(c["mode"] in ("route_ghost","development_discovery") and c["torque_map_search"]==(RECIPE_V2 if stable(c) else RECIPE)
        and c["righting_spec"]==spec and c["trajectory_reference_by_body"]==refs
        and all(type(x) is int for x in c["trajectory_reference_by_body"])
        and c["reference_selection"]==parent.parent.parent.references()
        and c["sharing_reference_selection"]==sharing_references()
        and c["trajectory_screen"]==trajectory.POLICY and c["post_native_path_screen"]==PATH_SCREEN
        and c["seed"]==RECIPE["seed"] and c["outer_steps"]==(RECIPE["route_outer_steps"] if route else 1440)
        and c["maximum_worlds_per_batch"]==12
        and not any(k in c for k in ("support_sharing_search","support_exchange_search","moment_handoff_search",
            "body_moment_search","trajectory_proposal","trajectory_retiming","joint_braking_search",
            "contact_reach_search","torso_target_search")),"Torque-map population, references, bounds or scope")
    if stable(c):
        require(c["predecessor"] == dict(path="sdk/discovery/creature_torque_map_native_failure_v1.json",
            sha256=V2_SOURCES["creature_torque_map_native_failure_v1.json"]), "Torque-map numerical predecessor")


def verify_route(folder,receipt):
    c=receipt["contract"]
    require(c["mode"]=="route_ghost" and c["torque_map_search"]==(RECIPE_V2 if stable(c) else RECIPE)
        and receipt["audit"]["capture"]["controller_replay_verified"]
        and receipt["audit"]["capture"]["within_run_projection_verified"],"Torque-map full route required")
    expected={m["cell_id"] for m in c["righting_metadata"]
              if "torque_map" in c["righting_spec"]["profiles"][m["candidate_index"]]}
    seen={name:dict(rows=0,force=0,target=0) for name in expected}
    counts=dict(quiet_contact_rows=0,coordinated_contact_rows=0,no_force_rows=0)
    inventory={r["path"]:r for r in receipt.get("artifacts",[])}
    for batch in receipt["audit"]["batches"]:
        name=f"native/{batch['batch_id']}/controller.jsonl";path=Path(folder)/name
        if inventory:
            require(path.stat().st_size==inventory[name]["bytes"]
                and hashlib.sha256(path.read_bytes()).hexdigest()==inventory[name]["sha256"],"Torque-map route binding")
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                row=json.loads(line);d=row["resolution"].get("body_moment",{});info=d.get("torque_map")
                if info is None:continue
                cell=row["binding"]["cell_id"];require(cell in seen,"Torque-map route cell identity")
                require(row["outer_step"]==seen[cell]["rows"],"Torque-map route row order")
                seen[cell]["rows"]+=1
                require(all(info[k] is False for k in ("forces_are_measured","torso_reactions_modeled","recovery_benefit_established")),
                        "Torque-map route scope")
                target=d["state_after"]["target"]
                if target is not None and target.get("torque_map_target"):
                    require(target["target_nonadjacent_gap_m"]>=-1e-9,"Torque-map target clearance")
                    seen[cell]["target"]+=1
                if info["reason"]=="upright_stance":continue
                present=[i for i,v in enumerate(row["request"]["state"]["ordered_contact_observations"]) if v["presence"]]
                require(info["measured_contact_limbs"]==present and info["active_limbs"]==d["active_limbs"]
                    and sorted(info["active_limbs"]+info["quiet_limbs"])==present
                    and set(info["active_limbs"]).isdisjoint(info["quiet_limbs"]),"Torque-map contact accounting")
                require(info["policy"]["contact_set"]!="primary" or len(d["active_limbs"])<=1,"Torque-map primary population")
                for limb in d["active_limbs"]:
                    for j in (2*limb,2*limb+1):
                        require(abs(d["force_projection"]["requested_torque"][j]-d["post_guard_predicted_torque_nm"][j])<=1e-8,
                                "Torque-map native guarded request")
                for limb in info["quiet_limbs"]:
                    require(all(d["force_projection"]["requested_torque"][j]==0. for j in (2*limb,2*limb+1)),
                            "Torque-map quiet request")
                seen[cell]["force"]+=bool(d["active_limbs"])
                counts["quiet_contact_rows"]+=bool(info["quiet_limbs"])
                counts["coordinated_contact_rows"]+=len(d["active_limbs"])>1
                counts["no_force_rows"]+=not d["active_limbs"]
    require(expected and all(v["rows"]==c["outer_steps"] and v["force"] and v["target"] for v in seen.values())
            and all(counts.values()),"Torque-map route coverage incomplete")
    return dict(cells=seen,counts=counts,complete=True,recovery_qualified=False)
