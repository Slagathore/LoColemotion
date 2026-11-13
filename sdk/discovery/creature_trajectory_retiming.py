"""Paired schedule intervention on exposed poses, with no controller change."""
import copy
import hashlib
import json
from pathlib import Path

from creature_batch import require
import creature_righting as righting
import creature_trajectory_search as trajectory

ROOT = Path(__file__).resolve().parents[2]
SOURCE = dict(path="sdk/discovery/creature_trajectory_search_v1.json",
              sha256="2c4a028543b016be2cdf0c00c3f5994e6cac5dffc991f1d3f2a27fc1a1b062c8")
RECIPE = dict(schema_version="locolemotion_trajectory_retiming_v1", seed=1061122,
    source_contract=SOURCE, body_count=16, multiplier=3, route_body_index=1,
    selected_indices=dict(wave=[0, 1, 2, 3, 4, 5, 6, 11],
                          impulse=[0, 1, 2, 3, 4, 5, 6, 11],
                          waypoint=[0, 1, 2, 3, 4, 6, 11, 13]),
    assignment_offsets=[0, 4, 8, 12])


def source():
    raw = (ROOT / SOURCE["path"]).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == SOURCE["sha256"], "Retiming exposed source binding")
    return json.loads(raw)["righting_spec"]


def source_dependencies(c):
    """Retain data read by recipe expansion and the actual-declaration controls."""
    return ([ROOT / SOURCE["path"], ROOT / "sdk/discovery/creature_trajectory_retiming_v1.json"]
            if "trajectory_retiming" in c else [])


def proposals(recipe):
    require(recipe == RECIPE, "Retiming frozen recipe")
    original = {p["id"]: p for p in source()["profiles"]}
    result = []
    for family, indices in recipe["selected_indices"].items():
        for index in indices:
            base = original[f"{family}_{index:02d}"]
            for suffix, factor in (("original", 1), ("slow3", recipe["multiplier"])):
                p = copy.deepcopy(base)
                p["id"] += "_" + suffix
                for phase in p["phases"]:
                    for field in ("minimum_hold_steps", "maximum_hold_steps"):
                        phase[field] *= factor
                    phase["limb_delay_steps"] = [v * factor for v in phase["limb_delay_steps"]]
                result.append(righting.sequence.profile(p))
    return result


def assignments(recipe):
    require(recipe == RECIPE, "Retiming frozen assignment")
    rows = [[0, 1] for _ in range(16)]
    for pair in range(24):
        for offset in recipe["assignment_offsets"]:
            rows[(pair + offset) % 16].extend([2 + 2 * pair, 3 + 2 * pair])
    return [sorted(row) for row in rows]


def spec(recipe, *, route=False):
    base = source()
    profiles = base["profiles"][:2] + proposals(recipe)
    rows = assignments(recipe)
    result = dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=copy.deepcopy(base["descriptors"]), profiles=profiles,
        conditions=copy.deepcopy(base["conditions"]), starts=copy.deepcopy(base["starts"]),
        profiles_by_body=rows)
    if route:
        index = recipe["route_body_index"]
        result.update(schema_version=righting.SCHEMA, descriptors=[result["descriptors"][index]],
                      profiles=[profiles[i] for i in rows[index]])
        del result["profiles_by_body"]
    return result


def validate(c):
    if "trajectory_retiming" not in c:
        return
    recipe = c["trajectory_retiming"]
    require(recipe == RECIPE and c["mode"] in ("route_ghost", "development_discovery")
            and "trajectory_proposal" not in c and c["trajectory_screen"] == trajectory.POLICY,
            "Retiming declaration scope")
    route = c["mode"] == "route_ghost"
    require(c["righting_spec"] == spec(recipe, route=route)
            and c["outer_steps"] == (2 if route else 1440)
            and c["maximum_worlds_per_batch"] == 14 and c["seed"] == recipe["seed"],
            "Retiming paired population, horizon or batch drift")


def assess(c, metrics, assessment):
    """Retain every original/slow contrast; these are development diagnostics."""
    validate(c)
    require("trajectory_retiming" in c, "Retiming missing declaration")
    metadata, episodes = c["righting_metadata"], assessment["episodes"]
    require(len(metadata) == len(metrics) == len(episodes), "Retiming outcome denominator")
    pairs = {}
    for meta, metric, episode in zip(metadata, metrics, episodes, strict=True):
        require(episode["cell_id"] == meta["cell_id"] and type(episode["eligible"]) is bool
                and metric["trajectory_samples"] == c["outer_steps"] * 5,
                "Retiming outcome identity or horizon")
        if meta["candidate_index"] < 2:
            continue
        base, variant = meta["candidate_id"].rsplit("_", 1)
        require(variant in ("original", "slow3"), "Retiming variant identity")
        key = (meta["body_index"], meta["condition_index"], meta["start_index"], base)
        pair = pairs.setdefault(key, {})
        require(variant not in pair, "Retiming duplicate paired outcome")
        pair[variant] = dict(cell_id=meta["cell_id"], eligible=episode["eligible"],
            peak_rotation_degrees=trajectory.rotation_degrees(metric["trajectory_maximum_up_dot"]),
            distal_supported_peak_degrees=trajectory.rotation_degrees(metric["trajectory_maximum_distal_supported_up_dot"]),
            distal_contact_samples=metric["trajectory_distal_contact_samples"],
            joint_limit_violation_samples=metric["joint_limit_violation_steps"],
            terminal_upright_dwell_steps=metric["terminal_upright_dwell_steps"])
    reports = []
    for key, pair in pairs.items():
        require(set(pair) == {"original", "slow3"}, "Retiming missing paired outcome")
        old, slow = pair["original"], pair["slow3"]
        reports.append(dict(body_index=key[0], condition_index=key[1], start_index=key[2],
            base_profile_id=key[3], **pair,
            rotation_gain_degrees=slow["peak_rotation_degrees"] - old["peak_rotation_degrees"],
            distal_supported_rotation_gain_degrees=slow["distal_supported_peak_degrees"] - old["distal_supported_peak_degrees"],
            distal_contact_sample_gain=slow["distal_contact_samples"] - old["distal_contact_samples"],
            joint_violation_sample_gain=slow["joint_limit_violation_samples"] - old["joint_limit_violation_samples"]))
    require(len(reports) == (6 if c["mode"] == "route_ghost" else 96), "Retiming pair population")
    return dict(pairs=reports, paired_groups=len(reports),
        original_eligible=sum(p["original"]["eligible"] for p in reports),
        slow_eligible=sum(p["slow3"]["eligible"] for p in reports),
        diagnostic_only=True, full_controller_replay=False, trained=False,
        physical_acceptance_authority=False, training_data_authority=False,
        release_authority=False, equivalence_authority=False)
