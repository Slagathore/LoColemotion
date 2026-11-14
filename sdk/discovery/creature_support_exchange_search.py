"""Factored support-preserving transitions around exposed body-specific references."""
import copy
import hashlib
import json
from pathlib import Path

import creature_body_moment as moment
import creature_moment_handoff_search as parent
import creature_righting as righting
import creature_support_exchange as exchange
import creature_trajectory_search as trajectory
from creature_batch import require

ROOT = parent.ROOT
SOURCES = dict(parent.SOURCES, **{
    "creature_moment_handoff_native_result_v1.json": "19124d130d1819de2a40fc317740f54eb0cad145d0177438acbc6fd2544507fa",
    "creature_moment_handoff_diagnosis_v1.json": "659d4c304f17bc8f8b316f222c2a3973c4df2158526feb7bba2376d1b6430707"})
RECIPE = dict(schema_version="locolemotion_support_exchange_search_v1", seed=1061139,
    body_indices=parent.RECIPE["body_indices"], route_body_index=16, route_outer_steps=720,
    limb_relations=["opposite_side","other_end","diagonal"], mass_shift_weights=[0.,.5,1.],
    stall_steps=[36,72], route_recipe_indices=[0,4,2,9,7,11,12,16,14],
    body_blocks=[[1,10,2,5,13,16,19,22],[8,11,0,6,14,17,20,23],[3,9,4,7,12,15,18,21]])
PATH_SCREEN = copy.deepcopy(parent.PATH_SCREEN)
FAMILIES = dict(opposite_side="opposite", other_end="sameend", diagonal="diagonal")


def recipes():
    return [dict(exchange.DEFAULT_POLICY, limb_relation=limb, mass_shift_weight=weight, stall_steps=stall)
            for weight in RECIPE["mass_shift_weights"] for stall in RECIPE["stall_steps"]
            for limb in RECIPE["limb_relations"]]


def assignments():
    """Each body gets six recipes; every recipe crosses four bodies per stratum."""
    rows=[[] for _ in range(24)]
    for mass in range(3):
        for stall in range(2):
            for limb in range(3):
                index=limb+3*(stall+2*mass)
                # Keep each exposed reference in one block. This avoids redundant
                # profiles while retaining all 18 recipes, both strata and 216 worlds.
                for body in RECIPE["body_blocks"][(limb+2*stall+mass)%3]:
                    rows[body].append(index)
    return [sorted(row) for row in rows]


def proposal(reference, recipe_index):
    selected=recipes()[recipe_index]
    profile=copy.deepcopy(reference)
    profile.update(id=f"{FAMILIES[selected['limb_relation']]}_{reference['id']}_r{recipe_index:02d}",
                   support_exchange=selected)
    return moment.profile(profile)


def reference_indices(*, route=False):
    if route:return [2]
    refs=parent.references();used=sorted({r["candidate_index"] for r in refs})
    return [2+used.index(r["candidate_index"]) for r in refs]


def spec(*, route=False):
    result=parent.parent.spec(parent.parent.RECIPE)
    refs=parent.references()
    if route:
        body=RECIPE["route_body_index"]
        reference=result["profiles"][refs[body]["candidate_index"]]
        result.update(schema_version=righting.SCHEMA,descriptors=[result["descriptors"][body]],
            profiles=result["profiles"][:2]+[reference]
                +[proposal(reference,i) for i in RECIPE["route_recipe_indices"]])
        del result["profiles_by_body"]
    else:
        old=result["profiles"]
        used=[0,1]+sorted({r["candidate_index"] for r in refs})
        rows=assignments()
        pairs=sorted({(ref["candidate_index"],i) for ref,row in zip(refs,rows,strict=True) for i in row})
        indices={pair:len(used)+i for i,pair in enumerate(pairs)}
        result["profiles"]=[old[i] for i in used]+[proposal(old[ref],i) for ref,i in pairs]
        result["profiles_by_body"]=[[0,1,ref]+[indices[(choice["candidate_index"],i)] for i in row]
            for ref,choice,row in zip(reference_indices(),refs,rows,strict=True)]
    return result


def source_dependencies(c):
    return ([ROOT/"sdk/discovery"/name for name in SOURCES]
        +[ROOT/"sdk/discovery"/name for name in (
            "creature_body_moment_v1.json","creature_body_moment_route_v1.json",
            "creature_moment_handoff_v1.json","creature_moment_handoff_route_v1.json",
            "creature_support_exchange_v1.json","creature_support_exchange_route_v1.json")]
        if "support_exchange_search" in c else [])


