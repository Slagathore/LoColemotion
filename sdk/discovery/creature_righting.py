"""Portable, untrained righting candidates for the shared creature discovery route.

This development controller owns no simulator and grants no recovery authority.
It binds the public recovery morphology, proposes bounded joint velocities from
canonical observations, and retains every measured limit breach. Native callers
own motor application; the existing recovery selector's gates are unchanged.
"""
import copy
import math

import numpy as np

from creature_batch import bridge, compile_creature, identifier, require
from actuation_recovery_mechanics import RigidTree, quaternion_rotation, xyz
from showcase_model import FIELDS, validate_descriptor
from sporespore_locomotion import r24d22_recovery_s169_morphology
import creature_righting_sequence as sequence
import creature_joint_braking as braking
import creature_contact_reach as contact_reach
import creature_body_moment as body_moment

SCHEMA = "locolemotion_creature_righting_population_v1"
ASSIGNED_SCHEMA = "locolemotion_creature_righting_assigned_population_v1"
EXPANDED = ("cells", "initial_lateral_velocities_m_s", "initial_roll_angles_rad", "righting_metadata")
SELECTION = dict(minimum_upright_dot=.95, minimum_height_ratio=.75,
    maximum_angular_speed_rad_s=.5, required_terminal_dwell_steps=300,
    maximum_joint_limit_violation_steps=0, shortlist_per_body_condition=2,
    minimum_mean_pose_distance=.15)
MOTION_FIELDS = {"feedback_axis_body", "feedback_polarity", "feedback_minimum_hold_steps",
                 "feedback_rate_deadband_rad_s", "feedback_requires_distal_contact"}


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def profile(value):
    require(type(value) is dict, "Righting profile object")
    if value.get("mode") == body_moment.MODE:
        return body_moment.profile(value)
    if value.get("mode") == contact_reach.MODE:
        return contact_reach.profile(value)
    if "joint_braking" in value:
        base = {k:v for k,v in value.items() if k != "joint_braking"}
        result = profile(base)
        require(result["mode"] != "zero_velocity_brake", "Joint braking requires an active pose controller")
        result["joint_braking"] = braking.policy(value["joint_braking"])
        return result
    if value.get("mode") == sequence.MODE:
        return sequence.profile(value)
    motion = value.get("mode") == "motion_rock"
    require(set(value) == {"id", "mode", "pose_a", "pose_b",
        "half_period_steps", "position_gain_s_inv", "maximum_speed_rad_s", "maximum_slew_rad_s_per_step"}
        | (MOTION_FIELDS if motion else set()),
        "Righting profile fields")
    require(identifier(value["id"]) and value["mode"] in ("zero_velocity_brake", "rock", "motion_rock"), "Righting profile identity")
    for key in ("pose_a", "pose_b"):
        require(type(value[key]) is list and len(value[key]) == 8
                and all(finite(v) and -.9 <= v <= .9 for v in value[key]), "Righting normalized pose bounds")
    require(type(value["half_period_steps"]) is int and 12 <= value["half_period_steps"] <= 240,
            "Righting phase bound")
    require(finite(value["position_gain_s_inv"]) and 1 <= value["position_gain_s_inv"] <= 12
            and finite(value["maximum_speed_rad_s"]) and 0 < value["maximum_speed_rad_s"] <= 3.5
            and finite(value["maximum_slew_rad_s_per_step"]) and 0 < value["maximum_slew_rad_s_per_step"] <= .2,
            "Righting command bounds")
    if value["mode"] == "zero_velocity_brake":
        require(value["pose_a"] == value["pose_b"] == [0.] * 8, "Righting brake carries a pose")
    if motion:
        axis = value["feedback_axis_body"]
        require(type(axis) is list and len(axis) == 3 and all(finite(v) for v in axis)
                and abs(sum(v*v for v in axis)-1.) <= 1e-12, "Righting feedback unit axis")
        require(type(value["feedback_polarity"]) is int and value["feedback_polarity"] in (-1, 1)
                and type(value["feedback_minimum_hold_steps"]) is int
                and 12 <= value["feedback_minimum_hold_steps"] < value["half_period_steps"]
                and finite(value["feedback_rate_deadband_rad_s"])
                and .01 <= value["feedback_rate_deadband_rad_s"] <= .5
                and type(value["feedback_requires_distal_contact"]) is bool, "Righting feedback bounds")
        require(sum(abs(a-b) for a, b in zip(value["pose_a"], value["pose_b"], strict=True))/8 >= .1,
                "Righting feedback poses do not differ")
    return copy.deepcopy(value)


