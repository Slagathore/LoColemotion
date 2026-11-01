"""Retained contact and motor arithmetic; no forecasts, solves, or interventions."""
from collections import Counter
from contextlib import ExitStack, contextmanager
import math
from unittest.mock import patch

import mujoco
import numpy as np

from actuation_recovery_mechanics import (
    array, command_envelope, motor_torque, require, resolve_correction,
    torque_envelope,
)
from audit_gpu_batch_execution import same_bits
from sequence_authority_diagnostic_v1 import (
    close, contact_loads, diagnose, scalar_guards, specification,
)

FEET = tuple(name + "_distal" for name in (
    "front_left", "front_right", "rear_left", "rear_right"))
JOINT_LIMIT_KIND = int(mujoco.mjtConstraint.mjCNSTR_LIMIT_JOINT)


@contextmanager
def retained_only():
    """Fail if the reader accidentally crosses a known execution entrypoint."""
    with ExitStack() as guards:
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2",
                     "mj_forward", "mj_inverse", "mj_collision"):
            guards.enter_context(patch.object(
                mujoco, name, side_effect=AssertionError("Retained reader forbids native execution")))
        for target in (
            "xml.etree.ElementTree.fromstring", "xml.etree.ElementTree.parse",
            "predictive_sequence_v1.evaluate", "predictive_sequence_v1.search",
            "predictive_contact_sequence_v1.evaluate", "predictive_contact_sequence_v1.search",
            "held_contact_rollout.HeldContactRollout.predict",
            "prepared_predictive_model.PreparedSelector.select_canonical",
            "floating_base_dynamics.FloatingDynamics.mass_matrix",
            "floating_base_dynamics.FloatingDynamics.inverse_dynamics",
            "numpy.linalg.solve",
        ):
            guards.enter_context(patch(
                target, side_effect=AssertionError("Retained reader forbids new dynamics/search")))
        yield


def model_spec(prepared):
    joints = prepared["morphology_spec"]["joints"]
    result = dict(
        joint_ids=[joint["joint_id"] for joint in joints],
        limits=[[joint["lower_limit_rad"], joint["upper_limit_rad"]] for joint in joints],
        gains=prepared["velocity_gains"], ranges=prepared["force_ranges"],
        geom_bodies=["world"] + [geom["body_id"] for geom in prepared["ordered_geometry"]],
    )
    specification(result)
    require(tuple(name for name in result["geom_bodies"] if name in FEET) == FEET,
            "Contact authority exact distal identities")
    return result


def control_packet(row):
    """Keep the actual public envelope; prefix and handoff may use different caps."""
    request = row["resolution_request"]["provider_request"]
    baseline = request["deterministic_baseline"]["ordered_commands"]
    limits = request["safety_envelope"]["ordered_actuator_limits"]
    resolved = row["resolution"]["ordered_commands"]
    names = [entry["actuator_id"] for entry in baseline]
    require(len(names) == len(set(names)) == 8
            and [entry["actuator_id"] for entry in limits] == names
            and [entry["actuator_id"] for entry in resolved] == names,
            "Contact authority ordered public actuator join")
    sites = row["request"]["state"]["ordered_contact_observations"]
    require([site["contact_site_id"] for site in sites] ==
            [name.removesuffix("_distal") + "_foot" for name in FEET]
            and all(type(site["bears_support"]) is bool
                    and type(site["presence"]) is bool
                    and site["normal_load_n"] is None for site in sites),
            "Contact authority prepared flags do not contain measured loads")
    value = dict(
        command=row["outer_step"], actuator_ids=names,
        baseline=[entry["combined_canonical_target_velocity_rad_s"] for entry in baseline],
        speeds=[entry["maximum_target_speed_rad_s"] for entry in baseline],
        previous_correction=[entry["previous_applied_correction_rad_s"] for entry in limits],
        caps=[entry["maximum_absolute_correction_rad_s"] for entry in limits],
        slew=[entry["maximum_slew_per_step_rad_s"] for entry in limits],
        correction=[entry["applied_correction_rad_s"] for entry in resolved],
        target=row["native_targets"], qpos=row["native_observation"]["qpos"],
        qvel=row["native_observation"]["qvel"], time_s=row["native_observation"]["time_s"],
        prepared_presence=[site["presence"] for site in sites],
        prepared_support=[site["bears_support"] for site in sites],
    )
    for name in ("baseline", "speeds", "previous_correction", "caps", "slew", "correction", "target"):
        array(value[name], (8,), "Contact authority finite " + name)
    array(value["qpos"], (15,), "Contact authority prepared position")
    array(value["qvel"], (14,), "Contact authority prepared velocity")
    require(type(value["command"]) is int and value["command"] >= 0
            and math.isfinite(value["time_s"]), "Contact authority public command clock")
    return value


