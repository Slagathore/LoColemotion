"""Measure finite recovery walking from native body/contact records.

This shared component has no campaign or acceptance authority. The caller must
first verify the complete retained worker and independent native replay. Foot
geometry is calculated from measured body poses and compiled contact sites;
controller-reported endpoints and success flags are not measurement inputs.
"""
import math

LIMBS = ("front_left", "front_right", "rear_left", "rear_right")
AXES = "xyz"


def require(value, code):
    if not value:
        raise ValueError("FINITE_RECOVERY_WALKING_" + code)


def vector(value):
    require(isinstance(value, dict), "VECTOR")
    result = tuple(value.get(k) for k in AXES)
    require(all(type(v) in (int, float) and math.isfinite(v) for v in result), "FINITE_VECTOR")
    return result


def rotate(q, v):
    values = tuple(q.get(k) for k in "xyzw")
    require(all(type(x) in (int, float) and math.isfinite(x) for x in values), "QUATERNION")
    require(abs(sum(x*x for x in values) - 1) <= 1e-6, "UNIT_QUATERNION")
    x, y, z, w = values
    # Quaternion rotation, independently expressed without the controller code.
    t = (2*(y*v[2]-z*v[1]), 2*(z*v[0]-x*v[2]), 2*(x*v[1]-y*v[0]))
    cross = (y*t[2]-z*t[1], z*t[0]-x*t[2], x*t[1]-y*t[0])
    return tuple(v[i] + w*t[i] + cross[i] for i in range(3))


def measured_endpoints(row, sites):
    bodies = row["request"]["measured_body_frame"]["ordered_body_states"]
    require(len(bodies) == 9 and len({b["body_id"] for b in bodies}) == 9, "BODY_POPULATION")
    by_id = {b["body_id"]: b for b in bodies}
    result = {}
    for limb, site in zip(LIMBS, sites):
        require(site["contact_site_id"] == limb + "_foot" and site["body_id"] == limb + "_distal", "SITE_IDENTITY")
        pose = by_id[site["body_id"]]["pose_world"]
        position = vector(pose["position_m"])
        offset = rotate(pose["orientation_xyzw"], vector(site["local_center_m"]))
        result[limb] = tuple(position[i]+offset[i] for i in range(3))
    return result