def behavior_key(candidate):
    # Preserve the earlier duplicate rule; feedback variants must also bind
    # every parameter that changes their response to the same observation.
    if candidate["mode"] == body_moment.MODE:
        return body_moment.behavior_key(candidate)
    if candidate["mode"] == contact_reach.MODE:
        return contact_reach.behavior_key(candidate)
    if "joint_braking" in candidate:
        base = {k:v for k,v in candidate.items() if k != "joint_braking"}
        return behavior_key(base) + tuple(candidate["joint_braking"][k] for k in braking.FIELDS)
    if candidate["mode"] == sequence.MODE:
        return sequence.behavior_key(candidate)
    key = tuple(candidate["pose_a"] + candidate["pose_b"] + [candidate["half_period_steps"],
        candidate["position_gain_s_inv"], candidate["maximum_speed_rad_s"], candidate["maximum_slew_rad_s_per_step"]])
    if candidate["mode"] == "motion_rock":
        key += tuple(candidate["feedback_axis_body"]) + tuple(candidate[k] for k in
            ("feedback_polarity", "feedback_minimum_hold_steps", "feedback_rate_deadband_rad_s",
             "feedback_requires_distal_contact"))
    return key


def motion_phase(candidate, rotation, angular, bearing_contacts, phase, elapsed, upright):
    """Choose a bounded phase from measured body-frame rotation, without mutation."""
    require(type(angular) is dict and set(angular) == set("xyz")
            and all(finite(angular[k]) for k in "xyz"), "Righting feedback angular observation")
    body_velocity = rotation.T @ np.asarray([angular[k] for k in "xyz"])
    rate = float(np.dot(body_velocity, candidate["feedback_axis_body"]))
    signed = rate*candidate["feedback_polarity"]
    require(finite(rate) and finite(signed) and np.isfinite(body_velocity).all(), "Righting feedback finite rate")
    available = not candidate["feedback_requires_distal_contact"] or bearing_contacts > 0
    threshold = candidate["feedback_rate_deadband_rad_s"]
    desired = 0 if signed >= threshold else 1 if signed <= -threshold else phase
    selected = phase
    if upright:
        reason = "upright_stance"
    elif elapsed < candidate["feedback_minimum_hold_steps"]:
        reason = "minimum_hold"
    elif available and desired != phase:
        selected, reason = desired, "measured_rotation"
    elif elapsed >= candidate["half_period_steps"]:
        selected, reason = 1-phase, "bounded_fallback"
    else:
        reason = "waiting_for_contact" if not available else "deadband" if abs(signed) < threshold else "measured_hold"
    return dict(axis_body=copy.deepcopy(candidate["feedback_axis_body"]),
        body_angular_velocity_rad_s=body_velocity.tolist(), axis_angular_rate_rad_s=rate,
        signed_rate_rad_s=signed, bearing_distal_contacts=bearing_contacts, motion_available=available,
        phase_before=phase, hold_steps_before=elapsed, phase_after=selected,
        hold_steps_after=0 if upright else 1 if selected != phase else elapsed+1, selection_reason=reason)


def recovery_descriptor(descriptor):
    result = r24d22_recovery_s169_morphology()
    result["base_descriptor"] = copy.deepcopy(validate_descriptor(descriptor))
    result["recovery_morphology_id"] = "righting_" + descriptor["morphology_id"]
    return result


