"""Geometry-guided ground reaching and bounded contact-anchor motion.

Targets use a declared flat ground plane and compiled distal capsule geometry.
A retained anchor is a geometric target selected after measured contact, not a
measured contact point, force estimate or certificate of dynamic feasibility.
"""
import copy
import math
import numpy as np

from actuation_recovery_mechanics import RigidTree, array, require, xyz
from creature_batch import identifier
import creature_joint_braking as braking

MODE = "contact_reach"
STRATEGIES = ("ground", "anchor", "sweep")
GRID = 25


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def profile(value):
    fields = {"id", "mode", "strategy", "axis_body", "bend_pattern", "active_limb_count",
        "push_depth_m", "sweep_fraction", "reach_timeout_steps", "push_steps", "reset_steps",
        "target_update_steps", "pose_a", "pose_b", "position_gain_s_inv",
        "maximum_speed_rad_s", "maximum_slew_rad_s_per_step", "joint_braking"}
    require(type(value) is dict and set(value) == fields, "Contact-reach profile fields")
    require(identifier(value["id"]) and value["mode"] == MODE
            and value["strategy"] in STRATEGIES
            and value["bend_pattern"] in ("outward", "inward"), "Contact-reach identity or strategy")
    require(type(value["axis_body"]) is list and len(value["axis_body"]) == 3
            and all(finite(v) for v in value["axis_body"])
            and value["axis_body"] in ([1., 0., 0.], [-1., 0., 0.], [0., 0., 1.], [0., 0., -1.]),
            "Contact-reach declared principal horizontal axis")
    require(type(value["active_limb_count"]) is int and value["active_limb_count"] in (1, 2)
            and finite(value["push_depth_m"]) and .005 <= value["push_depth_m"] <= .06
            and finite(value["sweep_fraction"]) and 0 <= value["sweep_fraction"] <= .3
            and (value["sweep_fraction"] > 0) is (value["strategy"] == "sweep"),
            "Contact-reach support or displacement bounds")
    for key, low, high in (("reach_timeout_steps", 60, 240), ("push_steps", 60, 240),
                           ("reset_steps", 12, 60), ("target_update_steps", 1, 24)):
        require(type(value[key]) is int and low <= value[key] <= high, "Contact-reach clock bounds")
    require(all(type(value[k]) is list and len(value[k]) == 8
                and all(finite(v) and -.9 <= v <= .9 for v in value[k]) for k in ("pose_a", "pose_b")),
            "Contact-reach idle/reset pose bounds")
    require(finite(value["position_gain_s_inv"]) and 1 <= value["position_gain_s_inv"] <= 12
            and finite(value["maximum_speed_rad_s"]) and 0 < value["maximum_speed_rad_s"] <= 3.5
            and finite(value["maximum_slew_rad_s_per_step"]) and 0 < value["maximum_slew_rad_s_per_step"] <= .2,
            "Contact-reach command bounds")
    braking.policy(value["joint_braking"])
    return copy.deepcopy(value)


def behavior_key(p):
    return (MODE, p["strategy"], *p["axis_body"], p["bend_pattern"], p["active_limb_count"],
        p["push_depth_m"], p["sweep_fraction"], p["reach_timeout_steps"], p["push_steps"], p["reset_steps"],
        p["target_update_steps"], *p["pose_a"], *p["pose_b"], p["position_gain_s_inv"],
        p["maximum_speed_rad_s"], p["maximum_slew_rad_s_per_step"],
        *(p["joint_braking"][k] for k in braking.FIELDS))