def measure(report, compiled, contract):
    """Return additional component measurements, never regrade the source run."""
    require(compiled["descriptor"] == report["configuration"]["base_descriptor"], "DESCRIPTOR")
    sites = compiled["morphology"]["morphology_spec"]["contact_sites"]
    require(len(sites) == 4, "CONTACT_SITE_POPULATION")
    phase_order = contract["controller_composition"]["ordered_native_limb_memory_ids"]
    require(len(phase_order) == 4 and set(phase_order) == set(LIMBS), "NATIVE_LIMB_ORDER")
    phase_offsets = {limb: i*90 for i, limb in enumerate(phase_order)}
    rows = report["development_walking_entry"]["rows"]
    posts = report["development_cycle_stop"]["rows"]
    require(len(rows) == len(posts) and len(rows) > 0, "TRACE_POPULATION")
    limits, observable, tail = (contract[k] for k in ("limits", "finite_walking_observable", "settled_tail"))
    # R10K names the bound independently of the V50 predecessor. Select its
    # declared schema explicitly; numerical limits and measurements stay shared.
    maximum_key = ("maximum_walking_commands" if contract.get("schema_version") in
                   ("sporespore_r10ap_progressive_headroom_finite_cycle_contract_v1",
                    "sporespore_r10am_support_anchored_finite_cycle_contract_v1",
                    "sporespore_r10aj_hip_recenter_finite_cycle_contract_v1",
                    "sporespore_r10ai_concurrent_load_rise_finite_cycle_contract_v1",
                    "sporespore_r10ag_detection_frame_load_seeking_finite_cycle_contract_v1",
                    "sporespore_r10k_partial_fall_finite_cycle_contract_v1",
                    "sporespore_r10l_extended_support_transfer_finite_cycle_contract_v1",
                    "sporespore_r10m_bounded_stop_velocity_finite_cycle_contract_v1",
                    "sporespore_r10n_zero_velocity_brake_finite_cycle_contract_v1",
                    "sporespore_r10o_initialized_zero_brake_finite_cycle_contract_v1",
                    "sporespore_r10q_upright_finite_cycle_contract_v1", "sporespore_r10r_upright_finite_cycle_contract_v1", "sporespore_r10r_upright_finite_cycle_contract_v2", "sporespore_r10s_extended_preparation_finite_cycle_contract_v1", "sporespore_r10t_post_recovery_settling_finite_cycle_contract_v1", "sporespore_r10u_post_recovery_settling_finite_cycle_contract_v2", "sporespore_r10v_post_recovery_settling_finite_cycle_contract_v2", "sporespore_r10y_partial_direct_neutral_finite_cycle_contract_v1", "sporespore_r10z_partial_pose_geometry_finite_cycle_contract_v1", "sporespore_r10aa_partial_load_seeking_finite_cycle_contract_v1", "sporespore_r10ab_partial_downward_rise_finite_cycle_contract_v1", "sporespore_r10ab_partial_downward_rise_finite_cycle_contract_v2") else "maximum_v50_walking_commands")
    require(len(rows) <= limits[maximum_key] + limits["stopping_commands"], "HORIZON")
    points = [measured_endpoints(row, sites) for row in rows]
    base = rows[0]["request"]["state"]["base_pose_world"]
    heading = rotate(base["orientation_xyzw"], (0., 0., 1.))
    norm = math.hypot(heading[0], heading[2])
    require(norm > 1e-9, "HEADING")
    forward = (heading[0]/norm, 0., heading[2]/norm)
    releases, absent, completed = {}, {}, {}
    flight_run, longest_flight = dict.fromkeys(LIMBS, 0), dict.fromkeys(LIMBS, 0)
    bearing_history, presence_history, settled_history, planned_history = [], [], [], []
    floor = rows[0]["request"]["floor_reference"]["height_world_m"]
    require(type(floor) in (int, float) and math.isfinite(floor), "FLOOR")
    cycle_end = 0
    global_origin = rows[0]["commanded_global_step"] - 1
    for n, (row, post) in enumerate(zip(rows, posts), 1):
        require(n == row["session_local_step"] == post["session_local_step"] == row["request"]["state"]["semantic_step"], "LOCAL_CLOCK")
        require(row["commanded_global_step"] == global_origin+n and row["measured_global_step"] == global_origin+n-1, "GLOBAL_CLOCK")
        require(row["full_step_receipt_sha256"] == post["full_step_receipt_sha256"], "STEP_BINDING")
        source = post["post_native_source"]
        observation = source["observation"]
        require(observation["semantic_step"] == source["precommand_trace"]["global_semantic_step"] == global_origin+n, "POST_CLOCK")
        contacts = observation["state"]["ordered_contact_observations"]
        require(len(contacts) == 4, "CONTACT_POPULATION")
        bearing = {}
        for limb, contact in zip(LIMBS, contacts):
            require(contact["contact_site_id"] == limb+"_foot" and type(contact["presence"]) is bool and type(contact["bears_support"]) is bool, "KNOWN_CONTACT")
            bearing[limb] = contact["presence"] and contact["bears_support"]
        bearing_history.append(bearing)
        presence_history.append({limb: contact["presence"] for limb, contact in zip(LIMBS, contacts)})
        velocity = vector(observation["center_of_mass"]["linear_velocity_world_m_s"])
        omega = vector(observation["state"]["base_twist_world"]["angular_velocity_rad_s"])
        tilt = source["precommand_trace"]["torso_tilt_rad"]
        require(type(tilt) in (int, float) and math.isfinite(tilt), "TILT")
        require(observation["center_of_mass"]["source_measurement"] is True, "COM_SOURCE")
        settled_history.append(all(bearing.values()) and math.hypot(velocity[0], velocity[2]) <= tail["maximum_horizontal_com_speed_m_s"]
            and math.sqrt(sum(v*v for v in omega)) <= tail["maximum_torso_angular_speed_rad_s"] and tilt <= tail["maximum_torso_tilt_rad"])
        output = row["native_output"]
        transfer = output["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]
        planned = transfer["planned_swing_limb_id"]
        require(planned is None or planned in LIMBS, "PLANNED_LIMB")
        require(type(transfer["preparation_released_this_command"]) is bool, "KNOWN_RELEASE")
        planned_history.append(planned)
        require(type(row["development_cycle_stopping"]) is bool and row["development_cycle_stopping"] == (cycle_end > 0), "STOP_BOUNDARY")
        if cycle_end:
            continue
        memory = output["next_memory"]["ordered_limb_memory"]
        require(len(memory) == 4 and {m["limb_id"] for m in memory} == set(LIMBS), "LIMB_MEMORY")
        require([m["limb_id"] for m in memory] == phase_order, "NATIVE_PHASE_ORDER")
        # Godot retains these C ABI counts as integral binary64 values. Validate
        # the numeric domain; never rewrite the original retained memory.
        require(all(type(m["gait_step"]) in (int, float) and math.isfinite(m["gait_step"])
            and m["gait_step"] >= 0 and m["gait_step"] == int(m["gait_step"]) for m in memory), "GAIT_CLOCK")
        clocks = {m["limb_id"]: int(m["gait_step"]) for m in memory}
        phases = {limb: (clocks[limb] + 360-phase_offsets[limb]) % 360 for limb in LIMBS}
        if transfer["preparation_released_this_command"]:
            require(planned in LIMBS, "RELEASE_LIMB")
            releases.setdefault(planned, n)
        for limb in LIMBS:
            in_flight = limb in releases and limb not in completed and phases[limb] <= 72 and not bearing[limb]
            flight_run[limb] = flight_run[limb]+1 if in_flight else 0
            longest_flight[limb] = max(longest_flight[limb], flight_run[limb])
            if in_flight:
                absent.setdefault(limb, n)
            if limb in absent and phases[limb] > 72 and bearing[limb]:
                completed.setdefault(limb, n)
        if len(completed) == 4 and all(phases[limb] > 72 and bearing[limb] for limb in LIMBS):
            cycle_end = n

    def displacement(first, last, limb):
        # Command n+1's premeasurement is command n's postmeasurement.
        if first >= len(points) or last is None or last >= len(points):
            return None
        return sum((points[last][limb][i]-points[first][limb][i])*forward[i] for i in range(3))

    cycles = [dict(limb_id=limb, release_command=releases.get(limb), first_absent_command=absent.get(limb),
        first_supported_stance_command=completed.get(limb), maximum_consecutive_absent_samples=longest_flight[limb],
        measured_endpoint_forward_m=displacement(absent[limb], completed[limb], limb) if limb in completed else None) for limb in LIMBS]
    episodes = []
    for limb_index, limb in enumerate(LIMBS):
        first = None
        for n, bearing in enumerate(bearing_history, 1):
            if not bearing[limb] and first is None:
                first = n
            elif bearing[limb] and first is not None:
                episodes.append(dict(limb_id=limb, first_absent_command=first, first_bearing_command=n,
                    absent_samples=n-first, required_support_at_onset=planned_history[first-1] != limb,
                    measured_endpoint_forward_m=displacement(first, n, limb),
                    native_presence_absent_samples=sum(not p[limb] for p in presence_history[first-1:n-1]),
                    present_without_support_samples=sum(p[limb] for p in presence_history[first-1:n-1]),
                    maximum_nominal_gap_m=max(points[j][limb][1]-floor-sites[limb_index]["radius_m"] for j in range(first, n)) if n < len(points) else None))
                first = None
        if first is not None:
            episodes.append(dict(limb_id=limb, first_absent_command=first, first_bearing_command=None,
                absent_samples=len(rows)+1-first, required_support_at_onset=planned_history[first-1] != limb,
                measured_endpoint_forward_m=None, maximum_nominal_gap_m=None,
                native_presence_absent_samples=sum(not p[limb] for p in presence_history[first-1:]),
                present_without_support_samples=sum(p[limb] for p in presence_history[first-1:])))
    cycle_passed = all(c["first_supported_stance_command"] is not None and c["maximum_consecutive_absent_samples"] >= observable["minimum_consecutive_native_absence_samples"]
        and c["measured_endpoint_forward_m"] is not None and c["measured_endpoint_forward_m"] >= observable["minimum_measured_forward_endpoint_advance_m"] for c in cycles)
    stop_count = len(rows)-cycle_end if cycle_end else 0
    initial_position = vector(base["position_m"])
    final_position = vector(posts[-1]["post_native_source"]["observation"]["state"]["base_pose_world"]["position_m"])
    body_advance = sum((final_position[i]-initial_position[i])*forward[i] for i in range(3))
    return dict(schema_version="sporespore_finite_recovery_walking_measurement_v1", scope="component_measurement_only",
        command_count=len(rows), cycle_end_command=cycle_end, stopping_commands=stop_count, planned_cycles=cycles,
        pre_first_to_post_last_body_forward_m=body_advance,
        body_forward_predicate=body_advance >= observable["minimum_forward_body_advance_m"],
        all_contact_loss_episodes=episodes, planned_cycle_predicate=cycle_passed,
        complete_stop_predicate=stop_count == limits["stopping_commands"] and all(settled_history[-limits["settled_tail_commands"]:]),
        source_run_regraded=False, physical_acceptance_authority=False, release_authority=False,
        new_world_count=0, new_solver_step_count=0)
