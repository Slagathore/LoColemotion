"""Measured support exchange around an unchanged body-specific reference.

Only an unloaded limb seeks a new contact. A measured contact must persist
before one old limb may retract. Requested forces remain model proposals;
contact presence does not measure reaction force or establish recovery.
"""
import copy
import math

import numpy as np

import creature_body_moment as moment
from creature_batch import require

FIELDS = {"schema_version", "limb_relation", "mass_shift_weight", "stall_steps",
          "progress_increment_degrees", "minimum_reference_steps", "maximum_seek_steps",
          "contact_dwell_steps", "transfer_steps", "retry_steps", "target_update_steps",
          "target_joint_margin_rad", "target_floor_height_m"}
KNEE_SAMPLES = 9
DEFAULT_POLICY = dict(schema_version="locolemotion_support_exchange_v1", limb_relation="other_end",
    mass_shift_weight=.5, stall_steps=36, progress_increment_degrees=.25, minimum_reference_steps=120,
    maximum_seek_steps=180, contact_dwell_steps=6, transfer_steps=36, retry_steps=60,
    target_update_steps=12, target_joint_margin_rad=.05, target_floor_height_m=-.002)


def policy(value):
    require(type(value) is dict and set(value) == FIELDS
            and value["schema_version"] == "locolemotion_support_exchange_v1"
            and value["limb_relation"] in ("opposite_side", "other_end", "diagonal"), "Exchange policy fields")
    for key, low, high in (("mass_shift_weight", 0., 1.), ("progress_increment_degrees", .1, 2.),
            ("target_joint_margin_rad", .025, .12), ("target_floor_height_m", -.005, 0.)):
        require(moment.finite(value[key]) and low <= value[key] <= high, "Exchange bound: "+key)
    for key, low, high in (("stall_steps", 24, 120), ("minimum_reference_steps", 60, 240),
            ("maximum_seek_steps", 120, 240), ("contact_dwell_steps", 3, 24),
            ("transfer_steps", 24, 90), ("retry_steps", 30, 120), ("target_update_steps", 6, 24)):
        require(type(value[key]) is int and low <= value[key] <= high, "Exchange clock: "+key)
    return copy.deepcopy(value)


def initial(rotation):
    return dict(phase="reference", elapsed=0, cooldown=0, stall_count=0,
        best_rotation_degrees=rotation, base=None, support_limbs=[], replacement_limb=None,
        hold_positions_rad=None, axis_body=None, target=None, contact_count=0, cycles=0)


def replacement_limb(support, contacts, relation):
    """Ordered four-limb topology; choose an actually unloaded limb."""
    if not support:
        return None
    anchor = support[0]
    flip = {"opposite_side": 1, "other_end": 2, "diagonal": 3}[relation]
    ordered = [anchor ^ flip] + [i for i in range(4) if i != anchor ^ flip]
    return next((i for i in ordered if i not in support and not contacts[i]["presence"]), None)


def hinge_height_roots(anchor, axis, point_at_zero, height, lower, upper):
    """Solve the vertical coordinate of a point rotated about a fixed hinge.

    Rodrigues' formula gives A*cos(q)+B*sin(q)=C. This is a geometric
    intersection, with no assumption that the target is dynamically reachable.
    """
    r = point_at_zero-anchor
    fixed = axis*float(axis @ r)
    a, b = float(r[1]-fixed[1]), float(np.cross(axis,r)[1])
    c = height-float(anchor[1]+fixed[1])
    amplitude = math.hypot(a,b)
    if amplitude <= 1e-12:
        return [max(lower,min(upper,0.))] if abs(c) <= 1e-9 else []
    if abs(c) > amplitude+1e-12:
        return []
    phase, delta = math.atan2(b,a), math.acos(max(-1.,min(1.,c/amplitude)))
    return sorted({phase+sign*delta+turn*2*math.pi for sign in (-1,1) for turn in (-1,0,1)
                   if lower <= phase+sign*delta+turn*2*math.pi <= upper})


