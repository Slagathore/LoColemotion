"""Measured upright steering and bounded release/reacquisition of foot support.

The existing moment controller supplies geometry and force proposals. This
component changes their direction and timing, without inventing contact loads
or treating a requested force as a measured reaction.
"""
import copy
import math

import numpy as np

import creature_body_moment as moment
from creature_batch import require

FIELDS = {"schema_version", "steering_bias", "minimum_tilt_sine", "axis_slew_rad_per_step",
          "schedule", "minimum_push_steps", "maximum_push_steps", "release_steps",
          "stall_steps", "progress_deadband_rad_s"}


def policy(value):
    require(type(value) is dict and set(value) == FIELDS
            and value["schema_version"] == "locolemotion_moment_handoff_v1"
            and value["schedule"] in ("continuous", "clock", "stall"), "Handoff policy fields")
    for key, low, high in (("steering_bias", -.75, .75), ("minimum_tilt_sine", .02, .3),
            ("axis_slew_rad_per_step", .01, .2), ("progress_deadband_rad_s", .01, .5)):
        require(moment.finite(value[key]) and low <= value[key] <= high, "Handoff bound: " + key)
    for key, low, high in (("minimum_push_steps", 12, 120), ("maximum_push_steps", 60, 240),
            ("release_steps", 12, 60), ("stall_steps", 12, 60)):
        require(type(value[key]) is int and low <= value[key] <= high, "Handoff clock: " + key)
    require(value["minimum_push_steps"] < value["maximum_push_steps"], "Handoff push order")
    return copy.deepcopy(value)


def steering(rotation, angular, seed_axis, previous_axis, p):
    # R.T * world-up is the measured up direction in body coordinates.
    # body-up cross that vector is the torque direction increasing uprightness.
    up = rotation[1]
    gradient = np.array([up[2], 0., -up[0]])
    sine = float(np.linalg.norm(gradient))
    direction = np.asarray(seed_axis, dtype=float)
    available = sine >= p["minimum_tilt_sine"]
    if available:
        direction = gradient / sine
        side = np.array([direction[2], 0., -direction[0]])
        direction = direction + p["steering_bias"] * side
        direction /= np.linalg.norm(direction)
    old = np.asarray(previous_axis, dtype=float)
    angle = math.atan2(old[2], old[0])
    delta = (math.atan2(direction[2], direction[0])-angle+math.pi) % (2*math.pi)-math.pi
    turn = max(-p["axis_slew_rad_per_step"], min(p["axis_slew_rad_per_step"], delta))
    axis = old.copy() if turn == 0. else np.array([math.cos(angle+turn), 0., math.sin(angle+turn)])
    progress_axis = gradient / sine if available else np.asarray(seed_axis)
    rate = float(moment.mechanics.xyz(angular) @ (rotation @ progress_axis))
    require(np.isfinite(axis).all() and abs(float(axis @ axis)-1.) < 1e-12 and math.isfinite(rate),
            "Handoff finite unit steering")
    return axis, rate, available


def plan(p, geometry, state, rotation, contacts, memory, previous, upright):
    h = p["handoff"]
    before = copy.deepcopy(memory) if memory is not None else dict(
        phase="push", elapsed=0, stall_count=0, cycles=0, axis_body=p["axis_body"][:], inner=None)
    after = copy.deepcopy(before)
    axis, rate, steering_available = steering(rotation, state["base_twist_world"]["angular_velocity_rad_s"],
        p["axis_body"], before["axis_body"], h)
    contact_available = any(c["presence"] for c in contacts)
    reason = "continue"
    if upright:
        after.update(phase="push", elapsed=0, stall_count=0, axis_body=p["axis_body"][:], inner=None)
        axis = np.asarray(p["axis_body"]);reason = "upright_reset"
    elif before["phase"] == "release":
        if before["elapsed"] >= h["release_steps"]:
            after.update(phase="push", elapsed=0, stall_count=0, inner=None)
            reason = "reacquire"
    else:
        stalled = h["schedule"] == "stall" and contact_available and rate < h["progress_deadband_rad_s"]
        after["stall_count"] = before["stall_count"]+1 if stalled else 0
        measured = before["elapsed"] >= h["minimum_push_steps"] and after["stall_count"] >= h["stall_steps"]
        deadline = before["elapsed"] >= h["maximum_push_steps"]
        if h["schedule"] != "continuous" and (deadline or measured):
            after.update(phase="release", elapsed=0, stall_count=0, cycles=before["cycles"]+1, inner=None)
            reason = "measured_stall_release" if measured else "bounded_release"
    base = {k: v for k, v in p.items() if k != "handoff"}
    base["axis_body"] = axis.tolist()
    decision = moment.plan(base, geometry, state, rotation, contacts, after["inner"], previous,
                           upright, retract=not upright and after["phase"] == "release")
    after.update(inner=decision["state_after"], axis_body=axis.tolist(),
                 elapsed=0 if upright else after["elapsed"]+1)
    decision.update(state_before=before, state_after=after,
        handoff=dict(phase=after["phase"], reason=reason, measured_progress_rate_rad_s=rate,
            measured_contact_available=contact_available, upright_steering_available=steering_available,
            commanded_axis_body=axis.tolist(), requested_force_is_measurement=False))
    return decision
