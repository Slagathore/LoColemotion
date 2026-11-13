"""Virtual torso goals produce joint proposals; they never move a native root."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import array, require, xyz

SCHEMA = "locolemotion_supported_torso_target_v1"
FIELDS = ("schema_version", "pivot", "maximum_rotation_rad", "ramp_steps", "rise_m")


def policy(value):
    require(type(value) is dict and set(value) == set(FIELDS)
            and value["schema_version"] == SCHEMA and value["pivot"] in ("root", "torso_edge"),
            "Torso target fields or pivot")
    finite = lambda x: type(x) in (int, float) and math.isfinite(x)
    require(finite(value["maximum_rotation_rad"]) and 0 < value["maximum_rotation_rad"] <= math.pi/3
            and type(value["ramp_steps"]) is int and 12 <= value["ramp_steps"] <= 120
            and finite(value["rise_m"]) and 0 <= value["rise_m"] <= .04,
            "Torso target bounds")
    return copy.deepcopy(value)


def frame(position, rotation, axis_body, anchors, elapsed, config, torso_size):
    """A bounded positive-axis orientation objective in an explicit virtual frame."""
    p = array(position, (3,), "Torso target position")
    r = array(rotation, (3,3), "Torso target rotation")
    axis = r @ array(axis_body, (3,), "Torso target axis")
    require(np.allclose(r.T @ r,np.eye(3),rtol=0.,atol=1e-10) and np.linalg.det(r)>0
            and abs(float(axis @ axis)-1.)<1e-10,"Torso target rigid frame")
    size = array(torso_size,(3,),"Torso target box size")
    require((size>0).all(),"Torso target positive box")
    corners = np.asarray([[x,y,z] for x in (-1.,1.) for y in (-1.,1.) for z in (-1.,1.)])*size/2
    world_corners = p+corners @ r.T
    support = array(anchors, (len(anchors),3), "Torso target support anchors")
    require(len(anchors) > 0 and type(elapsed) is int and elapsed >= 0, "Torso target contact clock")
    up = r[:,1]; world_up = np.array([0.,1.,0.])
    # Up dot along this axis is A*cos(t)+B*sin(t)+constant. Its positive
    # maximizing angle bounds the lookahead; yaw-like axes may offer no gain.
    constant = float(np.dot(axis,up)*np.dot(axis,world_up))
    a = float(np.dot(world_up,up))-constant
    b = float(np.dot(world_up,np.cross(axis,up)))
    amplitude = math.hypot(a,b)
    remaining = math.atan2(b,a) % (2*math.pi) if amplitude > 1e-12 else 0.
    if min(remaining,2*math.pi-remaining) < 1e-12: remaining = 0.
    ramp = min(1.,elapsed/config["ramp_steps"])
    angle = min(config["maximum_rotation_rad"]*ramp,remaining)
    x,y,z = axis
    skew = np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])
    delta = np.eye(3)+math.sin(angle)*skew+(1.-math.cos(angle))*(skew @ skew)
    pivot = p
    if config["pivot"] == "torso_edge":
        # Choose a low torso corner with the least upward rotational velocity;
        # the other corners initially rise about its body-axis edge.
        low = world_corners[:,1] <= np.min(world_corners[:,1])+1e-10
        speed = np.cross(axis,world_corners-p)[:,1]
        index = min(np.flatnonzero(low),key=lambda i:(float(speed[i]),int(i)))
        pivot = world_corners[index]
    target_position = pivot+delta @ (p-pivot)+world_up*config["rise_m"]*ramp
    target_rotation = delta @ r
    lowest = float(np.min((target_position+corners @ target_rotation.T)[:,1]))
    clearance_correction = max(0.,-lowest)
    target_position = target_position+world_up*clearance_correction
    return dict(position_m=target_position.tolist(), rotation_matrix=target_rotation.tolist(),
        pivot_world_m=pivot.tolist(), applied_rotation_rad=angle, ramp_fraction=ramp,
        torso_floor_clearance_correction_m=clearance_correction,
        virtual_torso_minimum_height_m=lowest+clearance_correction,
        remaining_positive_rotation_rad=remaining, maximum_attainable_up_dot=constant+amplitude,
        current_up_dot=float(up[1]), virtual_up_dot=float(target_rotation[1,1]),
        root_is_actuated_or_teleported=False)


def select(geometry, candidate, limb, position, rotation, current_pair, anchor, contacts, memory):
    active = (memory["phase"] == "push" and anchor is not None and contacts[limb]["bears_support"])
    reference = None
    if active:
        anchors = [memory["anchors"][i] for i in memory["active_limbs"]
                   if contacts[i]["bears_support"] and memory["anchors"][i] is not None]
        collision = geometry.tree.bodies[0]["collision"]
        require(collision["kind"] == "box","Torso target requires compiled box geometry")
        reference = frame(position,rotation,candidate["axis_body"],anchors,memory["elapsed"],candidate["torso_target"],xyz(collision["size_m"]))
    projected_position = np.asarray(reference["position_m"]) if active else position
    projected_rotation = np.asarray(reference["rotation_matrix"]) if active else rotation
    choice = geometry.select(limb,projected_position,projected_rotation,current_pair,
                             candidate["bend_pattern"],candidate["push_depth_m"],anchor)
    actual = geometry.candidates(limb,position,rotation)[choice["grid_index"]]
    choice["torso_target_projection"] = dict(active=active, virtual_frame=reference,
        actual_root_geometric_low_endpoint_world_m=actual.tolist(),
        actual_root_predicted_capsule_clearance_m=float(actual[1]-geometry.radii[limb]),
        projection_frame="virtual_torso_target" if active else "measured_torso")
    return choice