def replacement_target(g, state, rotation, axis, support, limb, p, *, score=None):
    """Solve hip heights at nine knee samples; keep other measured joints exact.

    The measured posture is never clipped into a pose bank. Endpoint clearance
    does not certify the intervening movement; native path screening is separate.
    """
    q = np.asarray([j["position_rad"] for j in state["ordered_joint_observations"]])
    if not np.isfinite(q).all() or np.any(q < g.lower) or np.any(q > g.upper):
        return None
    pose = state["base_pose_world"]
    position = moment.mechanics.xyz(pose["position_m"])
    quaternion = [pose["orientation_xyzw"][k] for k in "xyzw"]
    world_axis = rotation @ axis
    frame = g.tree.kinematics(position, quaternion, q)
    points, _ = g.measured(frame)
    pivot = np.mean(points[support], axis=0)
    margin = p["support_exchange"]["target_joint_margin_rad"]
    lower, upper = g.lower+margin, g.upper-margin
    if np.any(lower >= upper):
        return None
    hip, knee = 2*limb, 2*limb+1
    joint = g.tree.joints[hip]
    anchor = position+rotation @ moment.mechanics.xyz(joint["anchor_parent_m"])
    hinge_axis = rotation @ moment.mechanics.xyz(joint["axis_parent_unit"])
    distal = int(g.bank.distal[limb])
    half, radius = g.bank.geometry.shapes[distal][1]
    floor = p["support_exchange"]["target_floor_height_m"]
    best = None
    for index, knee_angle in enumerate(np.linspace(lower[knee],upper[knee],KNEE_SAMPLES)):
        candidate = q.copy();candidate[hip] = 0.;candidate[knee] = knee_angle
        zero = g.tree.kinematics(position,quaternion,candidate)
        offset = zero["rotations"][distal,:,1]*half
        roots = set()
        for endpoint in (zero["positions"][distal]-offset,zero["positions"][distal]+offset):
            roots.update(hinge_height_roots(anchor,hinge_axis,endpoint,floor+radius,lower[hip],upper[hip]))
        for hip_angle in sorted(roots):
            candidate[hip] = hip_angle
            proposed = g.tree.kinematics(position,quaternion,candidate)
            feet, gap = g.measured(proposed);foot = feet[limb]
            body = 1+2*limb
            upper_half, upper_radius = g.bank.geometry.shapes[body][1]
            upper_low = proposed["positions"][body,1]-abs(proposed["rotations"][body,1,1])*upper_half-upper_radius
            _, arms = moment.force_direction(foot[None,:],proposed["whole_body_com"],world_axis,
                                             np.array([0.,1.,0.]),p["friction_ratio"])
            if gap < -1e-9 or abs(foot[1]-floor) > 1e-7 or foot[1] > upper_low+.01 or arms[0] <= 1e-9:
                continue
            gravity_arm = float(np.cross(proposed["whole_body_com"]-pivot,[0.,-1.,0.]) @ world_axis)
            distance = float(np.mean(np.abs(candidate[hip:knee+1]-q[hip:knee+1])))
            score_m = float(arms[0])-.025*distance+p["support_exchange"]["mass_shift_weight"]*gravity_arm
            extra = {} if score is None else score(proposed, candidate, foot, float(arms[0]), gravity_arm, distance)
            if extra is None:
                continue
            score_m = extra.get("score_m", score_m)
            if best is None or score_m > best["score_m"]:
                best = dict(knee_sample_index=index,limb=limb,joint_targets_rad=candidate[hip:knee+1].tolist(),
                    endpoint_nonadjacent_gap_m=float(gap),predicted_foot_height_m=float(foot[1]),
                    proposed_moment_arm_m=float(arms[0]),gravity_moment_arm_m=gravity_arm,score_m=score_m)
                best.update(extra)
    return best


def supported_proposal(p, g, state, rotation, previous, support, axis, targets):
    """Convert model force requests at retained contacts through existing limits."""
    q = np.asarray([j["position_rad"] for j in state["ordered_joint_observations"]])
    qd = np.asarray([j["velocity_rad_s"] for j in state["ordered_joint_observations"]])
    pose = state["base_pose_world"]
    frame = g.tree.kinematics(moment.mechanics.xyz(pose["position_m"]),
        [pose["orientation_xyzw"][k] for k in "xyzw"], q)
    points, gap = g.measured(frame)
    directions, arms = moment.force_direction(points, frame["whole_body_com"], rotation @ axis,
                                               np.array([0.,1.,0.]), p["friction_ratio"])
    if not support or any(arms[i] <= 1e-9 for i in support):
        return None
    requested = g.weight*g.length*p["moment_weight_length_ratio"]
    normal = min(g.weight*p["normal_load_ratio"]/len(support), requested/sum(arms[i] for i in support))
    wrenches = [dict(body_id=g.tree.body_ids[g.bank.distal[i]], point=points[i].tolist(),
                    force=(normal*directions[i]).tolist(), torque=[0.,0.,0.]) for i in support]
    speed = np.asarray([min(m["maximum_target_speed_rad_s"],p["maximum_speed_rad_s"]) for m in g.spec["actuators"]])
    envelope = moment.mechanics.command_envelope(np.zeros(8),speed,previous,speed,
                                                 np.full(8,p["maximum_slew_rad_s_per_step"]))
    projection = moment.mechanics.command_for_static_wrenches(g.tree,frame,wrenches,[0.,-9.81,0.],
        envelope,qd,g.creature["spec"]["velocity_gains"],g.creature["spec"]["force_ranges"])
    proposal = p["position_gain_s_inv"]*(targets-q)
    for i in support:
        proposal[2*i:2*i+2] = projection["target"][2*i:2*i+2]
    normalized = np.where(targets >= 0.,targets/g.upper,-targets/g.lower)
    require(np.isfinite(proposal).all() and np.isfinite(normalized).all(), "Exchange finite proposal")
    return dict(phase="contact_force", normalized_targets=normalized.tolist(),
        proposed_velocities_rad_s=proposal.tolist(), active_limbs=list(support),
        axis_angular_rate_rad_s=float(moment.mechanics.xyz(state["base_twist_world"]["angular_velocity_rad_s"]) @ (rotation @ axis)),
        geometric_contact_points_m=points.tolist(), measured_nonadjacent_gap_m=gap,
        requested_moment_nm=requested, proposed_moment_nm=float(normal*sum(arms[i] for i in support)),
        requested_wrenches=wrenches,
        force_projection={k:v.tolist() if isinstance(v,np.ndarray) else v for k,v in projection.items()},
        forces_are_measured=False, dynamic_feasibility_established=False)


