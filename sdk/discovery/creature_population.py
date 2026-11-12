"""Factored creature populations and finite within-body discovery assessment.

Population expansion is pure. All declared cells survive assessment, including
failed bodies. Scores come only from complete independently checked full capture.
"""
import copy
import math

from creature_batch import identifier, profile, require
from showcase_model import FIELDS, validate_descriptor

DEFAULT_SELECTION = dict(
    minimum_height_m=.25, maximum_tilt_rad=.6,
    maximum_torso_contact_steps=0, maximum_safe_no_actuation_steps=0,
    minimum_ground_contact_steps=1, minimum_nonzero_force_steps=1,
    target_planar_velocity_m_s=[.2, 0.], shortlist_per_body_condition=2,
    minimum_mean_absolute_coefficient_distance=.10,
)


def validate_selection(value):
    require(type(value) is dict and set(value) == set(DEFAULT_SELECTION), "Creature selection fields")
    for key in ("minimum_height_m", "maximum_tilt_rad", "minimum_mean_absolute_coefficient_distance"):
        require(type(value[key]) in (int, float) and math.isfinite(value[key]), "Creature selection finite bound")
    require(0 < value["minimum_height_m"] <= 1 and 0 < value["maximum_tilt_rad"] <= math.pi
            and 0 <= value["minimum_mean_absolute_coefficient_distance"] <= .5, "Creature selection bounds")
    for key in ("maximum_torso_contact_steps", "maximum_safe_no_actuation_steps",
                "minimum_ground_contact_steps", "minimum_nonzero_force_steps"):
        require(type(value[key]) is int and 0 <= value[key] <= 7200, "Creature selection count bound")
    require(value["minimum_ground_contact_steps"] >= 1 and value["minimum_nonzero_force_steps"] >= 1,
            "Creature active-ground evidence required")
    require(type(value["shortlist_per_body_condition"]) is int and 1 <= value["shortlist_per_body_condition"] <= 4,
            "Creature shortlist bound")
    target = value["target_planar_velocity_m_s"]
    require(type(target) is list and len(target) == 2
            and all(type(v) in (int, float) and math.isfinite(v) and abs(v) <= 1 for v in target),
            "Creature selection velocity target")


def expand(spec):
    require(type(spec) is dict and set(spec) == {"schema_version", "descriptors", "profiles", "conditions", "starts"}
            and spec["schema_version"] == "locolemotion_creature_population_v1", "Creature population fields")
    bodies, profiles, conditions, starts = [spec[k] for k in ("descriptors", "profiles", "conditions", "starts")]
    require(all(type(v) is list and v for v in (bodies, profiles, conditions, starts))
            and 1 <= len(bodies) <= 64 and 2 <= len(profiles) <= 64 and 1 <= len(conditions) <= 4
            and 1 <= len(starts) <= 2 and len(bodies)*len(profiles)*len(conditions)*len(starts) <= 256,
            "Creature population budget")
    shapes = []
    for body in bodies:
        validate_descriptor(body)
        shapes.append(tuple(body[key] for key in FIELDS))
    require(len(set(shapes)) == len(shapes) and len({b["morphology_id"] for b in bodies}) == len(bodies),
            "Creature population duplicated shape or identity")
    profiles = [profile(p) for p in profiles]
    require(len({p["id"] for p in profiles}) == len(profiles) and profiles[0]["factor"] is None
            and all(p["factor"] is not None for p in profiles[1:]), "Creature population baseline or profile aliases")
    for rows in (conditions, starts):
        require(len({r["id"] for r in rows}) == len(rows) and all(identifier(r["id"]) for r in rows),
                "Creature condition/start identity")
    for condition in conditions:
        require(set(condition) == {"id", "motor_effectiveness"}
                and type(condition["motor_effectiveness"]) is list and len(condition["motor_effectiveness"]) == 8
                and all(type(v) in (int, float) and math.isfinite(v) and .5 <= v <= 1
                        for v in condition["motor_effectiveness"]), "Creature population motor condition")
    require(len({tuple(c["motor_effectiveness"]) for c in conditions}) == len(conditions), "Duplicate motor condition")
    for start in starts:
        require(set(start) == {"id", "lateral_velocity_m_s"} and type(start["lateral_velocity_m_s"]) in (int, float)
                and math.isfinite(start["lateral_velocity_m_s"]) and abs(start["lateral_velocity_m_s"]) <= .005,
                "Creature population initial state")
    require(len({s["lateral_velocity_m_s"] for s in starts}) == len(starts), "Duplicate population start")
    cells, velocities, metadata = [], [], []
    for bi, body in enumerate(bodies):
        for ci, condition in enumerate(conditions):
            for si, start in enumerate(starts):
                for pi, candidate in enumerate(profiles):
                    cell_id = f"body_{bi:03d}_condition_{ci}_start_{si}_candidate_{pi:03d}"
                    cells.append(dict(cell_id=cell_id, descriptor=copy.deepcopy(body), profile=copy.deepcopy(candidate),
                                      motor_effectiveness=copy.deepcopy(condition["motor_effectiveness"])))
                    velocities.append(start["lateral_velocity_m_s"])
                    metadata.append(dict(cell_id=cell_id, body_index=bi, body_id=body["morphology_id"],
                        condition_index=ci, condition_id=condition["id"], start_index=si, start_id=start["id"],
                        candidate_index=pi, candidate_id=candidate["id"]))
    return dict(cells=cells, initial_lateral_velocities_m_s=velocities, population_metadata=metadata)


def verify_expansion(c):
    expected = expand(c["population_spec"])
    require(all(c[key] == value for key, value in expected.items()), "Creature population expansion drift")
    validate_selection(c["selection"])