def expand(spec):
    assigned = type(spec) is dict and spec.get("schema_version") == ASSIGNED_SCHEMA
    require(type(spec) is dict and set(spec) == {"schema_version", "descriptors", "profiles", "conditions", "starts"}
            | ({"profiles_by_body"} if assigned else set())
            and spec["schema_version"] in (SCHEMA, ASSIGNED_SCHEMA), "Righting population fields")
    bodies, candidates, conditions, starts = [spec[k] for k in ("descriptors", "profiles", "conditions", "starts")]
    require(all(type(v) is list and v for v in (bodies, candidates, conditions, starts))
            and len(bodies) <= 64 and 2 <= len(candidates) <= 64 and len(conditions) <= 4
            and len(starts) <= 4,
            "Righting population budget")
    assignments = spec["profiles_by_body"] if assigned else [list(range(len(candidates))) for _ in bodies]
    require(type(assignments) is list and len(assignments) == len(bodies)
            and all(type(row) is list and len(row) >= 2 and row[:2] == [0, 1]
                    and all(type(i) is int and 0 <= i < len(candidates) for i in row)
                    and row == sorted(set(row)) for row in assignments)
            and set(i for row in assignments for i in row) == set(range(len(candidates)))
            and sum(map(len, assignments))*len(conditions)*len(starts) <= 256,
            "Righting assigned profiles or world budget")
    for body in bodies:
        validate_descriptor(body)
    require(len({tuple(b[k] for k in FIELDS) for b in bodies}) == len(bodies)
            and len({b["morphology_id"] for b in bodies}) == len(bodies), "Righting duplicate body")
    candidates = [profile(p) for p in candidates]
    require(candidates[0]["mode"] == "zero_velocity_brake"
            and all(p["mode"] in ("rock", "motion_rock", sequence.MODE, contact_reach.MODE, body_moment.MODE) for p in candidates[1:]), "Righting comparator population")
    for rows in (candidates, conditions, starts):
        require(all(identifier(r["id"]) for r in rows) and len({r["id"] for r in rows}) == len(rows),
                "Righting duplicate identity")
    require(len({behavior_key(p) for p in candidates}) == len(candidates),
        "Righting duplicated candidate behavior")
    for condition in conditions:
        require(set(condition) == {"id", "motor_effectiveness"} and type(condition["motor_effectiveness"]) is list
                and len(condition["motor_effectiveness"]) == 8
                and all(finite(v) and .5 <= v <= 1 for v in condition["motor_effectiveness"]), "Righting motor condition")
    require(len({tuple(v["motor_effectiveness"]) for v in conditions}) == len(conditions), "Righting duplicate condition")
    for start in starts:
        require(set(start) == {"id", "roll_rad"} and finite(start["roll_rad"])
                and -math.pi <= start["roll_rad"] <= math.pi, "Righting initial roll")
    require(len({s["roll_rad"] for s in starts}) == len(starts), "Righting duplicate start")
    cells, rolls, metadata = [], [], []
    for bi, body in enumerate(bodies):
        for ci, condition in enumerate(conditions):
            for si, start in enumerate(starts):
                for pi in assignments[bi]:
                    candidate = candidates[pi]
                    name = f"righting_body_{bi:02d}_condition_{ci}_start_{si}_candidate_{pi:02d}"
                    cells.append(dict(cell_id=name, descriptor=copy.deepcopy(body), profile=copy.deepcopy(candidate),
                                      motor_effectiveness=copy.deepcopy(condition["motor_effectiveness"])))
                    rolls.append(start["roll_rad"])
                    metadata.append(dict(cell_id=name, body_index=bi, body_id=body["morphology_id"],
                        condition_index=ci, condition_id=condition["id"], start_index=si, start_id=start["id"],
                        candidate_index=pi, candidate_id=candidate["id"]))
    return dict(cells=cells, initial_lateral_velocities_m_s=[0.] * len(cells),
                initial_roll_angles_rad=rolls, righting_metadata=metadata)


def verify_expansion(c):
    require(all(c[key] == value for key, value in expand(c["righting_spec"]).items()), "Righting expansion drift")
    require(c["righting_selection"] == SELECTION, "Righting selection contract")


def ground_clearance(creature, roll):
    """Exact box/capsule lower support at zero joint angles, without a world."""
    tree = RigidTree(creature["compiled"]["morphology"]["morphology_spec"])
    frame = tree.kinematics([0., 0., 0.], [math.sin(roll/2), 0., 0., math.cos(roll/2)], [0.] * 8)
    lows = []
    for body, position, rotation in zip(tree.bodies, frame["positions"], frame["rotations"], strict=True):
        shape = body["collision"]
        if shape["kind"] == "box":
            extent = float(np.abs(rotation[1]) @ (xyz(shape["size_m"])/2))
        else:
            require(shape["kind"] == "capsule", "Righting initializer collision shape")
            extent = abs(float(rotation[1, 1])) * shape["length_m"]/2 + shape["radius_m"]
        lows.append(float(position[1]) - extent)
    return min(lows)