def plan(p, geometry, state, rotation, contacts, memory, previous, upright):
    e = p["support_exchange"]
    progress = math.degrees(math.acos(max(-1.,min(1.,-float(rotation[1,1])))))
    before = copy.deepcopy(memory) if memory is not None else initial(progress)
    after = copy.deepcopy(before)
    base_profile = {k:v for k,v in p.items() if k != "support_exchange"}
    base = moment.plan(base_profile,geometry,state,rotation,contacts,before["base"],previous,upright)
    after["base"] = base["state_after"]
    reason = "reference" if before["phase"] == "reference" else "continue"

    def fallback(cause):
        nonlocal after, reason
        base_memory, cycles = after["base"], after["cycles"]
        after = initial(progress)
        after.update(base=base_memory, cooldown=e["retry_steps"], cycles=cycles)
        reason = cause

    if upright:
        after = initial(progress)
        after["base"] = base["state_after"]
        reason = "upright_reset"
    elif before["phase"] == "reference":
        after["cooldown"] = max(0,before["cooldown"]-1)
        if progress >= before["best_rotation_degrees"]+e["progress_increment_degrees"]:
            after.update(best_rotation_degrees=progress, stall_count=0)
        elif base["active_limbs"] and before["elapsed"] >= e["minimum_reference_steps"] and not after["cooldown"]:
            after["stall_count"] += 1
        else:
            after["stall_count"] = 0
        if after["stall_count"] >= e["stall_steps"]:
            support = base["active_limbs"][:]
            limb = replacement_limb(support,contacts,e["limb_relation"])
            if limb is None:
                fallback("no_unloaded_limb")
            else:
                after.update(phase="seek", elapsed=0, support_limbs=support, replacement_limb=limb,
                    hold_positions_rad=[j["position_rad"] for j in state["ordered_joint_observations"]],
                    axis_body=(np.asarray(p["axis_body"])*base["state_after"]["sign"]).tolist(),
                    target=None, contact_count=0, cycles=before["cycles"]+1)
                reason = "measured_plateau"
    else:
        limb = before["replacement_limb"]
        required = before["support_limbs"] if before["phase"] == "seek" else before["support_limbs"][1:]+[limb]
        if not all(contacts[i]["presence"] for i in required):
            fallback("lost_required_contact")
        elif before["phase"] == "seek":
            after["contact_count"] = before["contact_count"]+1 if contacts[limb]["presence"] else 0
            if after["contact_count"] >= e["contact_dwell_steps"]:
                after.update(phase="transfer", elapsed=0)
                reason = "measured_replacement_contact"
            elif before["elapsed"] >= e["maximum_seek_steps"]:
                fallback("replacement_timeout")
        elif before["elapsed"] >= e["transfer_steps"]:
            fallback("transfer_complete")

    result = base
    if after["phase"] in ("seek", "transfer"):
        axis = np.asarray(after["axis_body"])
        limb, old = after["replacement_limb"], after["support_limbs"]
        if after["phase"] == "seek" and (after["target"] is None or after["elapsed"] % e["target_update_steps"] == 0):
            after["target"] = replacement_target(geometry,state,rotation,axis,old,limb,p)
        if after["target"] is None:
            fallback("no_clear_replacement_pose")
        else:
            targets = np.asarray(after["hold_positions_rad"]).copy()
            targets[2*limb:2*limb+2] = after["target"]["joint_targets_rad"]
            support = old
            if after["phase"] == "transfer":
                # Only the old primary contact retracts, after measured replacement.
                targets[2*old[0]:2*old[0]+2] = 0.
                support = old[1:]+[limb]
            proposal = supported_proposal(p,geometry,state,rotation,previous,support,axis,targets)
            if proposal is None:
                fallback("unsupported_moment_direction")
            else:
                result = proposal
    after["elapsed"] = 0 if upright else after["elapsed"]+1
    result.update(selection_reason=reason, state_before=before, state_after=after,
        support_exchange=dict(phase=after["phase"], reason=reason,
            measured_rotation_degrees=progress, support_limbs=after["support_limbs"],
            replacement_limb=after["replacement_limb"], contact_dwell_steps=after["contact_count"],
            target=after["target"], forces_are_measured=False, recovery_benefit_established=False))
    return result