def failure_codes(metric, selection):
    return [code for code, failed in (
        ("height", metric["minimum_height_m"] < selection["minimum_height_m"]),
        ("tilt", metric["maximum_tilt_rad"] > selection["maximum_tilt_rad"]),
        ("torso_contact", metric["torso_contact_steps"] > selection["maximum_torso_contact_steps"]),
        ("safe_no_actuation", metric["safe_no_actuation_steps"] > selection["maximum_safe_no_actuation_steps"]),
        ("no_ground_contact", metric["ground_contact_steps"] < selection["minimum_ground_contact_steps"]),
        ("no_actuator_force", metric["nonzero_force_steps"] < selection["minimum_nonzero_force_steps"]),
    ) if failed]


def episode_results(c, metrics, bindings, metadata, selection):
    """Common full-horizon eligibility and quality; failed episodes have no score."""
    n = len(c["cells"])
    require(len(metrics) == len(bindings) == len(metadata) == n
            and [b["cell_id"] for b in bindings] == [v["cell_id"] for v in c["cells"]],
            "Creature assessment denominator or binding")
    validate_selection(selection)
    duration = c["outer_steps"]*5*c["timestep_s"]
    target = selection["target_planar_velocity_m_s"]
    episodes = []
    for meta, metric, binding in zip(metadata, metrics, bindings, strict=True):
        require(set(metric) == {"minimum_height_m", "maximum_tilt_rad", "torso_contact_steps",
            "safe_no_actuation_steps", "ground_contact_steps", "nonzero_force_steps",
            "forward_displacement_m", "lateral_displacement_m"}, "Creature assessment metrics")
        for key, value in metric.items():
            if key.endswith("_steps"):
                maximum = c["outer_steps"] if key == "safe_no_actuation_steps" else c["outer_steps"]*5
                require(type(value) is int and 0 <= value <= maximum, "Creature assessment count")
            else:
                require(type(value) in (int, float) and math.isfinite(value), "Creature assessment finite metric")
        require(0 <= metric["maximum_tilt_rad"] <= math.pi, "Creature assessment tilt")
        failures = failure_codes(metric, selection)
        error = math.hypot(metric["forward_displacement_m"]/duration-target[0],
                           metric["lateral_displacement_m"]/duration-target[1])
        episodes.append(dict(meta, body_shape_sha256=binding["body_shape_sha256"],
            descriptor_sha256=binding["descriptor_sha256"], eligible=not failures, failure_codes=failures,
            velocity_error_m_s=error if not failures else None, metrics=copy.deepcopy(metric)))
    return episodes


def candidate_summary(rows, index, candidate_id, start_count):
    require(len(rows) == start_count and [r["start_index"] for r in rows] == list(range(start_count))
            and all(r["candidate_index"] == index and r["candidate_id"] == candidate_id for r in rows),
            "Creature selection start denominator")
    eligible = all(r["eligible"] for r in rows)
    return dict(candidate_index=index, candidate_id=candidate_id, eligible=eligible,
        eligible_starts=sum(r["eligible"] for r in rows), start_count=len(rows),
        failure_codes_by_start=[r["failure_codes"] for r in rows],
        mean_velocity_error_m_s=sum(r["velocity_error_m_s"] for r in rows)/len(rows) if eligible else None)


def assess(c, metrics, bindings):
    verify_expansion(c)
    spec, selection = c["population_spec"], c["selection"]
    episodes = episode_results(c, metrics, bindings, c["population_metadata"], selection)
    groups = []
    for bi, body in enumerate(spec["descriptors"]):
        for ci, condition in enumerate(spec["conditions"]):
            candidates = []
            for pi, candidate in enumerate(spec["profiles"]):
                rows = [e for e in episodes if (e["body_index"], e["condition_index"], e["candidate_index"]) == (bi, ci, pi)]
                candidates.append(candidate_summary(rows, pi, candidate["id"], len(spec["starts"])))
            baseline = candidates[0]
            ranking = sorted((r for r in candidates[1:] if r["eligible"] and
                (not baseline["eligible"] or r["mean_velocity_error_m_s"] < baseline["mean_velocity_error_m_s"])),
                key=lambda r: (r["mean_velocity_error_m_s"], r["candidate_index"]))
            shortlist = []
            for row in ranking:
                genome = spec["profiles"][row["candidate_index"]]["ordered_coefficients"]
                if all(sum(abs(x-y) for x, y in zip(genome, spec["profiles"][i]["ordered_coefficients"], strict=True))/8
                       >= selection["minimum_mean_absolute_coefficient_distance"] for i in shortlist):
                    shortlist.append(row["candidate_index"])
                if len(shortlist) == selection["shortlist_per_body_condition"]:
                    break
            for row in candidates:
                row["baseline_minus_error_m_s"] = (baseline["mean_velocity_error_m_s"]-row["mean_velocity_error_m_s"]
                    if baseline["eligible"] and row["eligible"] else None)
            groups.append(dict(body_index=bi, body_id=body["morphology_id"], condition_id=condition["id"],
                candidates=candidates, ranked_candidate_indices=[r["candidate_index"] for r in ranking],
                shortlist_candidate_indices=shortlist))
    return dict(scope="finite_exposed_development_discovery", world_count=len(episodes),
        eligible_worlds=sum(e["eligible"] for e in episodes), performance_failed_worlds=sum(not e["eligible"] for e in episodes),
        episodes=episodes, body_conditions=groups, trained=False, tier2_qualified=False,
        training_data_authority=False, physical_acceptance_authority=False, release_authority=False,
        fresh_full_capture_shortlist_required=True)
