"""Finite S169 stance feedback in canonical coordinates; no engine access.

The model converts body-attitude/rate feedback into stance-foot velocities,
then uses damped planar inverse kinematics to propose joint-velocity deltas.
The public resolver remains responsible for correction, slew and speed limits.
This is an untrained development family, not a qualified balance controller.
"""
import json
import math
from pathlib import Path

CONTRACT = Path(__file__).with_suffix(".json")
LEGS = ["front_left", "front_right", "rear_left", "rear_right"]
JOINTS = [leg+"_"+joint for leg in LEGS for joint in ["hip", "knee"]]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def number(value):
    require(type(value) in (int, float) and math.isfinite(value), "Nonfinite or invalid scalar")
    return float(value)


def vector(value):
    require(isinstance(value, dict) and set(value) == {"x", "y", "z"}, "Canonical vector")
    return [number(value[key]) for key in ["x", "y", "z"]]


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"] == "locolemotion_stance_feedback_v1"
        and value["ordered_joint_ids"] == JOINTS and len(value["legs"]) == 4
        and value["maximum_absolute_correction_rad_s"] == .25
        and value["maximum_slew_per_step_rad_s"] == .02
        and value["jacobian_damping_m"] == .03 and value["maximum_tilt_rad"] == .6
        and all(value[k] is False for k in ["trained", "training_data_authority",
            "physical_acceptance_authority", "release_authority", "equivalence_authority"]), "Feedback definition")
    require([leg["id"] for leg in value["legs"]] == LEGS, "Feedback limb order")
    for leg in value["legs"]:
        vector(leg["hip_anchor_body_m"])
        require(0 < number(leg["upper_length_m"]) < 1
            and 0 < number(leg["lower_length_m"]) < 1, "Feedback segment length")
    candidates = value["candidates"]
    require(len(candidates) == 12 and len({c["id"] for c in candidates}) == 12, "Feedback family denominator")
    for candidate in candidates:
        validate_candidate(candidate)
    require(candidates[0]["mode"] == "baseline" and candidates[1]["mode"] == "fixed",
        "Feedback control roles")
    return value


def validate_candidate(candidate):
    require(candidate["mode"] in ("baseline", "fixed", "feedback"), "Feedback mode")
    require(candidate["factor"] is None if candidate["mode"] == "baseline" else candidate["factor"] == 0.,
        "Feedback proposal mode")
    require(len(candidate["ordered_coefficients"]) == 8
        and all(-.25 <= number(v) <= .25 for v in candidate["ordered_coefficients"]), "Feedback baseline coefficients")
    require(0 <= number(candidate["attitude_gain_s_inv"]) <= 6
        and 0 <= number(candidate["angular_damping"]) <= 1
        and 0 <= number(candidate["velocity_gain_s_inv"]) <= .5, "Feedback gain domain")


def validate_geometry(compiled, model):
    require(compiled["descriptor"] == model["descriptor"], "Feedback descriptor domain")
    spec = compiled["morphology"]["morphology_spec"]
    require(compiled["morphology"]["ordered_joint_ids"] == JOINTS, "Feedback compiled joint order")
    joints = {j["joint_id"]: j for j in spec["joints"]}
    sites = {s["contact_site_id"]: s for s in spec["contact_sites"]}
    for leg in model["legs"]:
        hip, knee = [joints[leg["id"]+"_"+name] for name in ["hip", "knee"]]
        require(hip["parent_body_id"] == "torso" and hip["anchor_parent_m"] == leg["hip_anchor_body_m"]
            and all(j["axis_parent_unit"] == dict(x=0., y=0., z=1.) and j["joint_type"] == "revolute"
                for j in [hip, knee]), "Feedback joint frames")
        require(hip["anchor_child_m"] == dict(x=0., y=leg["upper_length_m"]/2, z=0.)
            and knee["anchor_parent_m"] == dict(x=0., y=-leg["upper_length_m"]/2, z=0.)
            and knee["anchor_child_m"] == dict(x=0., y=leg["lower_length_m"]/2, z=0.)
            and sites[leg["id"]+"_foot"]["local_center_m"] == dict(x=0., y=-leg["lower_length_m"]/2, z=0.),
            "Feedback segment frames")


def rotation(quaternion):
    require(isinstance(quaternion, dict) and set(quaternion) == {"x", "y", "z", "w"}, "Quaternion shape")
    x, y, z, w = [number(quaternion[k]) for k in ["x", "y", "z", "w"]]
    norm2 = x*x+y*y+z*z+w*w
    require(abs(norm2-1.) <= 1e-5, "Quaternion outside unit tolerance")
    inv = 1/math.sqrt(norm2); x*=inv; y*=inv; z*=inv; w*=inv
    return [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]


def transform(matrix, value, *, transpose=False):
    return [sum((matrix[j][i] if transpose else matrix[i][j])*value[j] for j in range(3)) for i in range(3)]


