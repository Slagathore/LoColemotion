"""Paired braking intervention on the exposed, diverse slow-trajectory cohort."""
import copy
import hashlib
import json

from creature_batch import require
import creature_joint_braking as braking
import creature_righting as righting
import creature_trajectory_retiming as retiming
import creature_trajectory_search as trajectory

SOURCE = dict(path="sdk/discovery/creature_trajectory_retiming_v1.json",
              sha256="7d4de2274324d4ec212cae0e9255190c961a537db32ca851958f75099ef566d1")
POLICY = dict(schema_version=braking.SCHEMA, margin_rad=.025, lookahead_steps=2,
              braking_acceleration_rad_s2=6.)
RECIPE = dict(schema_version="locolemotion_paired_joint_braking_v1", seed=1061123,
              source_contract=SOURCE, policy=POLICY, route_body_index=1, route_outer_steps=90)


def source():
    raw = (retiming.ROOT / SOURCE["path"]).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == SOURCE["sha256"], "Braking exposed source binding")
    return json.loads(raw)["righting_spec"]


def source_dependencies(c):
    return ([retiming.ROOT / retiming.SOURCE["path"], retiming.ROOT / SOURCE["path"],
             retiming.ROOT / "sdk/discovery/creature_joint_braking_v1.json",
             retiming.ROOT / "sdk/discovery/creature_joint_braking_route_v1.json"]
            if any(k in c for k in ("joint_braking_search", "contact_reach_search")) else [])


def spec(recipe, *, route=False):
    require(recipe == RECIPE, "Braking frozen recipe")
    original = source()
    profiles = copy.deepcopy(original["profiles"][:2])
    for p in original["profiles"][3::2]:
        require(p["id"].endswith("_slow3") and "joint_braking" not in p, "Braking source variant")
        baseline = copy.deepcopy(p)
        baseline["id"] += "_unbraked"
        guarded = copy.deepcopy(p)
        guarded.update(id=p["id"] + "_braked", joint_braking=copy.deepcopy(recipe["policy"]))
        profiles.extend([righting.profile(baseline), righting.profile(guarded)])
    result = copy.deepcopy(original)
    result["profiles"] = profiles
    if route:
        index = recipe["route_body_index"]
        result.update(schema_version=righting.SCHEMA, descriptors=[result["descriptors"][index]],
            profiles=[profiles[i] for i in result["profiles_by_body"][index]])
        del result["profiles_by_body"]
    return result


def validate(c):
    opted_in = any("joint_braking" in p for p in c.get("righting_spec", {}).get("profiles", []))
    require(not opted_in or any(k in c for k in ("joint_braking_search", "contact_reach_search")), "Braking requires its declared search gate")
    if "joint_braking_search" not in c:
        return
    require(c["joint_braking_search"] == RECIPE and c["mode"] in ("route_ghost", "development_discovery")
            and not any(k in c for k in ("trajectory_proposal", "trajectory_retiming"))
            and c["trajectory_screen"] == trajectory.POLICY, "Braking declaration scope")
    route = c["mode"] == "route_ghost"
    require(c["righting_spec"] == spec(RECIPE, route=route)
            and c["outer_steps"] == (RECIPE["route_outer_steps"] if route else 1440)
            and c["maximum_worlds_per_batch"] == 14 and c["seed"] == RECIPE["seed"],
            "Braking paired population, horizon or batch drift")
