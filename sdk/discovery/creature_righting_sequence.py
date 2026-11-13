"""Bounded pose sequences and reconstructed mechanical observations.

This controller component owns no simulator. Momentum is reconstructed from
measured generalized state and the compiled rigid tree. Sampled force times
joint displacement is a work estimate, not a continuous energy balance.
"""
import copy
import math

import numpy as np

from actuation_recovery_mechanics import array, require, xyz
from creature_batch import identifier

MODE = "pose_sequence"


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def profile(value):
    require(type(value) is dict and set(value) == {"id", "mode", "phases", "axis_body",
        "minimum_progress_rate_rad_s", "position_gain_s_inv", "maximum_speed_rad_s",
        "maximum_slew_rad_s_per_step"}, "Sequence profile fields")
    require(identifier(value["id"]) and value["mode"] == MODE, "Sequence profile identity")
    require(type(value["axis_body"]) is list, "Sequence axis list")
    axis = array(value["axis_body"], (3,), "Sequence axis")
    require(abs(float(axis @ axis)-1.) <= 1e-12 and axis[1] == 0., "Sequence horizontal unit axis")
    require(finite(value["position_gain_s_inv"]) and 1 <= value["position_gain_s_inv"] <= 12
        and finite(value["maximum_speed_rad_s"]) and 0 < value["maximum_speed_rad_s"] <= 3.5
        and finite(value["maximum_slew_rad_s_per_step"]) and 0 < value["maximum_slew_rad_s_per_step"] <= .2
        and finite(value["minimum_progress_rate_rad_s"]) and 0 <= value["minimum_progress_rate_rad_s"] <= .5,
        "Sequence command or progress-rate bounds")
    phases = value["phases"]
    require(type(phases) is list and 3 <= len(phases) <= 6, "Sequence phase population")
    for p in phases:
        require(type(p) is dict and set(p) == {"id", "pose", "limb_delay_steps", "minimum_hold_steps",
            "maximum_hold_steps", "advance_when", "threshold"} and identifier(p["id"]), "Sequence phase fields")
        require(type(p["pose"]) is list and len(p["pose"]) == 8
            and all(finite(v) and -.9 <= v <= .9 for v in p["pose"]), "Sequence normalized pose bounds")
        require(type(p["minimum_hold_steps"]) is int and type(p["maximum_hold_steps"]) is int
            and 12 <= p["minimum_hold_steps"] < p["maximum_hold_steps"] <= 240, "Sequence hold bounds")
        require(type(p["limb_delay_steps"]) is list and len(p["limb_delay_steps"]) == 4
            and all(type(v) is int and 0 <= v < p["minimum_hold_steps"] for v in p["limb_delay_steps"]),
            "Sequence limb delays")
        gate, threshold = p["advance_when"], p["threshold"]
        require((gate == "pose" and finite(threshold) and .01 <= threshold <= .3)
            or (gate == "progress" and finite(threshold) and 5 <= threshold <= 170)
            or (gate == "contact" and type(threshold) is int and 1 <= threshold <= 4), "Sequence transition gate")
    require(len({p["id"] for p in phases}) == len(phases), "Sequence duplicate phase identity")
    for a, b in zip(phases, phases[1:]+phases[:1], strict=True):
        require(sum(abs(x-y) for x, y in zip(a["pose"], b["pose"], strict=True))/8 >= .05,
            "Sequence adjacent pose aliases")
    return copy.deepcopy(value)


def behavior_key(candidate):
    result = [MODE, *candidate["axis_body"], *(candidate[k] for k in
        ("minimum_progress_rate_rad_s", "position_gain_s_inv", "maximum_speed_rad_s", "maximum_slew_rad_s_per_step"))]
    for p in candidate["phases"]:
        result.extend([*p["pose"], *p["limb_delay_steps"], p["minimum_hold_steps"],
            p["maximum_hold_steps"], p["advance_when"], p["threshold"]])
    return tuple(result)


