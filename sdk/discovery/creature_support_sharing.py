"""Force-bounded replacement poses and gradual contact-request sharing.

Only measured canonical posture/velocity/contact and committed prior commands
are used. Static requests and motor-response predictions are not measured
ground reaction, dynamic feasibility or qualified recovery.
"""
import copy
import math

import numpy as np

import creature_body_moment as moment
from creature_support_sharing_bounds import bounded_load_scale
import creature_support_exchange as exchange
from creature_batch import require

EXTRA = {"load_steps", "unload_steps", "maximum_share_steps", "minimum_request_fraction",
         "response_error_fraction", "torque_reserve_weight"}
DEFAULT_POLICY = dict(exchange.DEFAULT_POLICY,
    schema_version="locolemotion_support_sharing_v1", load_steps=24, unload_steps=24,
    maximum_share_steps=240, minimum_request_fraction=.5, response_error_fraction=.35,
    torque_reserve_weight=.5)
STATIC_RESERVE = .9
DT = 1 / 120


def policy(value):
    require(type(value) is dict and set(value) == exchange.FIELDS | EXTRA
            and value["schema_version"] == "locolemotion_support_sharing_v1", "Sharing policy fields")
    base = {k:value[k] for k in exchange.FIELDS}
    base["schema_version"] = exchange.DEFAULT_POLICY["schema_version"]
    exchange.policy(base)
    for key, low, high in (("load_steps", 12, 90), ("unload_steps", 12, 90), ("maximum_share_steps", 180, 360)):
        require(type(value[key]) is int and low <= value[key] <= high, "Sharing clock: "+key)
    for key, low, high in (("minimum_request_fraction", .25, .9), ("response_error_fraction", .1, .5),
                           ("torque_reserve_weight", 0., 1.)):
        require(moment.finite(value[key]) and low <= value[key] <= high, "Sharing bound: "+key)
    return copy.deepcopy(value)


def initial(rotation):
    return dict(exchange.initial(rotation), ready_count=0, unload_fraction=0.,
                last_replacement_torque_nm=None, last_request_fraction=0., last_old_request_fraction=1.)


def guarded_envelope(p, g, q, velocity, previous):
    """Image of speed/slew targets through the unchanged production joint guards."""
    speed = np.asarray([min(m["maximum_target_speed_rad_s"], p["maximum_speed_rad_s"]) for m in g.spec["actuators"]])
    env = moment.mechanics.command_envelope(np.zeros(8), speed, previous, speed,
                                            np.full(8, p["maximum_slew_rad_s_per_step"]))
    for side in ("lower", "upper"):
        values = env[side+"_target"].copy()
        for j in range(8):
            value = moment.braking.shape(float(q[j]), float(velocity[j]), float(values[j]), float(speed[j]),
                float(g.lower[j]), float(g.upper[j]), DT, p["joint_braking"])["shaped_velocity_rad_s"]
            values[j] = max(min(0., (g.lower[j]-q[j])/DT), min(max(0., (g.upper[j]-q[j])/DT), value))
        env[side+"_target"] = values
        env[side+"_correction"] = values.copy()
    require(np.all(env["lower_target"] <= env["upper_target"]), "Sharing guarded command interval")
    return env


def request_geometry(p, g, frame, points, axis, limbs):
    directions, arms = moment.force_direction(points, frame["whole_body_com"], axis,
                                               np.array([0., 1., 0.]), p["friction_ratio"])
    if not limbs or any(arms[i] <= 1e-9 for i in limbs):
        return None
    desired = g.weight*g.length*p["moment_weight_length_ratio"]
    normal = min(g.weight*p["normal_load_ratio"]/len(limbs), desired/sum(arms[i] for i in limbs))
    return directions, arms, normal


