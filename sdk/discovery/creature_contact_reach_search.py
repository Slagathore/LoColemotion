"""Bounded body-aware contact strategies on sixteen exposed creature shapes."""
import copy
import hashlib
import json
from pathlib import Path

from creature_batch import require
import creature_contact_reach as contact
import creature_joint_braking_search as braking
import creature_righting as righting
import creature_trajectory_search as trajectory

ROOT = Path(__file__).resolve().parents[2]
SOURCE = dict(path="sdk/discovery/creature_joint_braking_v1.json", sha256="b4e62a80bc9c13f0895f7606a8f21f960f18cd7b11bf7ad9e6d4a52bf318797c")
RECIPE = dict(schema_version="locolemotion_contact_reach_search_v1", seed=1061124,
    source_contract=SOURCE, route_body_index=1, route_outer_steps=360,
    ground_height_m=0., candidates_per_family=8, assignment_offsets=[0, 4, 8, 12])


def source():
    raw = (ROOT / SOURCE["path"]).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == SOURCE["sha256"], "Contact-reach exposed source binding")
    return json.loads(raw)["righting_spec"]


def proposals():
    result = []
    for fi, strategy in enumerate(contact.STRATEGIES):
        for v in range(8):
            # Inactive limbs retain these real rest/counter poses. Active limb
            # targets come from body geometry and measured contact.
            rest = [(.15 if (i//2+v) % 2 == 0 else -.15) for i in range(8)]
            counter = [(.4 if (i//2+v) % 2 == 0 else -.4) for i in range(8)]
            p = dict(id=f"{strategy}_{v:02d}", mode=contact.MODE, strategy=strategy,
                axis_body=([1.,0.,0.], [-1.,0.,0.], [0.,0.,1.], [0.,0.,-1.])[v % 4],
                bend_pattern="outward" if v < 4 else "inward", active_limb_count=1 if v % 3 == 2 else 2,
                push_depth_m=.015 if v % 2 == 0 else .04,
                sweep_fraction=(.15 if v % 2 == 0 else .3) if strategy == "sweep" else 0.,
                reach_timeout_steps=120, push_steps=120 if v % 2 == 0 else 180,
                reset_steps=30, target_update_steps=6, pose_a=rest, pose_b=counter,
                position_gain_s_inv=8. if v % 2 == 0 else 10., maximum_speed_rad_s=3.5,
                maximum_slew_rad_s_per_step=.2, joint_braking=copy.deepcopy(braking.POLICY))
            result.append(contact.profile(p))
    return result


def assignments():
    rows = [[0,1] for _ in range(16)]
    for i in range(24):
        family, variant = divmod(i, 8)
        for offset in RECIPE["assignment_offsets"]:
            rows[(variant+family+offset) % 16].append(i+2)
    return [sorted(row) for row in rows]


def spec(recipe, *, route=False):
    require(recipe == RECIPE, "Contact-reach frozen recipe")
    result = copy.deepcopy(source())
    result.update(profiles=result["profiles"][:2]+proposals(), profiles_by_body=assignments())
    if route:
        index = recipe["route_body_index"]
        result.update(schema_version=righting.SCHEMA, descriptors=[result["descriptors"][index]],
            profiles=[result["profiles"][i] for i in result["profiles_by_body"][index]])
        del result["profiles_by_body"]
    return result


def source_dependencies(c):
    return ([ROOT / SOURCE["path"], ROOT / "sdk/discovery/creature_contact_reach_v1.json",
             ROOT / "sdk/discovery/creature_contact_reach_route_v1.json"]
            if "contact_reach_search" in c else [])


def validate(c):
    opted_in = any(p["mode"] == contact.MODE for p in c.get("righting_spec", {}).get("profiles", []))
    require(not opted_in or "contact_reach_search" in c, "Contact-reach requires its declared search gate")
    if "contact_reach_search" not in c:
        return
    require(c["contact_reach_search"] == RECIPE and c["mode"] in ("route_ghost", "development_discovery")
            and not any(k in c for k in ("trajectory_proposal", "trajectory_retiming", "joint_braking_search"))
            and c["trajectory_screen"] == trajectory.POLICY, "Contact-reach declaration scope")
    route = c["mode"] == "route_ghost"
    require(c["righting_spec"] == spec(RECIPE, route=route)
            and c["outer_steps"] == (RECIPE["route_outer_steps"] if route else 1440)
            and c["maximum_worlds_per_batch"] == 8 and c["seed"] == RECIPE["seed"],
            "Contact-reach population, horizon or batch drift")


def route_report(rows, profiles):
    """Require observed production branches; successful locomotion is separate."""
    by_id = {p["id"]:p for p in profiles}
    counts = {s:dict(rows=0, measured_contact=0, bounded_push=0, new_cycle=0,
                    retained_anchor=0, displaced_anchor=0) for s in contact.STRATEGIES}
    for row in rows:
        p = by_id[row["binding"]["candidate_id"]]
        if p["mode"] != contact.MODE:
            continue
        d = row["resolution"]["contact_reach"]
        count = counts[p["strategy"]]; count["rows"] += 1
        reason = d["selection_reason"]
        if reason in ("measured_contact", "bounded_push", "new_cycle"): count[reason] += 1
        if p["strategy"] != "ground" and d["phase"] == "push":
            before, after = d["state_before"], d["state_after"]
            for i in after["active_limbs"]:
                anchor = after["anchors"][i]
                if anchor is not None and before["anchors"][i] == anchor:
                    count["retained_anchor"] += 1
                    choice = after["choices"][i]
                    target = choice["desired_anchor_world_m"] if choice else None
                    if target and any(abs(target[k]-anchor[k]) > 1e-8 for k in (0,2)):
                        count["displaced_anchor"] += 1
    require(all(v["rows"] and v["measured_contact"] and v["bounded_push"] and v["new_cycle"]
                for v in counts.values()), "Contact route phase coverage incomplete")
    require(all(counts[s]["retained_anchor"] for s in ("anchor","sweep"))
            and counts["sweep"]["displaced_anchor"], "Contact route anchor coverage incomplete")
    return dict(strategy_counts=counts, complete=True, recovery_qualified=False)


def verify_route(folder, receipt):
    require(receipt["contract"]["mode"] == "route_ghost" and receipt["audit"]["capture"]["controller_replay_verified"]
            and receipt["audit"]["capture"]["within_run_projection_verified"], "Contact route full replay required")
    paths = [Path(folder)/"native"/g["batch_id"]/"controller.jsonl" for g in receipt["audit"]["batches"]]
    if "artifacts" in receipt:
        inventory = {a["path"]:a for a in receipt["artifacts"]}
        for path in paths:
            bound = inventory[path.relative_to(folder).as_posix()]
            require(path.stat().st_size == bound["bytes"]
                    and hashlib.sha256(path.read_bytes()).hexdigest() == bound["sha256"], "Contact route stream binding")
    def rows():
        for path in paths:
            with path.open(encoding="utf-8") as stream:
                for line in stream:
                    yield json.loads(line)
    return route_report(rows(), receipt["contract"]["righting_spec"]["profiles"])