def geometry_seeds(mean_heights, poses):
    """Select exposed geometric proposals, without claiming dynamic feasibility.

    Rows represent eight azimuths and 0..180 degrees in five-degree increments.
    Wind-up favors the opposite initial direction, drive the 15..20-degree
    interval, and follow-through the 90..95-degree interval. Phase targets must
    differ; the first and last target also differ from the neutral catch pose.
    """
    poses = np.asarray(poses)
    require(poses.ndim == 2 and poses.shape[1] == 8 and 4 <= len(poses) <= 32768,
            "Sequence geometric pose population")
    poses = array(poses, poses.shape, "Sequence geometric finite poses")
    require(np.max(np.abs(poses)) <= .9 and len(np.unique(poses, axis=0)) == len(poses),
            "Sequence geometric pose bounds or aliases")
    heights = array(mean_heights, (8, 37, len(poses)), "Sequence geometric height population")
    result = []
    for direction in range(8):
        chosen, scores = [], []
        for stage, values in enumerate((heights[(direction+4) % 8, 1]-heights[(direction+4) % 8, 0],
                heights[direction, 4]-heights[direction, 3], heights[direction, 19]-heights[direction, 18])):
            allowed = np.ones(len(poses), dtype=bool)
            for index in chosen:
                allowed &= np.mean(np.abs(poses-poses[index]), axis=1) >= .15
            if stage in (0, 2):
                allowed &= np.mean(np.abs(poses), axis=1) >= .05
            require(allowed.any(), "Sequence geometric diversity exhausted")
            minimum = float(np.min(values[allowed]))
            index = int(np.flatnonzero(allowed & (values <= minimum+1e-12))[0])
            chosen.append(index); scores.append(float(values[index]))
        result.append(dict(azimuth_degrees=direction*45, pose_indices=chosen,
            sampled_mean_height_differences_m=scores, poses=poses[chosen].tolist()))
    return result


def normalized_pose(spec, positions):
    return [max(-.9, min(.9, float(q)/(j["upper_limit_rad"] if q >= 0 else -j["lower_limit_rad"])))
            for q, j in zip(positions, spec["joints"], strict=True)]


def angles(spec, pose):
    return np.asarray([v*(j["upper_limit_rad"] if v >= 0 else -j["lower_limit_rad"])
                       for v, j in zip(pose, spec["joints"], strict=True)])


def mechanics(tree, state, axis_body):
    """Rigid-body momentum about whole-body COM, including every joint speed."""
    joints = state["ordered_joint_observations"]
    q = array([j["position_rad"] for j in joints], (tree.n,), "Sequence measured positions")
    qd = array([j["velocity_rad_s"] for j in joints], (tree.n,), "Sequence measured velocities")
    position = xyz(state["base_pose_world"]["position_m"])
    orientation = state["base_pose_world"]["orientation_xyzw"]
    frame = tree.kinematics(position, [orientation[k] for k in "xyzw"], q)
    linear = [xyz(state["base_twist_world"]["linear_velocity_m_s"])]
    angular = [xyz(state["base_twist_world"]["angular_velocity_rad_s"])]
    for i, joint in enumerate(tree.joints):
        parent, child = tree.parent[i], tree.child[i]
        anchor_speed = linear[parent] + np.cross(angular[parent], frame["anchors"][i]-frame["positions"][parent])
        omega = angular[parent] + frame["axes"][i]*qd[i]
        angular.append(omega)
        linear.append(anchor_speed-np.cross(omega, frame["anchors"][i]-frame["positions"][child]))
    angular, linear = np.asarray(angular), np.asarray(linear)
    velocities = linear+np.cross(angular, frame["centers"]-frame["positions"])
    mass = float(np.sum(tree.mass))
    com_velocity = np.sum(tree.mass[:, None]*velocities, axis=0)/mass
    offsets = frame["centers"]-frame["whole_body_com"]
    rotations = frame["rotations"]
    local_omega = np.einsum("bji,bj->bi", rotations, angular)
    inertias = np.asarray([xyz(b["inertia_diagonal_kg_m2"]) for b in tree.bodies])
    spin = np.einsum("bij,bj->bi", rotations, inertias*local_omega)
    momentum = np.sum(spin+np.cross(offsets, tree.mass[:, None]*(velocities-com_velocity)), axis=0)
    axis = array(axis_body, (3,), "Sequence mechanical axis")
    axis_world = rotations[0] @ axis
    axis_local = np.einsum("bji,j->bi", rotations, axis_world)
    inertia_axis = float(np.sum(inertias*axis_local**2)+np.sum(tree.mass*np.sum(np.cross(offsets, axis_world)**2, axis=1)))
    kinetic = float(.5*np.sum(tree.mass[:, None]*velocities**2)+.5*np.sum(inertias*local_omega**2))
    body_momentum = rotations[0].T @ momentum
    values = dict(whole_body_mass_kg=mass, com_height_m=float(frame["whole_body_com"][1]),
        com_velocity_world_m_s=com_velocity.tolist(), angular_momentum_world_kg_m2_s=momentum.tolist(),
        angular_momentum_body_kg_m2_s=body_momentum.tolist(), kinetic_energy_j=kinetic,
        gravitational_potential_j=mass*9.81*float(frame["whole_body_com"][1]),
        axis_angular_momentum_kg_m2_s=float(body_momentum @ axis), axis_inertia_kg_m2=inertia_axis,
        torso_axis_rate_rad_s=float((rotations[0].T @ angular[0]) @ axis))
    require(inertia_axis > 0 and kinetic >= 0 and all(np.isfinite(v).all() for v in values.values()),
            "Sequence nonfinite mechanical observation")
    return values