def replacement_target(p, g, state, rotation, old, limb, axis):
    shim = dict(p, support_exchange=p["support_sharing"])

    def score(frame, candidate, point, arm, gravity_arm, distance):
        js = [2*limb, 2*limb+1]
        directions, _ = moment.force_direction(point[None, :], frame["whole_body_com"], rotation @ axis,
                                                np.array([0., 1., 0.]), p["friction_ratio"])
        normal = min(g.weight*p["normal_load_ratio"], g.weight*g.length*p["moment_weight_length_ratio"]/arm)
        wrench = dict(body_id=g.tree.body_ids[g.bank.distal[limb]], point=point.tolist(),
                      force=(normal*directions[0]).tolist(), torque=[0., 0., 0.])
        gravity = g.tree.gravity_torques(frame, [0., -9.81, 0.])
        contact = g.tree.wrench_torques(frame, [wrench])
        scale = bounded_load_scale(gravity[js], contact[js],
                            np.asarray(g.creature["spec"]["force_ranges"])[js])
        if scale is None or scale[1] <= 0.:
            return None
        bounded = normal*max(scale[0], scale[1]*STATIC_RESERVE)
        value = bounded*arm/g.weight + p["support_sharing"]["torque_reserve_weight"]*g.length*scale[1]
        value += p["support_sharing"]["mass_shift_weight"]*gravity_arm-.025*distance
        return dict(score_m=float(value), static_force_cap_scale_interval=scale,
                    proposed_bounded_normal_n=float(bounded), proposed_bounded_moment_nm=float(bounded*arm),
                    dynamic_feasibility_established=False)

    return exchange.replacement_target(g, state, rotation, axis, old, limb, shim, score=score)


def proposal(p, g, state, rotation, previous, old, replacement, phase, fraction, targets, axis):
    q = np.asarray([j["position_rad"] for j in state["ordered_joint_observations"]])
    velocity = np.asarray([j["velocity_rad_s"] for j in state["ordered_joint_observations"]])
    pose = state["base_pose_world"]
    frame = g.tree.kinematics(moment.mechanics.xyz(pose["position_m"]),
                             [pose["orientation_xyzw"][k] for k in "xyzw"], q)
    points, gap = g.measured(frame)
    world_axis = rotation @ axis
    retained = old[1:] if phase == "transfer" else old
    original = request_geometry(p, g, frame, points, world_axis, retained or [replacement])
    if original is None:
        return None
    directions, arms, old_normal = original
    weights = {i:1. for i in old}
    if phase != "seek":
        weights[replacement] = fraction if phase == "load" else 1.
    if phase == "unload":
        weights[old[0]] = 1.-fraction
    elif phase == "transfer":
        weights.pop(old[0])
    env = guarded_envelope(p, g, q, velocity, previous)
    ranges = np.asarray(g.creature["spec"]["force_ranges"])
    lower, upper = moment.mechanics.torque_envelope(env, velocity, g.creature["spec"]["velocity_gains"], ranges)
    gravity = g.tree.gravity_torques(frame, [0., -9.81, 0.])
    wrenches, details, active = [], [], []
    for limb, weight in weights.items():
        if arms[limb] <= 1e-9:
            return None
        js = [2*limb, 2*limb+1]
        normal = old_normal if limb in old else min(g.weight*p["normal_load_ratio"],
                       g.weight*g.length*p["moment_weight_length_ratio"]/arms[limb])
        wrench = dict(body_id=g.tree.body_ids[g.bank.distal[limb]], point=points[limb].tolist(),
                      force=(normal*directions[limb]).tolist(), torque=[0., 0., 0.])
        contact = g.tree.wrench_torques(frame, [wrench])
        cap = bounded_load_scale(gravity[js], contact[js], ranges[js])
        if cap is None or cap[1] <= 0.:
            return None
        # A fixed reserve below the static hard cap defines the full request.
        full = max(cap[0], cap[1]*STATIC_RESERVE)
        available = bounded_load_scale(gravity[js], contact[js],
                                                        np.column_stack((lower[js], upper[js])))
        if available is None or available[1] <= 0.:
            return None
        chosen = min(available[1], max(available[0], weight*full))
        if chosen <= 0. and not (phase == "unload" and limb == old[0] and weight == 0.):
            return None
        wrench["force"] = (normal*chosen*directions[limb]).tolist()
        wrenches.append(wrench);active.append(limb)
        details.append(dict(limb=limb, requested_weight=float(weight), static_scale_interval=cap,
            guarded_scale_interval=available, chosen_scale=float(chosen), full_scale=float(full),
            full_normal_n=float(normal*full), requested_normal_n=float(normal*chosen),
            request_fraction=float(chosen/full)))
    projected = moment.mechanics.command_for_static_wrenches(g.tree, frame, wrenches, [0., -9.81, 0.],
        env, velocity, g.creature["spec"]["velocity_gains"], g.creature["spec"]["force_ranges"])
    velocities = p["position_gain_s_inv"]*(targets-q)
    for limb in active:
        js = [2*limb, 2*limb+1]
        require(np.max(np.abs(projected["torque_error"][js])) <= 1e-8, "Sharing active request outside guarded envelope")
        velocities[js] = projected["target"][js]
    normalized = np.where(targets >= 0., targets/g.upper, -targets/g.lower)
    return dict(phase="contact_force", normalized_targets=normalized.tolist(),
        proposed_velocities_rad_s=velocities.tolist(), active_limbs=active,
        axis_angular_rate_rad_s=float(moment.mechanics.xyz(state["base_twist_world"]["angular_velocity_rad_s"]) @ world_axis),
        geometric_contact_points_m=points.tolist(), measured_nonadjacent_gap_m=gap,
        requested_moment_nm=float(g.weight*g.length*p["moment_weight_length_ratio"]),
        proposed_moment_nm=float(sum(v["requested_normal_n"]*arms[v["limb"]] for v in details)),
        requested_wrenches=wrenches, force_projection={k:v.tolist() if isinstance(v, np.ndarray) else v for k,v in projected.items()},
        sharing_requests=details, forces_are_measured=False, dynamic_feasibility_established=False)