def motor_state(packet, raw, spec, tolerance):
    """Instantaneous ranges hold the recorded state fixed, including joint velocity."""
    _, gains, ranges = specification(spec)
    target = array(packet["target"], (8,), "Contact authority target")
    velocity = array(raw["before_qvel"], (14,), "Contact authority prior velocity")[6:]
    actual = array(raw["actuator_force_nm"], (8,), "Contact authority native force")
    require(same_bits(raw["ctrl"], packet["target"]), "Contact authority applied target join")
    envelope = command_envelope(packet["baseline"], packet["speeds"],
                                packet["previous_correction"], packet["caps"], packet["slew"])
    correction, projected = resolve_correction(envelope, packet["correction"])
    close(correction, packet["correction"], "Contact authority public correction bounds")
    close(projected, target, "Contact authority public target projection")
    predicted = motor_torque(target, velocity, gains, ranges)
    error = float(np.max(np.abs(actual - predicted)))
    require(error <= tolerance, "Contact authority native motor arithmetic")
    lower, upper = torque_envelope(envelope, velocity, gains, ranges)
    return dict(
        torque_nm=actual.tolist(), reachable_lower_torque_nm=lower.tolist(),
        reachable_upper_torque_nm=upper.tolist(),
        lower_cap=[bool(force == bound) for force, bound in zip(actual, ranges[:, 0])],
        upper_cap=[bool(force == bound) for force, bound in zip(actual, ranges[:, 1])],
        unchanged_torque=[bool(lo == hi) for lo, hi in zip(lower, upper)],
        lower_cap_positive_velocity=[bool(force == bound and speed > 0.)
                                     for force, bound, speed in zip(actual, ranges[:, 0], velocity)],
        maximum_motor_error_nm=error,
        local_ranges_are_counterfactual_trajectories=False,
    )


def native_limit_forces(sample, native_ids, joint_ids):
    """Decode only joint-limit rows; contact and other rows keep their own identities."""
    require(len(native_ids) == len(joint_ids) == len(set(native_ids)) == 8
            and all(type(index) is int and index > 0 for index in native_ids),
            "Contact authority native joint identifiers")
    require(len(sample["efc_type"]) == len(sample["efc_id"]) ==
            len(sample["efc_force"]) == sample["nefc"],
            "Contact authority complete native constraint vector")
    names = dict(zip(native_ids, joint_ids)); result = {}
    for kind, index, force in zip(sample["efc_type"], sample["efc_id"], sample["efc_force"], strict=True):
        require(type(kind) is int and type(index) is int
                and type(force) in (int, float) and math.isfinite(force),
                "Contact authority finite typed native constraint")
        if kind != JOINT_LIMIT_KIND:
            continue
        require(index in names and names[index] not in result,
                "Contact authority unique named native joint limit")
        result[names[index]] = force
    return result


def forecast_limit_forces(row, spec):
    # The inherited check accounts for every scalar limit and three-vector contact.
    contact_loads(row, spec)
    forces = row["prediction"]["solution"]["force"]
    cursor = 0; result = {}
    for constraint in row["prediction"]["constraints"]:
        if constraint["kind"] == "joint_limit":
            result[constraint["joint_id"]] = forces[cursor]
            cursor += 1
        else:
            cursor += 3
    require(cursor == len(forces), "Contact authority forecast force accounting")
    return result


