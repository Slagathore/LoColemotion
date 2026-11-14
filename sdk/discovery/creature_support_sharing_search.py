"""Factored force-aware support sharing with fresh exposed comparators."""
import copy
import hashlib
import json
from pathlib import Path

import creature_body_moment as moment
import creature_support_exchange_search as parent
import creature_support_sharing as sharing
import creature_righting as righting
import creature_trajectory_search as trajectory
from creature_batch import require

ROOT = parent.ROOT
SOURCES = dict(parent.SOURCES, **{
    "creature_support_exchange_native_result_v1.json": "85a98ca3def2c6b9f4ba35b0ad61ceab04510815659580106b5f40b056f5e4c3",
    "creature_support_exchange_diagnosis_v1.json": "6b30d95c81e3f60ab6ca17e96a3f0fdc4a1308bcf3b49638f367af47142f7233"})
RECIPE = dict(schema_version="locolemotion_support_sharing_search_v1", seed=1061140,
    body_indices=parent.RECIPE["body_indices"], body_blocks=parent.RECIPE["body_blocks"],
    route_body_index=16, route_outer_steps=720, route_recipe_indices=[0,1,2,3,6,7,9,11],
    limb_relations=["opposite_side","other_end","diagonal"], torque_reserve_weights=[0.,.5],
    ramp_steps=[24,60], failed_reference_rule="mean_reference_gain_within_exposed_reference_group")
PATH_SCREEN = copy.deepcopy(parent.PATH_SCREEN)


def recipes():
    return [dict(sharing.DEFAULT_POLICY, limb_relation=limb, torque_reserve_weight=weight,
                 load_steps=ramp, unload_steps=ramp)
            for weight in RECIPE["torque_reserve_weights"] for ramp in RECIPE["ramp_steps"]
            for limb in RECIPE["limb_relations"]]


def assignments():
    rows = [[] for _ in range(24)]
    for weight in range(2):
        for ramp in range(2):
            for limb in range(3):
                index = limb+3*(ramp+2*weight)
                for body in RECIPE["body_blocks"][(limb+2*ramp+weight)%3]:
                    rows[body].append(index)
    return [sorted(row) for row in rows]


def failed_references():
    """One previously failed exchange per reference group, selected on exposed data."""
    path = ROOT/"sdk/discovery/creature_support_exchange_native_result_v1.json"
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == SOURCES[path.name], "Sharing failed comparator binding")
    outcomes = json.loads(raw)["outcomes"]["all_outcomes"]
    old = parent.spec()
    refs = parent.parent.references()
    chosen = {}
    for ref in sorted({v["candidate_id"] for v in refs}):
        bodies = [i for i,r in enumerate(refs) if r["candidate_id"] == ref]
        candidates = set.intersection(*(set(old["profiles_by_body"][b][3:]) for b in bodies))
        require(candidates, "Sharing common failed comparator")
        scores = {}
        for candidate in sorted(candidates):
            rows = [r for r in outcomes if r["body_index"] in bodies and r["candidate_index"] == candidate]
            require(len(rows) == len(bodies) and all(not r["eligible"] and r["joint_limit_violation_steps"] == 0 for r in rows),
                    "Sharing exposed failed comparator population")
            scores[candidate] = sum(r["peak_gain_against_reference_degrees"] for r in rows)/len(rows)
        index = max(scores, key=lambda i:(scores[i], -i))
        chosen[ref] = dict(candidate_index=index, candidate_id=old["profiles"][index]["id"],
            exposed_mean_reference_gain_degrees=scores[index], exposed_body_indices=bodies)
    return [dict(body_index=i, reference_candidate_id=r["candidate_id"], **chosen[r["candidate_id"]]) for i,r in enumerate(refs)]


def proposal(reference, index):
    recipe = recipes()[index]
    p = copy.deepcopy(reference)
    p.update(id=f"{parent.FAMILIES[recipe['limb_relation']]}_shared_{reference['id']}_r{index:02d}", support_sharing=recipe)
    return moment.profile(p)


def reference_indices(*, route=False):
    if route:return [2]
    refs = parent.parent.references();used = sorted({r["candidate_index"] for r in refs})
    return [2+used.index(r["candidate_index"]) for r in refs]


def spec(*, route=False):
    base = parent.parent.parent.spec(parent.parent.parent.RECIPE)
    refs, failed = parent.parent.references(), failed_references()
    old_exchange = parent.spec()["profiles"]
    if route:
        body = RECIPE["route_body_index"]
        reference = base["profiles"][refs[body]["candidate_index"]]
        base.update(schema_version=righting.SCHEMA, descriptors=[base["descriptors"][body]],
            profiles=base["profiles"][:2]+[reference,old_exchange[failed[body]["candidate_index"]]]
                +[proposal(reference,i) for i in RECIPE["route_recipe_indices"]])
        del base["profiles_by_body"]
    else:
        old = base["profiles"];used = [0,1]+sorted({r["candidate_index"] for r in refs})
        failed_indices = sorted({r["candidate_index"] for r in failed})
        rows = assignments()
        pairs = sorted({(ref["candidate_index"],i) for ref,row in zip(refs,rows,strict=True) for i in row})
        offset = len(used)+len(failed_indices)
        indices = {pair:offset+i for i,pair in enumerate(pairs)}
        base["profiles"] = [old[i] for i in used]+[old_exchange[i] for i in failed_indices]+[proposal(old[ref],i) for ref,i in pairs]
        base["profiles_by_body"] = [[0,1,reference,len(used)+failed_indices.index(f["candidate_index"])]
            +[indices[(r["candidate_index"],i)] for i in row]
            for reference,f,r,row in zip(reference_indices(),failed,refs,rows,strict=True)]
    return base