def plan(p, g, state, rotation, contacts, memory, previous, upright):
    e = p["support_sharing"]
    progress = math.degrees(math.acos(max(-1., min(1., -float(rotation[1, 1])))))
    before = copy.deepcopy(memory) if memory is not None else initial(progress)
    after = copy.deepcopy(before)
    base = moment.plan({k:v for k,v in p.items() if k != "support_sharing"}, g, state, rotation,
                       contacts, before["base"], previous, upright)
    after["base"] = base["state_after"]
    reason = "reference" if before["phase"] == "reference" else "continue"
    response_ok, response_error = False, None
    if before["last_replacement_torque_nm"] is not None:
        limb = before["replacement_limb"];js = [2*limb, 2*limb+1]
        response = moment.mechanics.motor_torque(previous,
            [j["velocity_rad_s"] for j in state["ordered_joint_observations"]],
            g.creature["spec"]["velocity_gains"], g.creature["spec"]["force_ranges"])[js]
        prior = np.asarray(before["last_replacement_torque_nm"])
        response_error = float(np.linalg.norm(response-prior))
        response_ok = response_error <= max(.2, e["response_error_fraction"]*float(np.linalg.norm(prior)))

    def fallback(cause):
        nonlocal after, reason
        after = dict(initial(progress), base=after["base"], cooldown=e["retry_steps"], cycles=after["cycles"])
        reason = cause

    if upright:
        after = dict(initial(progress), base=base["state_after"]);reason = "upright_reset"
    elif before["phase"] == "reference":
        after["cooldown"] = max(0, before["cooldown"]-1)
        if progress >= before["best_rotation_degrees"]+e["progress_increment_degrees"]:
            after.update(best_rotation_degrees=progress, stall_count=0)
        elif base["active_limbs"] and before["elapsed"] >= e["minimum_reference_steps"] and not after["cooldown"]:
            after["stall_count"] += 1
        else:
            after["stall_count"] = 0
        if after["stall_count"] >= e["stall_steps"]:
            old = base["active_limbs"][:]
            limb = exchange.replacement_limb(old, contacts, e["limb_relation"])
            if limb is None:
                fallback("no_unloaded_limb")
            else:
                after.update(phase="seek", elapsed=0, support_limbs=old, replacement_limb=limb,
                    hold_positions_rad=[j["position_rad"] for j in state["ordered_joint_observations"]],
                    axis_body=(np.asarray(p["axis_body"])*base["state_after"]["sign"]).tolist(),
                    target=None, contact_count=0, cycles=before["cycles"]+1)
                reason = "measured_plateau"
    else:
        old, limb = before["support_limbs"], before["replacement_limb"]
        required = old if before["phase"] == "seek" else (old[1:]+[limb] if before["phase"] == "transfer" else old+[limb])
        if not all(contacts[i]["presence"] for i in required):
            fallback("lost_required_contact")
        elif before["phase"] == "seek":
            after["contact_count"] = before["contact_count"]+1 if contacts[limb]["presence"] else 0
            if after["contact_count"] >= e["contact_dwell_steps"]:
                after.update(phase="load", elapsed=0, ready_count=0);reason = "measured_replacement_contact"
            elif before["elapsed"] >= e["maximum_seek_steps"]:
                fallback("replacement_timeout")
        elif before["phase"] == "load":
            if (before["elapsed"] >= e["load_steps"] and before["ready_count"] >= e["contact_dwell_steps"]
                    and response_ok and before["last_request_fraction"] >= e["minimum_request_fraction"]):
                after.update(phase="unload", elapsed=0, unload_fraction=0.);reason = "bounded_request_ready"
            elif before["elapsed"] >= e["maximum_share_steps"]:
                fallback("load_response_timeout")
        elif before["phase"] == "unload":
            if before["elapsed"] >= e["maximum_share_steps"]:
                fallback("unload_response_timeout")
            else:
                ready = response_ok and before["last_request_fraction"] >= e["minimum_request_fraction"]
                after["unload_fraction"] = max(0., min(1., before["unload_fraction"]+(1. if ready else -1.)/e["unload_steps"]))
                if not ready:reason = "restore_old_request"
                if after["unload_fraction"] >= 1.-1e-12:
                    after["unload_fraction"] = 1.
                    # The guarded request can exceed the scheduled weight. Do
                    # not remove it until a committed zero request was possible.
                    if ready and before["last_old_request_fraction"] <= 1e-12:
                        after.update(phase="transfer", elapsed=0);reason = "staged_unload_complete"
                    else:
                        reason = "await_old_request_release"
        elif before["elapsed"] >= e["transfer_steps"]:
            fallback("transfer_complete")
    result = base
    if after["phase"] != "reference":
        old, limb, axis = after["support_limbs"], after["replacement_limb"], np.asarray(after["axis_body"])
        if after["phase"] == "seek" and (after["target"] is None or after["elapsed"] % e["target_update_steps"] == 0):
            after["target"] = replacement_target(p, g, state, rotation, old, limb, axis)
        if after["target"] is None:
            fallback("no_clear_force_bounded_pose")
        else:
            targets = np.asarray(after["hold_positions_rad"]).copy()
            targets[2*limb:2*limb+2] = after["target"]["joint_targets_rad"]
            if after["phase"] == "transfer":targets[2*old[0]:2*old[0]+2] = 0.
            fraction = min(1., (after["elapsed"]+1)/e["load_steps"]) if after["phase"] == "load" else after["unload_fraction"]
            proposed = proposal(p, g, state, rotation, previous, old, limb, after["phase"], fraction, targets, axis)
            if proposed is None:
                fallback("no_guarded_force_interval")
            else:
                result = proposed
                if after["phase"] != "seek":
                    info = next(v for v in proposed["sharing_requests"] if v["limb"] == limb)
                    after["last_request_fraction"] = info["request_fraction"]
                    after["last_old_request_fraction"] = next((v["request_fraction"] for v in proposed["sharing_requests"]
                                                               if v["limb"] == old[0]), 0.)
                    after["ready_count"] = before["ready_count"]+1 if response_ok and info["request_fraction"] >= e["minimum_request_fraction"] else 0
                    after["last_replacement_torque_nm"] = proposed["force_projection"]["requested_torque"][2*limb:2*limb+2]
    after["elapsed"] = 0 if upright else after["elapsed"]+1
    result.update(selection_reason=reason, state_before=before, state_after=after,
        support_sharing=dict(phase=after["phase"], reason=reason, measured_rotation_degrees=progress,
            support_limbs=after["support_limbs"], replacement_limb=after["replacement_limb"],
            ready_count=after["ready_count"], unload_fraction=after["unload_fraction"],
            prepared_motor_response_error_nm=response_error, prepared_motor_response_ok=response_ok,
            forces_are_measured=False, recovery_benefit_established=False))
    return result