def forecast_cases(selection):
    """Exactly the nested best forecasts audited by the native parent, without aliases."""
    contact = "seed_selection" in selection
    seed = selection["seed_selection"] if contact else selection
    refined = "original" in seed
    original = seed["original"] if refined else seed
    cases = [("original", original["best"])]
    populations = [("original", original["evaluations"])]
    require(len(original["evaluations"]) == original["evaluated_candidates"],
            "Contact authority original population")
    if refined:
        payload = seed["refinement"]
        require(len(payload["evaluations"]) == payload["result"]["evaluated_candidates"] == 316,
                "Contact authority complete local refinement")
        require(same_bits(seed["best"], payload["result"]["best"]),
                "Contact authority refinement winner alias")
        cases.append(("refined", seed["best"]))
        populations.append(("refined", payload["evaluations"]))
    if contact:
        payload = selection["contact_search"]
        require(len(payload["evaluations"]) == payload["result"]["evaluated_candidates"] == 102,
                "Contact authority complete contact search")
        require(same_bits(selection["best"], payload["result"]["best"]),
                "Contact authority contact winner alias")
        cases.append(("contact", selection["best"]))
        populations.append(("contact", payload["evaluations"]))
    require(sum(len(rows) for _, rows in populations) == selection["evaluated_candidates"],
            "Contact authority exact complete evaluated population")
    require(same_bits(cases[-1][1], selection["best"]), "Contact authority selected best join")
    return cases, populations


def population_summary(populations):
    result = []
    for name, records in populations:
        rejected = Counter(); eligible = 0; intervals = Counter()
        for record in records:
            forecast = record["result"]
            require(type(forecast["eligible"]) is bool and
                    type(forecast["valid_intervals"]) is int and
                    0 <= forecast["valid_intervals"] <= 66 and
                    forecast["eligible"] == (forecast["valid_intervals"] == 66),
                    "Contact authority inherited finite candidate outcome")
            eligible += int(forecast["eligible"])
            intervals[str(forecast["valid_intervals"])] += 1
            for reason in forecast["rejection_reasons"]:
                rejected[reason] += 1
        result.append(dict(stage=name, evaluated=len(records), eligible=eligible,
                           valid_interval_histogram=dict(sorted(intervals.items())),
                           rejection_reason_counts=dict(sorted(rejected.items())),
                           rejection_counts_may_overlap=True))
    return result


def forecast_diagnostic(value, best, spec, metric):
    diagnostic = diagnose(value, best["option"]["knots"], best["result"], spec)
    raw_steps = [step for interval in best["result"]["rows"] for step in interval["forecast"]["rows"]]
    require(len(raw_steps) == len(diagnostic["trace"]), "Contact authority best forecast denominator")
    geometry = [0] * 4; positive = [0] * 4; limits = Counter()
    for raw, row in zip(raw_steps, diagnostic["trace"], strict=True):
        loads = row["contact_normal_forces_n"]
        row["distal_geometric_contact"] = [name in loads for name in FEET]
        row["distal_normal_force_n"] = [loads.get(name, 0.) for name in FEET]
        row["distal_clearance_before_m"] = metric.clearance(raw["before_qpos"])
        row["distal_clearance_after_m"] = metric.clearance(raw["qpos"])
        row["joint_limit_constraint_force"] = forecast_limit_forces(raw, spec)
        for name in row["joint_limit_constraint_force"]:
            limits[name] += 1
        for j, name in enumerate(FEET):
            geometry[j] += int(name in loads)
            positive[j] += int(loads.get(name, 0.) > 0.)
    diagnostic.update(ordered_distal_bodies=list(FEET),
                      distal_geometric_contact_steps=geometry,
                      distal_positive_normal_force_steps=positive,
                      joint_limit_constraint_steps=dict(sorted(limits.items())),
                      geometry_is_loaded_contact=False)
    return diagnostic


def future_input_drift(starting, intervals, packets):
    """Later observed baselines come from the actual closed loop, not an alternative plan."""
    require(starting["command"] in packets, "Contact authority known starting command")
    close(starting["baseline"], packets[starting["command"]]["baseline"],
          "Contact authority initial baseline identity")
    require([row["offset"] for row in intervals] == list(range(len(intervals))),
            "Contact authority consecutive forecast input clock")
    rows = []
    for interval in intervals:
        offset = interval["offset"]
        if offset == 0:
            continue
        command = starting["command"] + offset
        if command not in packets:
            break
        actual = packets[command]
        require(actual["command"] == command, "Contact authority later prepared command identity")
        rows.append(dict(
            command=command, offset=offset,
            baseline_difference_rad_s=[a - b for a, b in zip(actual["baseline"], starting["baseline"], strict=True)],
            speed_difference_rad_s=[a - b for a, b in zip(actual["speeds"], starting["speeds"], strict=True)],
            target_difference_rad_s=([a - b for a, b in zip(actual["target"], interval["target"], strict=True)]
                                     if actual["transferred"] else None),
            actual_command_transferred=actual["transferred"],
        ))
    return dict(
        compared_future_prepared_commands=len(rows), rows=rows,
        compared_future_transferred_commands=sum(row["actual_command_transferred"] for row in rows),
        maximum_absolute_baseline_difference_rad_s=[max((abs(row["baseline_difference_rad_s"][j]) for row in rows), default=None) for j in range(8)],
        maximum_absolute_target_difference_rad_s=[max((abs(row["target_difference_rad_s"][j]) for row in rows if row["target_difference_rad_s"] is not None), default=None) for j in range(8)],
        later_states_follow_actual_closed_loop=True,
        counterfactual_future_baseline_truth=False,
        forecast_error_attributable_to_held_baseline_measured=False,
        future_observations_used_for_selection=False,
    )


