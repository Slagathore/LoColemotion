"""Independent measured entry-domain check; no actuation or controller history.

The caller verifies native source identity and clock bindings before this pure
calculation. Reference-path feasibility is not a future contact guarantee.
"""
import math
from finite_recovery_walking import LIMBS, measured_endpoints, rotate, vector


def require(value, code):
    if not value:
        raise ValueError("RECOVERY_WALKING_READINESS_" + code)


def measure(request, center_of_mass, compiled, limits):
    state, frame = request["state"], request["measured_body_frame"]
    require(frame["source_measurement"] is True and frame["semantic_step"] == state["semantic_step"]
            and frame["sample_time_s"] == state["sample_time_s"]
            and frame["adapter_capability_sha256"] == state["adapter_capability_sha256"], "FRAME_BINDING")
    torso = frame["ordered_body_states"][0]
    require(torso["body_id"] == "torso" and torso["pose_world"] == state["base_pose_world"]
            and torso["twist_world"] == state["base_twist_world"], "TORSO_BINDING")
    spec, g = compiled["morphology"]["morphology_spec"], compiled["geometry"]
    require(compiled["descriptor"]["morphology_id"] == "qsdk_r05_generated_s169", "EXACT_S169")
    # This route's recovery morphology uses hip y=0. The base descriptor supplies
    # unchanged leg lengths, contact sites and actuator bounds, not hip height.
    sites = spec["contact_sites"]
    require(len(sites) == 4, "SITES")
    endpoints = measured_endpoints({"request": request}, sites)
    origin = vector(torso["pose_world"]["position_m"])
    heading = rotate(torso["pose_world"]["orientation_xyzw"], (0., 0., 1.))
    norm = math.hypot(heading[0], heading[2])
    require(norm > 1e-9, "HEADING")
    forward = (heading[0]/norm, 0., heading[2]/norm)
    up = rotate(torso["pose_world"]["orientation_xyzw"], (0., 1., 0.))
    tilt = math.atan2(math.hypot(up[0], up[2]), up[1])
    floor = request["floor_reference"]["height_world_m"]
    require(type(floor) in (int, float) and math.isfinite(floor), "FLOOR")
    radius, upper, lower = (g[k] for k in ("foot_radius_m", "upper_length_m", "lower_length_m"))
    require(all(type(v) in (int, float) and math.isfinite(v) and v > 0 for v in (radius, upper, lower)), "DIMENSIONS")
    floor_center = floor + radius
    contacts = state["ordered_contact_observations"]
    require(len(contacts) == 4, "CONTACT_POPULATION")
    bearing = []
    for limb, contact in zip(LIMBS, contacts):
        require(contact["contact_site_id"] == limb+"_foot" and type(contact["presence"]) is bool
                and type(contact["bears_support"]) is bool, "KNOWN_CONTACT")
        bearing.append(contact["presence"] and contact["bears_support"])
    require(center_of_mass["source_measurement"] is True, "COM_SOURCE")
    velocity = vector(center_of_mass["linear_velocity_world_m_s"])
    omega = vector(state["base_twist_world"]["angular_velocity_rad_s"])
    speed, angular = math.hypot(velocity[0], velocity[2]), math.sqrt(sum(v*v for v in omega))
    actuators = spec["actuators"]
    require(len(actuators) == 8, "ACTUATORS")
    legs = []
    for i, limb in enumerate(LIMBS):
        hip, knee = actuators[2*i:2*i+2]
        require(hip["actuator_id"] == limb+"_hip_motor" and knee["actuator_id"] == limb+"_knee_motor", "ACTUATOR_ORDER")
        x = sum((endpoints[limb][j]-origin[j])*forward[j] for j in range(3))
        x -= g["front_hip_x_m" if i < 2 else "rear_hip_x_m"]
        failures, maximum_reach = [], 0.
        for n in range(73):
            u = n/72
            height = origin[1] + u*u*(3-2*u)*(floor_center+.33-origin[1])
            down = height-floor_center
            reach = math.hypot(x, down)
            maximum_reach = max(maximum_reach, reach)
            cosine = (x*x+down*down-upper*upper-lower*lower)/(2*upper*lower)
            if down <= 0 or not -1 <= cosine <= 1:
                failures.append(dict(reference_interval=n, reason="unreachable_endpoint"))
                continue
            k = math.acos(cosine)
            h = math.atan2(x, down)-math.atan2(lower*math.sin(k), upper+lower*math.cos(k))
            if not (hip["minimum_target_position_rad"] <= h <= hip["maximum_target_position_rad"]
                    and knee["minimum_target_position_rad"] <= k <= knee["maximum_target_position_rad"]):
                failures.append(dict(reference_interval=n, reason="joint_bounds"))
        legs.append(dict(limb_id=limb, sagittal_offset_m=x, maximum_required_reach_m=maximum_reach,
            available_leg_length_m=upper+lower, geometric_path_feasible=not failures, failed_references=failures))
    checks = dict(four_native_supports=all(bearing),
        horizontal_com_settled=speed <= limits["maximum_horizontal_com_speed_m_s"],
        angular_settled=angular <= limits["maximum_torso_angular_speed_rad_s"],
        upright=tilt <= limits["maximum_torso_tilt_rad"],
        zero_bias_reference_path_feasible=all(leg["geometric_path_feasible"] for leg in legs))
    return dict(schema_version="sporespore_recovery_walking_readiness_v1", ready=all(checks.values()),
        checks=checks, ordered_legs=legs, horizontal_com_speed_m_s=speed, angular_speed_rad_s=angular,
        torso_tilt_rad=tilt, source_semantic_step=state["semantic_step"],
        reference_height_count=73, reference_geometry_is_contact_authority=False,
        future_contact_guaranteed=False, new_world_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def advance(memory, measurement, limits):
    """Count consecutive original completed samples, with a terminal timeout."""
    require(type(memory["commands"]) is int and 0 <= memory["commands"] < limits["maximum_commands"], "COMMAND_BOUND")
    require(type(memory["consecutive_ready"]) is int and 0 <= memory["consecutive_ready"] <= memory["commands"]
            and type(memory["last_source_step"]) is int and memory["last_source_step"] >= 1, "MEMORY")
    require(memory["outcome"] == "pending", "TERMINAL")
    require(type(measurement["ready"]) is bool, "READY_KIND")
    require(measurement["source_semantic_step"] == memory["last_source_step"]+1, "CONTIGUOUS_SAMPLE")
    count = memory["consecutive_ready"]+1 if measurement["ready"] else 0
    commands = memory["commands"]+1
    outcome = "ready" if count >= limits["ready_consecutive_completed_samples"] else "timeout" if commands == limits["maximum_commands"] else "pending"
    return dict(commands=commands, consecutive_ready=count, last_source_step=measurement["source_semantic_step"], outcome=outcome)