def validate(c):
    opted=any("support_exchange" in p for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or any(k in c for k in ("support_exchange_search","support_sharing_search")),"Exchange requires declared search")
    if "support_exchange_search" not in c:return
    for name,digest in SOURCES.items():
        require(hashlib.sha256((ROOT/"sdk/discovery"/name).read_bytes()).hexdigest()==digest,
                "Exchange predecessor binding")
    route=c["mode"]=="route_ghost"
    refs=c["trajectory_reference_by_body"]
    require(type(refs) is list and all(type(v) is int for v in refs)
        and c["support_exchange_search"]==RECIPE and c["mode"] in ("route_ghost","development_discovery")
        and c["righting_spec"]==spec(route=route) and refs==reference_indices(route=route)
        and c["reference_selection"]==parent.references()
        and c["trajectory_screen"]==trajectory.POLICY and c["post_native_path_screen"]==PATH_SCREEN
        and c["seed"]==RECIPE["seed"] and c["outer_steps"]==(RECIPE["route_outer_steps"] if route else 1440)
        and c["maximum_worlds_per_batch"]==12
        and not any(k in c for k in ("moment_handoff_search","body_moment_search","trajectory_proposal",
            "trajectory_retiming","joint_braking_search","contact_reach_search","torso_target_search")),
        "Exchange population, references, clocks or scope")


def verify_route(folder, receipt):
    """Require observed branch coverage in the fully replayed production stream."""
    require(receipt["contract"]["mode"]=="route_ghost"
        and receipt["contract"]["support_exchange_search"]==RECIPE
        and receipt["audit"]["capture"]["controller_replay_verified"]
        and receipt["audit"]["capture"]["within_run_projection_verified"],"Exchange full route required")
    counts=dict(rows=0,supported_seek=0,measured_replacement_contact=0,transfer=0,no_replacement_fallback=0)
    inventory={r["path"]:r for r in receipt.get("artifacts",[])}
    for batch in receipt["audit"]["batches"]:
        name=f"native/{batch['batch_id']}/controller.jsonl";path=Path(folder)/name
        if inventory:
            require(path.stat().st_size==inventory[name]["bytes"]
                and hashlib.sha256(path.read_bytes()).hexdigest()==inventory[name]["sha256"],
                "Exchange route stream binding")
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                row=json.loads(line);d=row["resolution"].get("body_moment",{});e=d.get("support_exchange")
                if e is None:continue
                counts["rows"]+=1
                after=d["state_after"]
                require(e["phase"]==after["phase"] and e["forces_are_measured"] is False
                    and e["recovery_benefit_established"] is False,"Exchange diagnostic scope")
                if e["phase"] in ("seek","transfer"):
                    old,limb=after["support_limbs"],after["replacement_limb"]
                    expected=old if e["phase"]=="seek" else old[1:]+[limb]
                    contacts=row["request"]["state"]["ordered_contact_observations"]
                    require(old and limb not in old and d["active_limbs"]==expected
                        and all(contacts[i]["presence"] for i in expected)
                        and len(d["requested_wrenches"])==len(expected)
                        and after["target"]["endpoint_nonadjacent_gap_m"]>=-1e-9,
                        "Exchange support retention or target")
                    if e["phase"]=="seek":
                        counts["supported_seek"]+=1
                    else:
                        counts["transfer"]+=1
                        require(after["contact_count"]>=exchange.DEFAULT_POLICY["contact_dwell_steps"],
                                "Exchange transfer before dwell")
                if e["reason"]=="measured_replacement_contact":
                    require(e["phase"]=="transfer" and d["state_before"]["phase"]=="seek"
                        and d["state_before"]["contact_count"]+1==after["contact_count"],
                        "Exchange contact acquisition")
                    counts["measured_replacement_contact"]+=1
                if e["reason"] in ("no_clear_replacement_pose","replacement_timeout"):
                    require(e["phase"]=="reference"
                        and after["cooldown"]==exchange.DEFAULT_POLICY["retry_steps"],"Exchange unbounded fallback")
                    counts["no_replacement_fallback"]+=1
    require(all(counts.values()),"Exchange route coverage incomplete")
    return dict(counts=counts,complete=True,recovery_qualified=False)