def turns(axis, angles):
    """Vectorized Rodrigues rotations for one compiled revolute axis."""
    x, y, z = xyz(axis)
    require(abs(x*x+y*y+z*z-1.) <= 1e-12, "Contact-reach joint axis")
    skew = np.asarray([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    a = angles[:, None, None]
    return np.eye(3) + np.sin(a)*skew + (1.-np.cos(a))*(skew @ skew)


class LimbGeometry:
    def __init__(self, spec):
        self.tree = RigidTree(spec)
        require(self.tree.n == 8 and len(spec["contact_sites"]) == 4, "Contact-reach four two-joint limbs")
        values = np.linspace(-.9, .9, GRID)
        self.poses = np.asarray([(h, k) for h in values for k in values])
        self.ends, self.radii, self.lengths, self.hips, self.distal = [], [], [], [], []
        for limb, site in enumerate(spec["contact_sites"]):
            hi, ki = 2*limb, 2*limb+1
            hip, knee = self.tree.joints[hi:ki+1]
            body_index = self.tree.index[site["body_id"]]
            require(self.tree.parent[hi] == 0 and self.tree.parent[ki] == self.tree.child[hi]
                    and self.tree.child[ki] == body_index
                    and self.tree.ancestors[body_index] == [hi, ki], "Contact-reach limb topology")
            shape = self.tree.bodies[body_index]["collision"]
            require(shape["kind"] == "capsule" and finite(shape["length_m"]) and shape["length_m"] > 0
                    and finite(shape["radius_m"]) and shape["radius_m"] > 0
                    and site["radius_m"] == shape["radius_m"], "Contact-reach distal capsule")
            lower = np.asarray([hip["lower_limit_rad"], knee["lower_limit_rad"]])
            upper = np.asarray([hip["upper_limit_rad"], knee["upper_limit_rad"]])
            require((lower < 0).all() and (upper > 0).all(), "Contact-reach neutral joint limits")
            q = np.where(self.poses >= 0, self.poses*upper, -self.poses*lower)
            rh, rk = turns(hip["axis_parent_unit"], q[:, 0]), turns(knee["axis_parent_unit"], q[:, 1])
            anchor = xyz(hip["anchor_parent_m"])
            proximal = anchor-rh @ xyz(hip["anchor_child_m"])
            knee_anchor = proximal+rh @ xyz(knee["anchor_parent_m"])
            distal_rotation = rh @ rk
            center = knee_anchor-distal_rotation @ xyz(knee["anchor_child_m"])
            half = shape["length_m"]/2
            endpoints = center[:, None, :] + np.stack((-distal_rotation[:, :, 1]*half,
                                                        distal_rotation[:, :, 1]*half), axis=1)
            require(np.isfinite(endpoints).all(), "Contact-reach finite candidate geometry")
            endpoints.setflags(write=False)
            self.ends.append(endpoints); self.radii.append(shape["radius_m"])
            self.lengths.append(float(np.linalg.norm(xyz(knee["anchor_parent_m"])-xyz(hip["anchor_child_m"])))+shape["length_m"])
            self.hips.append(anchor); self.distal.append(body_index)
        self.hips = np.asarray(self.hips)
        self.poses.setflags(write=False); self.hips.setflags(write=False)

    def candidates(self, limb, position, rotation):
        ends = position + self.ends[limb] @ rotation.T
        low = np.argmin(ends[:, :, 1], axis=1)
        return ends[np.arange(len(ends)), low]

    def measured_points(self, state):
        q = [j["position_rad"] for j in state["ordered_joint_observations"]]
        orientation = state["base_pose_world"]["orientation_xyzw"]
        frame = self.tree.kinematics(xyz(state["base_pose_world"]["position_m"]),
                                    [orientation[k] for k in "xyzw"], q)
        result = []
        for index in self.distal:
            body = self.tree.bodies[index]
            offset = frame["rotations"][index][:, 1]*body["collision"]["length_m"]/2
            ends = np.asarray([frame["positions"][index]-offset, frame["positions"][index]+offset])
            result.append(ends[int(np.argmin(ends[:, 1]))])
        return np.asarray(result)

    def select(self, limb, position, rotation, current_pair, bend_pattern, depth, anchor=None):
        points = self.candidates(limb, position, rotation)
        sign = 1 if self.hips[limb, 0] >= 0 else -1
        if bend_pattern == "inward": sign = -sign
        allowed = np.all(self.poses*sign >= -1e-12, axis=1)
        desired_y = self.radii[limb]-depth  # Declared flat ground: world y = 0.
        distance = np.sum((self.poses-np.asarray(current_pair))**2, axis=1)
        if anchor is None:
            # Prefer actually reaching the declared floor target before a short
            # joint move. If unreachable, retain the least-height proposal.
            possible = allowed & (points[:, 1] <= desired_y)
            if possible.any():
                allowed = possible
            else:
                lowest = float(np.min(points[allowed, 1]))
                allowed &= points[:, 1] <= lowest+1e-12
            score = (points[:, 1]-desired_y)**2 + (.05*self.lengths[limb])**2*distance
            desired = None
        else:
            desired = array(anchor, (3,), "Contact-reach finite world anchor").copy()
            desired[1] = desired_y
            # An anchor outside the limb plane is projected by finite search;
            # the residual remains visible instead of claiming reachability.
            error = points-desired
            score = np.sum(error*error, axis=1) + 3*error[:, 1]**2 + (.01*self.lengths[limb])**2*distance
        require(allowed.any() and np.isfinite(score).all(), "Contact-reach candidate projection")
        best = float(np.min(score[allowed]))
        index = int(np.flatnonzero(allowed & (score <= best+1e-14))[0])
        selected = points[index]
        return dict(grid_index=index, normalized_pose=self.poses[index].tolist(),
            geometric_low_endpoint_world_m=selected.tolist(), predicted_capsule_clearance_m=float(selected[1]-self.radii[limb]),
            desired_anchor_world_m=desired.tolist() if desired is not None else None,
            anchor_error_m=float(np.linalg.norm(selected-desired)) if desired is not None else None)


def plan(candidate, geometry, state, rotation, contacts, memory, upright):
    position = xyz(state["base_pose_world"]["position_m"])
    current = geometry.measured_points(state)
    q = [j["position_rad"] for j in state["ordered_joint_observations"]]
    normalized = [float(v)/(j["upper_limit_rad"] if v >= 0 else -j["lower_limit_rad"])
                  for j, v in zip(geometry.tree.joints, q, strict=True)]
    axis_world = rotation @ np.asarray(candidate["axis_body"])
    if memory is None:
        memory = dict(phase="reach", elapsed=0, cycle=0, active_limbs=[], anchors=[None]*4,
                      targets=candidate["pose_a"][:], choices=[None]*4)
    before, after = copy.deepcopy(memory), copy.deepcopy(memory)
    reason, new_anchor = "hold", False
    if upright:
        after = dict(phase="reach", elapsed=0, cycle=0, active_limbs=[], anchors=[None]*4,
                     targets=[0.]*8, choices=[None]*4)
        return dict(schema_version="locolemotion_contact_reach_decision_v1", state_before=before, state_after=after,
                    phase="upright_stance", selection_reason="upright_stance", normalized_targets=[0.]*8,
                    measured_low_endpoints_world_m=current.tolist(), active_contacts=0, anchor_updates=0)
    if not after["active_limbs"]:
        hips = position + geometry.hips @ rotation.T
        scores = np.cross(hips-position, [0., 1., 0.]) @ axis_world
        after["active_limbs"] = sorted(range(4), key=lambda i:(-float(scores[i]), i))[:candidate["active_limb_count"]]
        reason = "select_limbs"
    active_contacts = sum(contacts[i]["bears_support"] for i in after["active_limbs"])
    if after["phase"] == "reach" and active_contacts:
        after.update(phase="push", elapsed=0); reason = "measured_contact"
    elif after["phase"] == "reach" and after["elapsed"] >= candidate["reach_timeout_steps"]:
        after.update(phase="reset", elapsed=0); reason = "reach_timeout"
    elif after["phase"] == "push" and after["elapsed"] >= candidate["push_steps"]:
        after.update(phase="reset", elapsed=0); reason = "bounded_push"
    elif after["phase"] == "reset" and after["elapsed"] >= candidate["reset_steps"]:
        after.update(phase="reach", elapsed=0, cycle=after["cycle"]+1,
                     active_limbs=[], anchors=[None]*4, choices=[None]*4)
        reason = "new_cycle"
    updates = 0
    if after["phase"] == "push":
        for i in after["active_limbs"]:
            if contacts[i]["bears_support"] and after["anchors"][i] is None:
                after["anchors"][i] = current[i].tolist(); updates += 1
        new_anchor = updates > 0
    if after["phase"] == "reset" or not after["active_limbs"]:
        after["targets"] = candidate["pose_a"][:]
        after["choices"] = [None]*4
    elif after["elapsed"] % candidate["target_update_steps"] == 0 or new_anchor:
        after["targets"] = candidate["pose_b" if after["phase"] == "push" else "pose_a"][:]
        for i in after["active_limbs"]:
            anchor = after["anchors"][i] if candidate["strategy"] != "ground" else None
            if anchor is not None:
                anchor = np.asarray(anchor).copy()
                if candidate["strategy"] == "sweep":
                    tangent = np.cross(axis_world, [0., 1., 0.])
                    anchor += tangent*candidate["sweep_fraction"]*geometry.lengths[i]*after["elapsed"]/candidate["push_steps"]
            choice = geometry.select(i, position, rotation, normalized[2*i:2*i+2], candidate["bend_pattern"],
                                     candidate["push_depth_m"], anchor)
            after["targets"][2*i:2*i+2] = choice["normalized_pose"]
            after["choices"][i] = choice
    after["elapsed"] += 1
    return dict(schema_version="locolemotion_contact_reach_decision_v1", state_before=before, state_after=after,
        phase=after["phase"], selection_reason=reason, normalized_targets=after["targets"][:],
        measured_low_endpoints_world_m=current.tolist(), active_contacts=active_contacts, anchor_updates=updates)