def foot_geometry(leg, hip, knee):
    """Foot-sphere centre and its x/y Jacobian, relative to the torso."""
    h, k = number(hip), number(knee)
    a, b = leg["upper_length_m"], leg["lower_length_m"]
    sh, ch, sk, ck = math.sin(h), math.cos(h), math.sin(h+k), math.cos(h+k)
    origin = vector(leg["hip_anchor_body_m"])
    point = [origin[0]+a*sh+b*sk, origin[1]-a*ch-b*ck, origin[2]]
    jacobian = [[a*ch+b*ck, b*ck], [a*sh+b*sk, b*sk]]
    return point, jacobian


def inverse_velocity(jacobian, velocity, damping):
    """J^T (J J^T + lambda^2 I)^-1 v; finite at a straight leg."""
    a, b = jacobian[0]; c, d = jacobian[1]
    aa, ab, bb = a*a+b*b+damping*damping, a*c+b*d, c*c+d*d+damping*damping
    determinant = aa*bb-ab*ab
    require(damping > 0 and determinant > 0, "Damped Jacobian")
    x = (bb*velocity[0]-ab*velocity[1])/determinant
    y = (aa*velocity[1]-ab*velocity[0])/determinant
    return [a*x+c*y, b*x+d*y]


def feedback(state, command, candidate, model):
    """Read only current canonical observations. No future/history labels."""
    validate_candidate(candidate)
    require(candidate["mode"] == "feedback", "Feedback candidate required")
    orient = rotation(state["base_pose_world"]["orientation_xyzw"])
    gravity = vector(state["gravity_world_m_s2"])
    norm = math.sqrt(sum(v*v for v in gravity)); require(norm > 0, "Gravity direction")
    up = transform(orient, [-v/norm for v in gravity], transpose=True)
    require(up[1] >= math.cos(model["maximum_tilt_rad"]), "Outside declared tilt domain")
    gyro = transform(orient, vector(state["base_twist_world"]["angular_velocity_rad_s"]), transpose=True)
    velocity_world = vector(state["base_twist_world"]["linear_velocity_m_s"])
    require(math.sqrt(sum(v*v for v in gyro)) <= model["maximum_angular_speed_rad_s"]
        and math.sqrt(sum(v*v for v in velocity_world)) <= model["maximum_linear_speed_m_s"], "Outside declared speed domain")
    target = vector(command["desired_planar_velocity_task_m_s"])
    frame = state["task_frame"]
    forward, lateral = vector(frame["forward_axis_world_unit"]), vector(frame["lateral_axis_world_unit"])
    desired_world = [target[0]*forward[i]+target[2]*lateral[i] for i in range(3)]
    velocity_error = transform(orient, [desired_world[i]-velocity_world[i] for i in range(3)], transpose=True)
    kp, kd, kv = [candidate[k] for k in ["attitude_gain_s_inv", "angular_damping", "velocity_gain_s_inv"]]
    # For y-up coordinates: e_y cross desired_up = (up_z, 0, -up_x).
    omega = [kp*up[2]-kd*gyro[0], 0., -kp*up[0]-kd*gyro[2]]
    rows = state["ordered_joint_observations"]
    require([r["joint_id"] for r in rows] == JOINTS
        and all(r["validity"]["position"] is True for r in rows), "Joint observations")
    angles = {r["joint_id"]: number(r["position_rad"]) for r in rows}
    contacts = state["ordered_contact_observations"]
    require([r["contact_site_id"] for r in contacts] == [leg+"_foot" for leg in LEGS]
        and all(type(r["presence"]) is bool and type(r["bears_support"]) is bool
            and (not r["bears_support"] or r["presence"]) for r in contacts), "Support observations")
    corrections, receipts = [], []
    for leg, contact in zip(model["legs"], contacts, strict=True):
        point, jacobian = foot_geometry(leg, angles[leg["id"]+"_hip"], angles[leg["id"]+"_knee"])
        support = contact["presence"] and contact["bears_support"]
        # A planted foot moves opposite the requested body rigid motion.
        foot_velocity = [omega[2]*point[1]-kv*velocity_error[0],
            omega[0]*point[2]-omega[2]*point[0]-kv*velocity_error[1]]
        delta = inverse_velocity(jacobian, foot_velocity, model["jacobian_damping_m"]) if support else [0., 0.]
        require(all(math.isfinite(v) for v in delta), "Nonfinite feedback correction")
        corrections.extend(delta)
        receipts.append(dict(limb_id=leg["id"], support=support, foot_center_body_m=point,
            requested_foot_velocity_xy_m_s=foot_velocity, raw_feedback_rad_s=delta))
    return corrections, dict(status="supported", up_body=up, angular_velocity_body_rad_s=gyro,
        requested_angular_velocity_body_rad_s=omega, velocity_error_body_m_s=velocity_error, legs=receipts)
