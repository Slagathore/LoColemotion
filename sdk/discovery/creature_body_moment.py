"""Configured contact-force and momentum proposals through bounded velocities.

Only canonical observations enter this controller. Geometric poses avoid
nonadjacent overlap; their transitions and requested forces are not certified.
The native owner retains actual motion, contact and work independently.
"""
import copy
import json
import math

import numpy as np

import actuation_recovery_mechanics as mechanics
import creature_joint_braking as braking
from creature_batch import identifier, require
from creature_contact_moment import PoseContacts, segment_box_distance, segment_segment_distance
from creature_righting_geometry import pose_pool

MODE = "body_moment"
AXES = ([1.,0.,0.], [-1.,0.,0.], [0.,0.,1.], [0.,0.,-1.])
POOL = dict(states=[[0.,0.],[.9,.9],[-.9,-.9],[.9,-.9],[-.9,.9],
                    [.6,.9],[-.6,-.9],[.9,.45],[-.9,-.45]],
            uniform_count=512, edge_count=512, seed=1061134)
FIELDS = {"id", "mode", "axis_body", "strategy", "friction_ratio", "normal_load_ratio",
          "moment_weight_length_ratio", "pose_distance_weight_m", "target_update_steps",
          "minimum_hold_steps", "maximum_hold_steps", "rate_deadband_rad_s",
          "position_gain_s_inv", "maximum_speed_rad_s", "maximum_slew_rad_s_per_step", "joint_braking"}


def finite(v):
    return type(v) in (int, float) and math.isfinite(v)


def profile(value):
    require(type(value) is dict and set(value) == FIELDS and identifier(value["id"])
            and value["mode"] == MODE and value["strategy"] in ("drive", "rock"), "Moment profile fields")
    axis = value["axis_body"]
    require(type(axis) is list and len(axis) == 3 and all(finite(v) for v in axis)
            and axis in AXES, "Moment principal body axis")
    for key, low, high in (("friction_ratio",0.,.95), ("normal_load_ratio",.25,2.),
            ("moment_weight_length_ratio",.05,1.), ("pose_distance_weight_m",0.,.1),
            ("rate_deadband_rad_s",.01,.5), ("position_gain_s_inv",1.,12.),
            ("maximum_speed_rad_s",.1,3.5), ("maximum_slew_rad_s_per_step",.01,.2)):
        require(finite(value[key]) and low <= value[key] <= high, "Moment profile bound: "+key)
    for key, low, high in (("target_update_steps",1,12),("minimum_hold_steps",12,120),
                           ("maximum_hold_steps",60,240)):
        require(type(value[key]) is int and low <= value[key] <= high, "Moment clock bound: "+key)
    require(value["minimum_hold_steps"] < value["maximum_hold_steps"], "Moment hold order")
    braking.policy(value["joint_braking"])
    return copy.deepcopy(value)


def behavior_key(value):
    def numeric(v):
        if type(v) in (int,float):return float(v)
        if type(v) is list:return [numeric(x) for x in v]
        if type(v) is dict:return {k:numeric(x) for k,x in v.items()}
        return v
    return (MODE, json.dumps(numeric({k:v for k,v in value.items() if k != "id"}), sort_keys=True))


def force_direction(points, center, axis, up, friction):
    """Maximize signed moment per normal newton within a declared friction cone."""
    lever = np.cross(axis, points-center)
    normal = lever @ up
    tangent = lever-normal[...,None]*up
    length = np.linalg.norm(tangent, axis=-1)
    direction = up+friction*tangent/np.maximum(length[...,None],1e-15)
    return direction, np.sum(lever*direction,axis=-1)


class Geometry:
    def __init__(self, creature):
        self.creature = creature
        self.spec = creature["compiled"]["morphology"]["morphology_spec"]
        all_poses = PoseContacts(self.spec, pose_pool(**POOL))
        self.pool_indices = np.flatnonzero(all_poses.clear)
        require(len(self.pool_indices)>0 and all_poses.clear[0], "Moment missing clear neutral pose")
        self.bank = PoseContacts(self.spec, all_poses.geometry.poses[self.pool_indices])
        self.tree = self.bank.geometry.tree
        self.weight = float(sum(self.tree.mass))*9.81
        self.length = float(np.linalg.norm(self.bank.geometry.shapes[0][1]))
        # Two endpoints per distal capsule, in the shared support-feature order.
        self.features = np.asarray([[10,11],[14,15],[18,19],[22,23]])
        self.lower = np.asarray([j["lower_limit_rad"] for j in self.tree.joints])
        self.upper = np.asarray([j["upper_limit_rad"] for j in self.tree.joints])

    def target(self, position, rotation, current, axis, p):
        up = rotation[1]
        bank = self.bank
        low = bank.points @ up-bank.radii
        feature = self.features[np.arange(4), np.argmin(low[:,self.features],axis=2)]
        rows = np.arange(len(low))[:,None]
        points = bank.points[rows,feature]-bank.radii[feature,None]*up
        _, arm = force_direction(points,bank.geometry.com[:,None,:],axis,up,p["friction_ratio"])
        height = low[rows,feature]
        possible = height <= np.min(low,axis=1)[:,None]+.01
        normalized = np.where(current>=0,current/self.upper,-current/self.lower)
        distance = np.mean(np.abs(bank.geometry.poses-normalized),axis=1)
        score = arm-2*np.abs(position[1]+height)-p["pose_distance_weight_m"]*distance[:,None]
        score = np.where(possible,score,-np.inf)
        require(np.isfinite(score).any(), "Moment missing distal target")
        selected, limb = divmod(int(np.argmax(score)),4)
        return dict(bank_index=selected, pool_index=int(self.pool_indices[selected]), limb=limb,
            normalized_targets=bank.geometry.poses[selected].tolist(),
            target_nonadjacent_gap_m=float(bank.minimum_gap[selected]),
            predicted_contact_clearance_m=float(position[1]+height[selected,limb]),
            proposed_moment_arm_m=float(arm[selected,limb]), target_score_m=float(score[selected,limb]))

    def measured(self, frame):
        """Actual capsule low points and nonadjacent gap, with no joint clipping."""
        root, rotation = frame["positions"][0], frame["rotations"][0]
        ends, points = {}, []
        for b in range(1,9):
            half, radius = self.bank.geometry.shapes[b][1]
            offset = frame["rotations"][b,:,1]*half
            world = np.stack((frame["positions"][b]-offset,frame["positions"][b]+offset))
            ends[b] = ((world-root) @ rotation)[None,:,:]
            if b in self.bank.distal:
                point = world[int(np.argmin(world[:,1]))].copy();point[1]-=radius
                points.append(point)
        gaps = []
        for left,right in self.bank.pairs:
            radius = self.bank.geometry.shapes[right][1][1]
            if left==0:
                gap = segment_box_distance(ends[right],self.bank.geometry.shapes[0][1])[0]-radius
            else:
                gap = segment_segment_distance(ends[left],ends[right])[0]-radius-self.bank.geometry.shapes[left][1][1]
            gaps.append(float(gap))
        return np.asarray(points), min(gaps)