def plan(candidate, tree, state, rotation, contacts, memory, upright):
    positions = [j["position_rad"] for j in state["ordered_joint_observations"]]
    if memory is None:
        memory = dict(phase=0, elapsed=0, cycle=0, held_pose=normalized_pose(tree.spec, positions))
    before = copy.deepcopy(memory)
    phase, elapsed = before["phase"], before["elapsed"]
    current = candidate["phases"][phase]
    measured = mechanics(tree, state, candidate["axis_body"])
    axis = candidate["axis_body"]
    direction = np.asarray([-axis[2], 0., axis[0]])
    progress = math.degrees(math.atan2(float(rotation[1] @ direction), -float(rotation[1, 1])))
    error = float(np.max(np.abs(angles(tree.spec, current["pose"])-positions)))
    gate = current["advance_when"]
    ready = (error <= current["threshold"] if gate == "pose" else
        progress >= current["threshold"] and measured["torso_axis_rate_rad_s"] >= candidate["minimum_progress_rate_rad_s"]
        if gate == "progress" else contacts >= current["threshold"])
    after = copy.deepcopy(before)
    if upright:
        after = dict(phase=0, elapsed=0, cycle=0, held_pose=[0.]*8)
        target, reason = [0.]*8, "upright_stance"
    else:
        if elapsed < current["minimum_hold_steps"]:
            reason = "minimum_hold"
        elif ready or elapsed >= current["maximum_hold_steps"]:
            after.update(phase=(phase+1) % len(candidate["phases"]), elapsed=0,
                cycle=before["cycle"]+int(phase+1 == len(candidate["phases"])), held_pose=current["pose"][:])
            reason = "measured_"+gate if ready else "bounded_fallback"
        else:
            reason = "waiting_for_"+gate
        selected = candidate["phases"][after["phase"]]
        target = [v if after["elapsed"] >= selected["limb_delay_steps"][i//2] else after["held_pose"][i]
                  for i, v in enumerate(selected["pose"])]
        after["elapsed"] += 1
    return dict(schema_version="locolemotion_righting_sequence_decision_v1", state_before=before, state_after=after,
        phase_id="upright_stance" if upright else candidate["phases"][after["phase"]]["id"],
        selection_reason=reason, directed_progress_degrees=progress, measured_pose_error_rad=error,
        bearing_distal_contacts=contacts, normalized_targets=target, mechanics=measured)


def initial_work():
    return dict(sampled_joint_actuator_work_j=0., sampled_positive_joint_actuator_work_j=0.,
                sampled_negative_joint_actuator_work_j=0., sampled_work_intervals=0)


def measure_work(metric, row):
    # The completed-step joint-force sample is paired with the observed joint
    # displacement. Retain this quadrature convention; do not call it exact work.
    force = array(row["joint_force_nm"], (8,), "Sequence measured joint force")
    displacement = array(row["qpos"][7:], (8,), "Sequence completed joint pose")-array(
        row["before_qpos"][7:], (8,), "Sequence prior joint pose")
    work = force*displacement
    require(np.isfinite(work).all(), "Sequence finite sampled work")
    metric["sampled_joint_actuator_work_j"] += float(np.sum(work))
    metric["sampled_positive_joint_actuator_work_j"] += float(np.sum(np.maximum(work, 0.)))
    metric["sampled_negative_joint_actuator_work_j"] += float(np.sum(np.minimum(work, 0.)))
    metric["sampled_work_intervals"] += 1
    require(all(finite(metric[k]) for k in initial_work()), "Sequence work accumulation overflow")