def source_dependencies(c):
    return ([ROOT/"sdk/discovery"/name for name in SOURCES]
        +[ROOT/"sdk/discovery"/name for name in ("creature_body_moment_v1.json","creature_body_moment_route_v1.json",
            "creature_moment_handoff_v1.json","creature_moment_handoff_route_v1.json",
            "creature_support_exchange_v1.json","creature_support_exchange_route_v1.json",
            "creature_support_sharing_v1.json","creature_support_sharing_route_v1.json")]
        if "support_sharing_search" in c else [])


def validate(c):
    opted = any("support_sharing" in p for p in c.get("righting_spec",{}).get("profiles",[]))
    require(not opted or "support_sharing_search" in c, "Sharing requires declared search")
    if "support_sharing_search" not in c:return
    for name,digest in SOURCES.items():
        require(hashlib.sha256((ROOT/"sdk/discovery"/name).read_bytes()).hexdigest()==digest, "Sharing predecessor binding")
    route = c["mode"] == "route_ghost"
    require(c["support_sharing_search"] == RECIPE and c["mode"] in ("route_ghost","development_discovery")
        and c["righting_spec"] == spec(route=route)
        and c["trajectory_reference_by_body"] == reference_indices(route=route)
        and all(type(x) is int for x in c["trajectory_reference_by_body"])
        and c["reference_selection"] == parent.parent.references()
        and c["failed_exchange_reference_selection"] == failed_references()
        and c["trajectory_screen"] == trajectory.POLICY and c["post_native_path_screen"] == PATH_SCREEN
        and c["seed"] == RECIPE["seed"] and c["outer_steps"] == (720 if route else 1440)
        and c["maximum_worlds_per_batch"] == 12
        and not any(k in c for k in ("support_exchange_search","moment_handoff_search","body_moment_search",
            "trajectory_proposal","trajectory_retiming","joint_braking_search","contact_reach_search","torso_target_search")),
        "Sharing population, references, clocks or scope")


def verify_route(folder, receipt):
    require(receipt["contract"]["mode"] == "route_ghost"
        and receipt["contract"]["support_sharing_search"] == RECIPE
        and receipt["audit"]["capture"]["controller_replay_verified"]
        and receipt["audit"]["capture"]["within_run_projection_verified"], "Sharing full route required")
    counts = dict(rows=0,supported_seek=0,measured_replacement_contact=0,retained_support_loading=0,
                  staged_unloading=0,bounded_fallback=0)
    inventory = {r["path"]:r for r in receipt.get("artifacts",[])}
    for batch in receipt["audit"]["batches"]:
        name=f"native/{batch['batch_id']}/controller.jsonl";path=Path(folder)/name
        if inventory:
            require(path.stat().st_size==inventory[name]["bytes"]
                and hashlib.sha256(path.read_bytes()).hexdigest()==inventory[name]["sha256"], "Sharing route stream binding")
        with path.open(encoding="utf-8") as stream:
            for line in stream:
                row=json.loads(line);d=row["resolution"].get("body_moment",{});e=d.get("support_sharing")
                if e is None:continue
                counts["rows"] += 1
                after=d["state_after"];phase=e["phase"]
                require(phase==after["phase"] and e["forces_are_measured"] is False
                        and e["recovery_benefit_established"] is False, "Sharing scope")
                if phase != "reference":
                    old,limb=after["support_limbs"],after["replacement_limb"]
                    expected=old if phase=="seek" else old[1:]+[limb] if phase=="transfer" else old+[limb]
                    contacts=row["request"]["state"]["ordered_contact_observations"]
                    require(old and limb not in old and d["active_limbs"]==expected
                        and all(contacts[i]["presence"] for i in expected)
                        and after["target"]["endpoint_nonadjacent_gap_m"]>=-1e-9, "Sharing support retention")
                    js=[j for i in expected for j in (2*i,2*i+1)]
                    require(all(abs(d["force_projection"]["requested_torque"][j]-d["post_guard_predicted_torque_nm"][j])<=1e-8 for j in js),
                            "Sharing resolved torque bounds")
                    if phase=="seek":counts["supported_seek"]+=1
                    if phase=="load":
                        counts["retained_support_loading"]+=1
                        require(next(v for v in d["sharing_requests"] if v["limb"]==old[0])["requested_weight"]==1.,
                                "Sharing removed old request during loading")
                    if phase=="unload" and after["unload_fraction"]>0.:
                        counts["staged_unloading"]+=1
                    if phase in ("load","unload","transfer"):
                        require(after["contact_count"]>=sharing.DEFAULT_POLICY["contact_dwell_steps"], "Sharing before contact dwell")
                if e["reason"]=="measured_replacement_contact":
                    require(phase=="load" and d["state_before"]["phase"]=="seek", "Sharing measured acquisition")
                    counts["measured_replacement_contact"]+=1
                if e["reason"] in ("no_clear_force_bounded_pose","no_guarded_force_interval",
                    "replacement_timeout","load_response_timeout","unload_response_timeout","lost_required_contact"):
                    require(phase=="reference" and after["cooldown"]==sharing.DEFAULT_POLICY["retry_steps"], "Sharing unbounded fallback")
                    counts["bounded_fallback"]+=1
    require(all(counts.values()), "Sharing route coverage incomplete")
    return dict(counts=counts,complete=True,recovery_qualified=False)