def initial_arrays(creatures, rolls):
    require(len(creatures) == len(rolls) and all(finite(v) and -math.pi <= v <= math.pi for v in rolls),
            "Righting initial population")
    positions = []
    for creature, roll in zip(creatures, rolls, strict=True):
        # This is fresh initialization only. No running world may be reset here.
        height = .005 - ground_clearance(creature, roll)
        positions.append([0., 0., height, math.cos(roll/2), math.sin(roll/2), 0., 0.] + [0.] * 8)
    return np.asarray(positions, np.float32), np.zeros((len(creatures), 14), np.float32)


class RightingController:
    def __init__(self, core, declaration, *, seed):
        require(type(declaration) is dict and set(declaration) == {"cell_id", "descriptor", "profile", "motor_effectiveness"}
                and identifier(declaration["cell_id"]) and type(seed) is int and 0 <= seed <= 2147483647,
                "Righting cell fields")
        self.cell_id = declaration["cell_id"]
        self.candidate = profile(declaration["profile"])
        self.creature = compile_creature(core, declaration["descriptor"], declaration["motor_effectiveness"],
            recovery_descriptor=recovery_descriptor(declaration["descriptor"]))
        self.spec = self.creature["compiled"]["morphology"]["morphology_spec"]
        require([a["joint_id"] for a in self.spec["actuators"]] == self.creature["spec"]["ordered_joints"],
                "Righting motor order")
        self.previous, self.step_index, self.closed = [0.] * 8, 0, False
        self.motion_phase, self.motion_steps = 0, 0
        self.contact_state = None
        self.contact_geometry = contact_reach.LimbGeometry(self.spec) if self.candidate["mode"] == contact_reach.MODE else None
        self.sequence_state = None
        self.sequence_tree = RigidTree(self.spec) if self.candidate["mode"] == sequence.MODE else None
        self.moment_state = None
        self.moment_geometry = body_moment.Geometry(self.creature) if self.candidate["mode"] == body_moment.MODE else None

    @property
    def binding(self):
        return dict(copy.deepcopy(self.creature["binding"]), cell_id=self.cell_id, candidate_id=self.candidate["id"])

    def close(self):
        self.closed = True

    def plan(self, observation):
        require(not self.closed and type(observation) is dict and set(observation) == {
            "cell_id", "descriptor_sha256", "model_xml_sha256", "state", "stability", "kinematics"},
            "Righting observation fields or closed controller")
        require(all(observation[k] == self.binding[k] for k in ("cell_id", "descriptor_sha256", "model_xml_sha256")),
                "Crossed righting observation")
        state = observation["state"]
        require(type(state["semantic_step"]) is int and state["semantic_step"] == self.step_index
                and state["sample_time_s"] == self.step_index*bridge.CONTROLLER_DT_S, "Righting observation clock")
        joints = state["ordered_joint_observations"]
        require(len(joints) == 8 and [j["joint_id"] for j in joints] == self.creature["spec"]["ordered_joints"]
                and all(finite(j[k]) for j in joints for k in ("position_rad", "velocity_rad_s")),
                "Righting joint observation")
        q = state["base_pose_world"]["orientation_xyzw"]
        require(type(q) is dict and set(q) == set("xyzw"), "Righting root quaternion fields")
        rotation = quaternion_rotation([q[k] for k in "xyzw"])
        height = state["base_pose_world"]["position_m"]["y"]
        require(finite(height), "Righting root height")
        up = float(rotation[1, 1])
        sequential = self.candidate["mode"] == sequence.MODE
        contacting = self.candidate["mode"] == contact_reach.MODE
        moment = self.candidate["mode"] == body_moment.MODE
        phase = 0 if sequential or contacting or moment else (self.step_index // self.candidate["half_period_steps"]) % 2
        upright = up >= .9 and height >= .6*self.creature["compiled"]["geometry"]["initial_torso_center_y_m"]
        feedback, decision, contact_decision, moment_decision = None, None, None, None
        if self.candidate["mode"] == "motion_rock" or sequential or contacting or moment:
            contacts = state["ordered_contact_observations"]
            require(type(contacts) is list and len(contacts) == 4
                    and [v["contact_site_id"] for v in contacts] == [v["contact_site_id"] for v in self.spec["contact_sites"]]
                    and all(type(v[k]) is bool for v in contacts for k in ("presence", "bears_support"))
                    and all(not v["bears_support"] or v["presence"] for v in contacts), "Righting feedback contact population")
            if moment:
                moment_decision = body_moment.plan(self.candidate, self.moment_geometry, state, rotation,
                    contacts, self.moment_state, self.previous, upright)
            elif contacting:
                contact_decision = contact_reach.plan(self.candidate, self.contact_geometry, state, rotation,
                    contacts, self.contact_state, upright)
            elif sequential:
                decision = sequence.plan(self.candidate, self.sequence_tree, state, rotation,
                    sum(v["bears_support"] for v in contacts), self.sequence_state, upright)
            else:
                feedback = motion_phase(self.candidate, rotation, state["base_twist_world"]["angular_velocity_rad_s"],
                    sum(v["bears_support"] for v in contacts), self.motion_phase, self.motion_steps, upright)
                phase = feedback["phase_after"]
        normalized = (moment_decision["normalized_targets"] if moment else
            contact_decision["normalized_targets"] if contacting else
            decision["normalized_targets"] if sequential else
            [0.] * 8 if upright else self.candidate["pose_a" if phase == 0 else "pose_b"])
        commands, targets, breaches = [], [], []
        for i, (joint, motor, observed, value) in enumerate(zip(self.spec["joints"], self.spec["actuators"], joints, normalized, strict=True)):
            lo, hi, actual = joint["lower_limit_rad"], joint["upper_limit_rad"], observed["position_rad"]
            require(lo < 0 < hi, "Righting zero stance outside limits")
            target = value*(hi if value >= 0 else -lo)
            speed = min(motor["maximum_target_speed_rad_s"], self.candidate["maximum_speed_rad_s"])
            proposal = 0. if self.candidate["mode"] == "zero_velocity_brake" else self.candidate["position_gain_s_inv"]*(target-actual)
            if moment:
                proposal = moment_decision["proposed_velocities_rad_s"][i]
            bounded = max(-speed, min(speed, proposal))
            slew = self.candidate["maximum_slew_rad_s_per_step"]
            slewed = max(self.previous[i]-slew, min(self.previous[i]+slew, bounded))
            protection = None
            shaped = slewed
            if "joint_braking" in self.candidate:
                protection = braking.shape(actual, observed["velocity_rad_s"], slewed,
                    speed, lo, hi, bridge.CONTROLLER_DT_S, self.candidate["joint_braking"])
                shaped = protection["shaped_velocity_rad_s"]
            # Joint protection overrides slew. Keep the original observed-bound
            # rule after the optional prediction; prediction is not a guarantee.
            final = max(min(0., (lo-actual)/bridge.CONTROLLER_DT_S),
                        min(max(0., (hi-actual)/bridge.CONTROLLER_DT_S), shaped))
            breaches.append(not lo <= actual <= hi)
            targets.append(final)
            commands.append(dict(actuator_id=motor["actuator_id"], joint_id=joint["joint_id"],
                target_position_rad=target, proposed_velocity_rad_s=proposal,
                canonical_velocity_rad_s=final, maximum_speed_rad_s=speed,
                speed_limited=bounded != proposal, slew_limited=slewed != bounded,
                joint_guard_applied=final != slewed, observed_joint_limit_breach=breaches[-1]))
            if protection is not None:
                commands[-1]["anticipatory_joint_braking"] = protection
        record = dict(binding=self.binding, request=dict(state=copy.deepcopy(state)),
            stability=copy.deepcopy(observation["stability"]), kinematics=copy.deepcopy(observation["kinematics"]),
            resolution=dict(schema_version="locolemotion_righting_commands_v1", safe_no_actuation=False,
                mode=self.candidate["mode"], phase="upright_stance" if upright else f"rock_{phase}",
                observed_up_dot=up, observed_joint_limit_breaches=breaches, ordered_commands=commands,
                previous_canonical_velocities_rad_s=copy.deepcopy(self.previous),
                trained=False, physical_acceptance_authority=False, release_authority=False),
            native_targets=targets)
        if feedback is not None:
            record["resolution"]["motion_feedback"] = feedback
        if decision is not None:
            record["resolution"].update(phase=decision["phase_id"], sequence=decision)
        if contact_decision is not None:
            record["resolution"].update(phase=contact_decision["phase"], contact_reach=contact_decision)
        if moment_decision is not None:
            moment_decision["post_guard_predicted_torque_nm"] = body_moment.mechanics.motor_torque(
                targets, [j["velocity_rad_s"] for j in joints], self.creature["spec"]["velocity_gains"],
                self.creature["spec"]["force_ranges"]).tolist()
            record["resolution"].update(phase=moment_decision["phase"], body_moment=moment_decision)
        return record

    def commit(self, record):
        self.previous = copy.deepcopy(record["native_targets"])
        if self.candidate["mode"] == "motion_rock":
            feedback = record["resolution"]["motion_feedback"]
            self.motion_phase, self.motion_steps = feedback["phase_after"], feedback["hold_steps_after"]
        if self.candidate["mode"] == sequence.MODE:
            self.sequence_state = copy.deepcopy(record["resolution"]["sequence"]["state_after"])
        if self.candidate["mode"] == contact_reach.MODE:
            self.contact_state = copy.deepcopy(record["resolution"]["contact_reach"]["state_after"])
        if self.candidate["mode"] == body_moment.MODE:
            self.moment_state = copy.deepcopy(record["resolution"]["body_moment"]["state_after"])
        self.step_index += 1

    def step(self, observation):
        record = self.plan(observation)
        self.commit(record)
        return record


class RightingBatch:
    """Atomic host planning for independent native GPU cells; no physics calls."""
    def __init__(self, core, declarations, *, seed):
        require(type(declarations) is list and 1 <= len(declarations) <= 256
                and len({r["cell_id"] for r in declarations}) == len(declarations), "Righting batch population")
        self.controllers, self.closed = [], False
        try:
            for row in declarations:
                self.controllers.append(RightingController(core, row, seed=seed))
        except BaseException:
            self.close()
            raise

    @property
    def bindings(self):
        return [cell.binding for cell in self.controllers]

    def close(self):
        for cell in self.controllers:
            cell.close()
        self.closed = True

    def step(self, observations):
        require(not self.closed and type(observations) is list and len(observations) == len(self.controllers),
                "Righting batch observation denominator or closed")
        rows = [c.plan(o) for c, o in zip(self.controllers, observations, strict=True)]
        for cell, row in zip(self.controllers, rows, strict=True):
            cell.commit(row)
        return rows


def initial_metrics():
    return dict(terminal_upright_dwell_steps=0, longest_upright_dwell_steps=0,
                joint_limit_violation_steps=0, final_up_dot=0., final_height_ratio=0., final_angular_speed_rad_s=0.)


def measure(metric, row, creature):
    q, v = row["qpos"], row["qvel"]
    up = 1-2*(q[4]**2+q[5]**2)
    ratio = q[2]/creature["compiled"]["geometry"]["initial_torso_center_y_m"]
    speed = math.sqrt(sum(x*x for x in v[3:6]))
    safe = all(j["lower_limit_rad"] <= actual <= j["upper_limit_rad"]
               for j, actual in zip(creature["compiled"]["morphology"]["morphology_spec"]["joints"], q[7:], strict=True))
    distal_ids = [creature["spec"]["geom_names"].index(site["body_id"]+"_geom")
                  for site in creature["compiled"]["morphology"]["morphology_spec"]["contact_sites"]]
    supported = all(any(set(hit["geom"]) == {0, geom} for hit in row["contacts"]) for geom in distal_ids)
    torso_clear = not any(1 in hit["geom"] for hit in row["contacts"])
    upright = up >= SELECTION["minimum_upright_dot"] and ratio >= SELECTION["minimum_height_ratio"]
    dwell = metric["terminal_upright_dwell_steps"]+1 if upright and safe and supported and torso_clear and speed <= SELECTION["maximum_angular_speed_rad_s"] else 0
    metric.update(terminal_upright_dwell_steps=dwell,
        longest_upright_dwell_steps=max(metric["longest_upright_dwell_steps"], dwell),
        joint_limit_violation_steps=metric["joint_limit_violation_steps"]+int(not safe),
        final_up_dot=up, final_height_ratio=ratio, final_angular_speed_rad_s=speed)


def assess(c, metrics, bindings):
    verify_expansion(c)
    require(len(metrics) == len(bindings) == len(c["cells"])
            and [b["cell_id"] for b in bindings] == [v["cell_id"] for v in c["cells"]], "Righting assessment population")
    episodes, groups = [], {}
    for meta, metric, binding in zip(c["righting_metadata"], metrics, bindings, strict=True):
        require(all(k in metric and finite(metric[k]) for k in initial_metrics()), "Righting finite metrics")
        for key in ("terminal_upright_dwell_steps", "longest_upright_dwell_steps", "joint_limit_violation_steps"):
            require(type(metric[key]) is int and 0 <= metric[key] <= c["outer_steps"]*5, "Righting metric count")
        require(metric["terminal_upright_dwell_steps"] <= metric["longest_upright_dwell_steps"], "Righting dwell summary")
        failures = []
        if metric["terminal_upright_dwell_steps"] < SELECTION["required_terminal_dwell_steps"]:
            failures.append("no_terminal_supported_upright_dwell")
        if metric["joint_limit_violation_steps"]:
            failures.append("joint_limit_violation")
        row = dict(meta, body_shape_sha256=binding["body_shape_sha256"], eligible=not failures,
                   failure_codes=failures, metrics=copy.deepcopy(metric))
        episodes.append(row)
        groups.setdefault((meta["body_index"], meta["condition_index"]), []).append(row)
    shortlists = []
    for (body, condition), rows in groups.items():
        candidates = []
        assigned = c["righting_spec"].get("profiles_by_body")
        indices = assigned[body] if assigned is not None else range(len(c["righting_spec"]["profiles"]))
        for pi in indices:
            profile_row = c["righting_spec"]["profiles"][pi]
            selected = [r for r in rows if r["candidate_index"] == pi]
            require(len(selected) == len(c["righting_spec"]["starts"]), "Righting missing start")
            if pi and all(r["eligible"] for r in selected):
                candidates.append(dict(candidate_id=profile_row["id"], candidate_index=pi,
                    minimum_terminal_dwell_steps=min(r["metrics"]["terminal_upright_dwell_steps"] for r in selected)))
        candidates.sort(key=lambda r: (-r["minimum_terminal_dwell_steps"], r["candidate_index"]))
        diverse = []
        def distance(left, right):
            a, b = [c["righting_spec"]["profiles"][r["candidate_index"]] for r in (left, right)]
            if body_moment.MODE in (a["mode"], b["mode"]):
                # Dynamic targets have no fixed pose pair. Retain at most one
                # per axis/strategy family, without inventing a pose distance.
                return 0. if all(a.get(k) == b.get(k) for k in ("mode","axis_body","strategy","handoff")) else 1.
            poses = lambda p: [r["pose"] for r in p["phases"]] if p["mode"] == sequence.MODE else [p["pose_a"], p["pose_b"]]
            aa, bb = poses(a), poses(b)
            n = math.lcm(len(aa), len(bb))
            return sum(abs(x-y) for i in range(n) for x, y in zip(
                aa[i*len(aa)//n], bb[i*len(bb)//n], strict=True))/(8*n)
        for candidate in candidates:
            if all(distance(candidate, other) >= SELECTION["minimum_mean_pose_distance"] for other in diverse):
                diverse.append(candidate)
            if len(diverse) == SELECTION["shortlist_per_body_condition"]:
                break
        shortlists.append(dict(body_index=body, condition_index=condition,
            candidates=diverse))
    return dict(episodes=episodes, shortlists=shortlists, eligible_worlds=sum(r["eligible"] for r in episodes),
        failed_worlds=sum(not r["eligible"] for r in episodes), trained=False,
        recovery_qualified=False, training_data_authority=False, physical_acceptance_authority=False, release_authority=False)