def plan(p, geometry, state, rotation, contacts, memory, previous, upright):
    """Pure proposal; callers atomically commit memory only after the whole batch."""
    g = geometry
    q = np.asarray([v["position_rad"] for v in state["ordered_joint_observations"]])
    qd = np.asarray([v["velocity_rad_s"] for v in state["ordered_joint_observations"]])
    position = mechanics.xyz(state["base_pose_world"]["position_m"])
    orientation = state["base_pose_world"]["orientation_xyzw"]
    frame = g.tree.kinematics(position,[orientation[k] for k in "xyzw"],q)
    points, gap = g.measured(frame)
    rate = float(mechanics.xyz(state["base_twist_world"]["angular_velocity_rad_s"]) @ (rotation @ p["axis_body"]))
    before = copy.deepcopy(memory) if memory is not None else dict(sign=1,elapsed=0,switches=0,target=None)
    after = copy.deepcopy(before);reason = "hold"
    if not upright and p["strategy"]=="rock":
        reversing = before["elapsed"]>=p["minimum_hold_steps"] and rate*before["sign"] < -p["rate_deadband_rad_s"]
        timeout = before["elapsed"]>=p["maximum_hold_steps"]
        if reversing or timeout:
            after.update(sign=-before["sign"],elapsed=0,switches=before["switches"]+1,target=None)
            reason = "measured_reversal" if reversing else "bounded_reversal"
    axis = np.asarray(p["axis_body"])*after["sign"]
    if upright:
        after.update(sign=1,elapsed=0,target=None)
        normalized = np.zeros(8);reason = "upright_stance"
    else:
        if after["target"] is None or state["semantic_step"] % p["target_update_steps"] == 0:
            after["target"] = g.target(position,rotation,q,axis,p)
        normalized = np.asarray(after["target"]["normalized_targets"])
        after["elapsed"] += 1
    targets = np.where(normalized>=0,normalized*g.upper,-normalized*g.lower)
    speed = np.asarray([min(m["maximum_target_speed_rad_s"],p["maximum_speed_rad_s"]) for m in g.spec["actuators"]])
    proposal = p["position_gain_s_inv"]*(targets-q)
    direction, arms = force_direction(points,frame["whole_body_com"],rotation @ axis,np.array([0.,1.,0.]),p["friction_ratio"])
    active = sorted((i for i,c in enumerate(contacts) if not upright and c["presence"] and arms[i]>1e-9),
                    key=lambda i:(-arms[i],i))[:2]
    requested_moment = g.weight*g.length*p["moment_weight_length_ratio"] if active else 0.
    normal = min(g.weight*p["normal_load_ratio"]/len(active),requested_moment/sum(arms[i] for i in active)) if active else 0.
    wrenches = [dict(body_id=g.tree.body_ids[g.bank.distal[i]],point=points[i].tolist(),
                    force=(normal*direction[i]).tolist(),torque=[0.,0.,0.]) for i in active]
    projection = None
    if active:
        envelope = mechanics.command_envelope(np.zeros(8),speed,previous,speed,
                                             np.full(8,p["maximum_slew_rad_s_per_step"]))
        projection = mechanics.command_for_static_wrenches(g.tree,frame,wrenches,[0.,-9.81,0.],
            envelope,qd,g.creature["spec"]["velocity_gains"],g.creature["spec"]["force_ranges"])
        for i in active:
            proposal[2*i:2*i+2] = projection["target"][2*i:2*i+2]
        projection = {k:v.tolist() if isinstance(v,np.ndarray) else v for k,v in projection.items()}
    require(np.isfinite(proposal).all(), "Moment finite proposal")
    return dict(phase="upright_stance" if upright else "contact_force" if active else "reach",
        selection_reason=reason, state_before=before, state_after=after,
        normalized_targets=normalized.tolist(), proposed_velocities_rad_s=proposal.tolist(),
        axis_angular_rate_rad_s=rate, active_limbs=active, geometric_contact_points_m=points.tolist(),
        measured_nonadjacent_gap_m=gap, requested_moment_nm=requested_moment,
        proposed_moment_nm=float(normal*sum(arms[i] for i in active)), requested_wrenches=wrenches,
        force_projection=projection, forces_are_measured=False, dynamic_feasibility_established=False)
