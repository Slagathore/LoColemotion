"""Deterministic motion proposals and explicitly non-qualifying progress signals.

The controller, motor bounds and supported-upright criterion are unchanged.
Partial rotation proposes further experiments; it never makes an episode pass.
"""
import copy
import math
import random

from creature_batch import require
import creature_righting_sequence as sequence

RECIPE = dict(schema_version="locolemotion_trajectory_proposal_v1", seed=1061121,
              candidates_per_family=16, body_count=16, assignment_offsets=[0, 3, 7, 11])
POLICY = dict(schema_version="locolemotion_trajectory_screen_v1", leads_per_group=2,
              minimum_peak_rotation_gain_degrees=5., one_lead_per_family=True,
              require_zero_joint_limit_violations=True, qualification_authority=False)


def proposals(recipe):
    require(recipe == RECIPE, "Trajectory proposal recipe")
    rng = random.Random(recipe["seed"])
    result = []
    for family in ("wave", "impulse", "waypoint"):
        for index in range(16):
            count = 3 + index % 4
            amplitude = (.45, .65, .9)[index % 3]
            if family == "wave":
                offsets = [rng.randrange(4)*math.pi/2 for _ in range(4)]
                knee_offset = (math.pi/2, math.pi, -math.pi/2)[index % 3]
                poses = [[round(amplitude*math.sin(2*math.pi*p/count + offsets[j//2]
                          + (knee_offset if j % 2 else 0.)), 12)
                          for j in range(8)] for p in range(count)]
            elif family == "impulse":
                windup = [amplitude*rng.choice((-1, 1)) for _ in range(8)]
                poses = [windup, [-v for v in windup]]
                poses += [[round(rng.uniform(-amplitude, amplitude), 12) for _ in range(8)]
                          for _ in range(count-2)]
            else:
                poses = [[round(rng.uniform(-.9, .9), 12) for _ in range(8)] for _ in range(count)]
            phases = []
            for p, pose in enumerate(poses):
                hold = (18, 30, 48, 72)[(index+p) % 4]
                if family == "impulse" and p == 1:
                    hold = 14 + 4*(index % 3)
                minimum = max(12, hold-1)
                phases.append(dict(id=f"phase_{p}", pose=pose,
                    limb_delay_steps=[0]*4 if index % 2 == 0 else [rng.randrange(min(8, minimum)) for _ in range(4)],
                    minimum_hold_steps=minimum, maximum_hold_steps=hold,
                    advance_when="pose", threshold=.03))
            profile = dict(id=f"{family}_{index:02d}", mode=sequence.MODE, phases=phases,
                axis_body=([1., 0., 0.], [0., 0., 1.], [-1., 0., 0.], [0., 0., -1.])[index % 4],
                minimum_progress_rate_rad_s=0., position_gain_s_inv=(4., 8., 12.)[index % 3],
                maximum_speed_rad_s=(2., 3.5)[index % 2],
                maximum_slew_rad_s_per_step=(.08, .2)[(index//2) % 2])
            result.append(sequence.profile(profile))
    return result


def assignments(recipe):
    require(recipe == RECIPE, "Trajectory assignment recipe")
    rows = [[0, 1] for _ in range(16)]
    for index in range(48):
        for offset in recipe["assignment_offsets"]:
            rows[(index+offset) % 16].append(index+2)
    return [sorted(row) for row in rows]


def validate(c):
    if "trajectory_reference_by_body" in c:
        refs=c["trajectory_reference_by_body"];spec=c.get("righting_spec",{})
        assigned=spec.get("profiles_by_body",[list(range(len(spec.get("profiles",[]))))]*len(spec.get("descriptors",[])))
        require(any(k in c for k in ("moment_handoff_search","support_exchange_search","support_sharing_search","torque_map_search"))
                and type(refs) is list and len(refs)==len(assigned)
                and all(type(r) is int and r>=2 and r in a for r,a in zip(refs,assigned,strict=True)),
                "Trajectory declared fresh references")
    if "trajectory_screen" not in c:
        require("trajectory_proposal" not in c, "Trajectory proposals require declared screening")
        return
    require(c["trajectory_screen"] == POLICY and "righting_spec" in c
            and c["mode"] in ("route_ghost", "development_discovery"), "Trajectory screening scope")
    if "trajectory_proposal" in c:
        recipe = c["trajectory_proposal"]
        spec = c["righting_spec"]
        require(c["mode"] == "development_discovery" and len(spec["descriptors"]) == 16
                and spec["profiles"][2:] == proposals(recipe)
                and spec.get("profiles_by_body") == assignments(recipe), "Trajectory frozen proposal expansion")


def initial_metrics():
    return dict(trajectory_maximum_up_dot=-1., trajectory_maximum_distal_supported_up_dot=-1.,
                trajectory_distal_contact_samples=0, trajectory_samples=0)


def measure(metric, row, creature):
    up = max(-1., min(1., 1-2*(row["qpos"][4]**2+row["qpos"][5]**2)))
    spec = creature["compiled"]["morphology"]["morphology_spec"]
    distal = {creature["spec"]["geom_names"].index(site["body_id"]+"_geom") for site in spec["contact_sites"]}
    contact = any(0 in hit["geom"] and any(g in distal for g in hit["geom"]) for hit in row["contacts"])
    metric["trajectory_maximum_up_dot"] = max(metric["trajectory_maximum_up_dot"], up)
    if contact:
        metric["trajectory_maximum_distal_supported_up_dot"] = max(metric["trajectory_maximum_distal_supported_up_dot"], up)
    metric["trajectory_distal_contact_samples"] += int(contact)
    metric["trajectory_samples"] += 1


def rotation_degrees(up):
    return math.degrees(math.acos(max(-1., min(1., -up))))


def assess(c, metrics):
    """Keep every exposed score and select progress leads separately from eligibility."""
    validate(c)
    require(len(metrics) == len(c["righting_metadata"]), "Trajectory assessment population")
    groups = {}
    for meta, metric in zip(c["righting_metadata"], metrics, strict=True):
        require(all(k in metric and type(metric[k]) in (int, float) and math.isfinite(metric[k])
                    for k in initial_metrics())
                and metric["trajectory_samples"] == c["outer_steps"]*5
                and type(metric["trajectory_distal_contact_samples"]) is int
                and 0 <= metric["trajectory_distal_contact_samples"] <= metric["trajectory_samples"]
                and -1 <= metric["trajectory_maximum_distal_supported_up_dot"] <= metric["trajectory_maximum_up_dot"] <= 1,
                "Trajectory finite samples or bounds")
        row = dict(meta, peak_rotation_degrees=rotation_degrees(metric["trajectory_maximum_up_dot"]),
            distal_supported_peak_degrees=rotation_degrees(metric["trajectory_maximum_distal_supported_up_dot"]),
            joint_limit_violation_steps=metric["joint_limit_violation_steps"])
        groups.setdefault((meta["body_index"], meta["condition_index"], meta["start_index"]), []).append(row)
    reports = []
    for key, rows in groups.items():
        comparators = {r["candidate_index"]: r for r in rows if r["candidate_index"] in (0, 1)}
        require(set(comparators) == {0, 1}, "Trajectory fresh comparators missing")
        timed = comparators[1]["peak_rotation_degrees"]
        reference_index=c.get("trajectory_reference_by_body",[1]*len(c["righting_spec"]["descriptors"]))[key[0]]
        reference=next(r for r in rows if r["candidate_index"]==reference_index)
        score="peak_gain_against_timed_degrees" if reference_index==1 else "peak_gain_against_reference_degrees"
        for row in rows:
            row["peak_gain_against_timed_degrees"] = row["peak_rotation_degrees"]-timed
            if reference_index!=1:
                row["peak_gain_against_reference_degrees"]=row["peak_rotation_degrees"]-reference["peak_rotation_degrees"]
        candidates = sorted((r for r in rows if r["candidate_index"] >= 2
            and r["candidate_index"] != reference_index
            and r["joint_limit_violation_steps"] == 0
            and r[score] >= POLICY["minimum_peak_rotation_gain_degrees"]),
            key=lambda r: (-r[score], -r["distal_supported_peak_degrees"], r["candidate_index"]))
        leads, families = [], set()
        for candidate in candidates:
            family = candidate["candidate_id"].split("_")[0]
            if family not in families:
                leads.append(copy.deepcopy(candidate)); families.add(family)
            if len(leads) == POLICY["leads_per_group"]:
                break
        reports.append(dict(body_index=key[0], condition_index=key[1], start_index=key[2],
                            observations=rows, progress_leads=leads))
        if reference_index!=1:
            reports[-1].update(reference_candidate_index=reference_index,reference_candidate_id=reference["candidate_id"])
    return dict(groups=reports, progress_lead_count=sum(len(v["progress_leads"]) for v in reports),
        diagnostic_only=True, recovery_qualified=False, trained=False, training_data_authority=False,
        physical_acceptance_authority=False, release_authority=False)