def matched_first_interval(starting_command, result, native, spec):
    """Compare only the first interval whose target was actually transferred."""
    first = result["rows"][0]
    require(first["offset"] == 0 and len(first["forecast"]["rows"]) == 5,
            "Contact authority first applied interval")
    position = velocity = 0.; load_error = [0.] * 4; presence_mismatch = [0] * 4
    for step, predicted in enumerate(first["forecast"]["rows"]):
        internal = 5 * starting_command + step + 1
        require(internal in native, "Contact authority missing matched native sample")
        observed = native[internal]
        require(observed["command"] == starting_command
                and same_bits(observed["target"], first["target"]),
                "Contact authority matched applied target and internal clock")
        position = max(position, max(abs(a - b) for a, b in zip(observed["qpos"], predicted["qpos"], strict=True)))
        velocity = max(velocity, max(abs(a - b) for a, b in zip(observed["qvel"], predicted["qvel"], strict=True)))
        loads = contact_loads(predicted, spec)
        for j in range(4):
            load_error[j] = max(load_error[j], abs(observed["distal_normal_force_n"][j] - loads.get(FEET[j], 0.)))
            presence_mismatch[j] += int(observed["distal_geometric_contact"][j] != (FEET[j] in loads))
    return dict(compared_native_steps=5, maximum_position_component_error=position,
                maximum_velocity_component_error=velocity, maximum_distal_normal_force_error_n=load_error,
                distal_contact_presence_mismatch_steps=presence_mismatch,
                errors_are_diagnostic_only=True, later_forecasts_native_validated=False)


def native_summary(rows, spec):
    """Every retained sample contributes; no selection based on outcome or load."""
    require(rows and len({row["step"] for row in rows}) == len(rows),
            "Contact authority nonempty unique native sample population")
    require([row["step"] for row in rows] == list(range(rows[0]["step"], rows[-1]["step"] + 1)),
            "Contact authority consecutive native summary population")
    result = dict(internal_steps=len(rows), ordered_distal_bodies=list(FEET),
                  joint_ids=spec["joint_ids"], first_step=rows[0]["step"], last_step=rows[-1]["step"])
    for key, source in (("distal_geometric_contact_steps", "distal_geometric_contact"),
                        ("distal_positive_normal_force_steps", "distal_normal_force_n")):
        result[key] = [sum(int(row[source][j] > 0) for row in rows) for j in range(4)]
    result["distal_normal_impulse_n_s"] = [sum(row["distal_normal_force_n"][j] / 600. for row in rows) for j in range(4)]
    result["minimum_distal_clearance_before_m"] = [min(row["distal_clearance_before_m"][j] for row in rows) for j in range(4)]
    result["maximum_distal_clearance_before_m"] = [max(row["distal_clearance_before_m"][j] for row in rows) for j in range(4)]
    for name in ("lower_cap", "upper_cap", "unchanged_torque", "lower_cap_positive_velocity"):
        result[name + "_steps"] = [sum(int(row["motor"][name][j]) for row in rows) for j in range(8)]
    result["joint_limit_constraint_steps"] = {
        name: sum(name in row["joint_limit_constraint_force"] for row in rows) for name in spec["joint_ids"]}
    result["maximum_motor_error_nm"] = max(row["motor"]["maximum_motor_error_nm"] for row in rows)
    result["positive_normal_force_is_support_qualification"] = False
    result["local_torque_range_proves_global_infeasibility"] = False
    return result
