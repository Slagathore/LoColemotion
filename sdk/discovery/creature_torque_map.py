"""Pose and force proposals constrained by the measured joint-torque map.

Row-space forces are a declared model choice, not measured ground reaction.
Other canonical foot contacts receive bounded zero-torque requests. Torso and
upper-link reactions are outside that contact interface and remain unmodeled.
"""
import copy

import numpy as np

import creature_body_moment as moment
from creature_batch import require
from creature_support_sharing import guarded_envelope, STATIC_RESERVE
from creature_support_sharing_bounds import bounded_load_scale

DEFAULT_POLICY = dict(schema_version="locolemotion_torque_map_v1", pose_score="bounded_moment",
                      normalization="moment", contact_set="all")


def policy(value):
    require(type(value) is dict and set(value) == set(DEFAULT_POLICY)
            and value["schema_version"] == DEFAULT_POLICY["schema_version"]
            and value["pose_score"] in ("visible_arm", "bounded_moment")
            and value["normalization"] in ("moment", "load")
            and value["contact_set"] in ("primary", "all"), "Torque-map policy fields")
    return copy.deepcopy(value)


def cone_force(linear, lever, up, friction):
    """Maximize lever.F with F.up=1, |F-up|<=mu and F in range(J).

    Supports a batch of 3-by-2 linear Jacobians, including rank zero and one.
    The minimum-length unit-normal force is P.up/(up.P.up). Remaining force
    lies in the row-space plane perpendicular to up; its radius follows from
    the friction cone. An empty intersection is reported, never clipped valid.
    """
    raw = np.asarray(linear)
    require(raw.ndim >= 2 and raw.shape[-2:] == (3, 2), "Torque-map Jacobian shape")
    linear = moment.mechanics.array(raw, raw.shape, "Torque-map finite Jacobian")
    lever = moment.mechanics.array(lever, raw.shape[:-2]+(3,), "Torque-map lever")
    up = moment.mechanics.array(up, (3,), "Torque-map up")
    require(abs(float(up @ up)-1.) <= 1e-12 and moment.finite(friction) and 0. <= friction <= .95,
            "Torque-map unit normal or friction")
    basis, singular, _ = np.linalg.svd(linear, full_matrices=False)
    visible = singular > np.maximum(singular[..., :1], 1.)*1e-10
    projector = np.einsum("...ij,...j,...kj->...ik", basis, visible, basis)
    projected_up = projector @ up
    length2 = np.sum(projected_up*up, axis=-1)
    inverse = np.divide(1., length2, out=np.zeros_like(length2), where=length2>1e-14)
    feasible = (length2>1e-14) & (inverse <= 1.+friction*friction+1e-12)
    minimum = projected_up*inverse[..., None]
    tangent = (projector @ lever[..., None])[..., 0]-projected_up*np.sum(minimum*lever, axis=-1)[..., None]
    tangent_length = np.linalg.norm(tangent, axis=-1)
    radius = np.sqrt(np.maximum(0., 1.+friction*friction-inverse))
    direction = minimum+tangent*np.divide(radius, tangent_length,
                         out=np.zeros_like(radius), where=tangent_length>1e-12)[..., None]
    direction = np.where(feasible[..., None], direction, 0.)
    require(np.all(np.abs(direction @ up-np.where(feasible, 1., 0.)) <= 1e-9)
            and np.all(np.linalg.norm(direction-(direction @ up)[..., None]*up, axis=-1)
                       <= np.where(feasible, friction, 0.)+1e-9)
            and np.all(np.linalg.norm((projector @ direction[..., None])[..., 0]-direction, axis=-1)<=1e-9),
            "Torque-map cone construction")
    return dict(direction=direction, moment_arm=np.sum(lever*direction, axis=-1),
                feasible=feasible, rank=np.sum(visible, axis=-1), projector=projector)


def load_intervals(gravity, contact, bounds):
    """Vectorized affine bounds for target ranking; execution uses the scalar reader."""
    lower = np.zeros(gravity.shape[:-1]); upper = np.ones_like(lower)
    valid = np.ones(lower.shape, dtype=bool)
    for joint in range(2):
        offset, slope = -gravity[..., joint], -contact[..., joint]
        lo, hi = bounds[..., joint, 0], bounds[..., joint, 1]
        a = np.divide(lo-offset, slope, out=np.zeros_like(offset), where=slope!=0.)
        b = np.divide(hi-offset, slope, out=np.ones_like(offset), where=slope!=0.)
        valid &= (slope!=0.) | ((offset>=lo) & (offset<=hi))
        lower = np.maximum(lower, np.minimum(a, b)); upper = np.minimum(upper, np.maximum(a, b))
    return lower, upper, valid & (lower<=upper)


def normal_request(p, weight, length, arms, count):
    budget = weight*p["normal_load_ratio"]/count
    if p["torque_map"]["normalization"] == "load":
        return np.broadcast_to(budget, np.shape(arms))
    return np.minimum(budget, weight*length*p["moment_weight_length_ratio"]/np.maximum(arms, 1e-12))


class Geometry(moment.Geometry):
    def __init__(self, creature, configuration, *, base=None):
        if base is None:
            super().__init__(creature)
        else:
            self.__dict__.update(base.__dict__)
        self.configuration = policy(configuration)
        model, tree = self.bank.geometry, self.tree
        self.anchors = np.stack([model.positions[:, tree.parent[i]]
            +model.rotations[:, tree.parent[i]] @ moment.mechanics.xyz(j["anchor_parent_m"])
            for i,j in enumerate(tree.joints)], axis=1)
        self.axes = np.stack([model.rotations[:, tree.parent[i]] @ moment.mechanics.xyz(j["axis_parent_unit"])
            for i,j in enumerate(tree.joints)], axis=1)
        centers = model.positions+np.einsum("nbij,bj->nbi", model.rotations, tree.local_com)
        self.gravity_coefficients = np.zeros_like(self.axes)
        for body in range(len(tree.bodies)):
            for joint in tree.ancestors[body]:
                self.gravity_coefficients[:, joint] += tree.mass[body]*np.cross(
                    self.axes[:, joint], centers[:, body]-self.anchors[:, joint])
        for value in (self.anchors, self.axes, self.gravity_coefficients):
            value.setflags(write=False)

    def target(self, position, rotation, current, axis, p):
        p = dict(p, torque_map=self.configuration)
        up, bank = rotation[1], self.bank
        low = bank.points @ up-bank.radii
        feature = self.features[np.arange(4), np.argmin(low[:, self.features], axis=2)]
        rows = np.arange(len(low))[:, None]
        points = bank.points[rows, feature]-bank.radii[feature, None]*up
        linear = np.stack([np.cross(self.axes[:, j::2], points-self.anchors[:, j::2])
                           for j in (0, 1)], axis=-1)
        forces = cone_force(linear, np.cross(axis, points-bank.geometry.com[:, None]), up, p["friction_ratio"])
        arms = forces["moment_arm"]
        normal = normal_request(p, self.weight, self.length, arms, 1)
        contact = np.einsum("...ij,...i->...j", linear, forces["direction"])*normal[..., None]
        gravity = (-9.81*(self.gravity_coefficients @ up)).reshape(-1, 4, 2)
        bounds = np.asarray(self.creature["spec"]["force_ranges"]).reshape(1, 4, 2, 2)
        lower, upper, valid = load_intervals(gravity, contact, bounds)
        bounded = normal*np.maximum(lower, STATIC_RESERVE*upper)
        height = low[rows, feature]
        possible = height <= np.min(low, axis=1)[:, None]+.01
        normalized = np.where(current>=0., current/self.upper, -current/self.lower)
        distance = np.mean(np.abs(bank.geometry.poses-normalized), axis=1)
        score = arms if self.configuration["pose_score"] == "visible_arm" else bounded*arms/self.weight
        score = score-2.*np.abs(position[1]+height)-p["pose_distance_weight_m"]*distance[:, None]
        valid &= possible & forces["feasible"] & (arms>1e-9) & (upper>0.)
        score = np.where(valid, score, -np.inf)
        if not np.isfinite(score).any():
            return dict(super().target(position, rotation, current, axis, p),
                        torque_map_target=False, torque_map_fallback="no_positive_cone_pose")
        selected, limb = divmod(int(np.argmax(score)), 4)
        return dict(bank_index=selected, pool_index=int(self.pool_indices[selected]), limb=limb,
            normalized_targets=bank.geometry.poses[selected].tolist(),
            target_nonadjacent_gap_m=float(bank.minimum_gap[selected]),
            predicted_contact_clearance_m=float(position[1]+height[selected, limb]),
            proposed_moment_arm_m=float(arms[selected, limb]), target_score_m=float(score[selected, limb]),
            torque_map_target=True, torque_map_rank=int(forces["rank"][selected, limb]),
            proposed_direction_body=forces["direction"][selected, limb].tolist(),
            proposed_bounded_normal_n=float(bounded[selected, limb]),
            static_scale_interval=[float(lower[selected, limb]), float(upper[selected, limb])])


def plan(p, g, state, rotation, contacts, memory, previous, upright):
    require(g.configuration == p["torque_map"], "Torque-map geometry policy binding")
    base = {k:v for k,v in p.items() if k != "torque_map"}
    result = moment.plan(base, g, state, rotation, contacts, memory, previous, upright)
    present = [i for i,c in enumerate(contacts) if c["presence"]]
    info = dict(policy=p["torque_map"], measured_contact_limbs=present, active_limbs=[], quiet_limbs=[],
                forces_are_measured=False, torso_reactions_modeled=False, recovery_benefit_established=False)
    result["torque_map"] = info
    if upright:
        info["reason"] = "upright_stance"
        return result
    q = np.asarray([j["position_rad"] for j in state["ordered_joint_observations"]])
    velocity = np.asarray([j["velocity_rad_s"] for j in state["ordered_joint_observations"]])
    pose = state["base_pose_world"]
    frame = g.tree.kinematics(moment.mechanics.xyz(pose["position_m"]),
                             [pose["orientation_xyzw"][k] for k in "xyzw"], q)
    points, gap = g.measured(frame)
    axis = rotation @ (np.asarray(p["axis_body"])*result["state_after"]["sign"])
    linear = np.stack([g.tree.jacobian(frame, g.tree.body_ids[g.bank.distal[i]], points[i])[0][:, 2*i:2*i+2]
                       for i in range(4)])
    forces = cone_force(linear, np.cross(axis, points-frame["whole_body_com"]), np.array([0., 1., 0.]), p["friction_ratio"])
    eligible = sorted((i for i in present if forces["feasible"][i] and forces["moment_arm"][i]>1e-9),
                      key=lambda i:(-forces["moment_arm"][i], i))
    selected = eligible[:1] if p["torque_map"]["contact_set"] == "primary" else eligible
    envelope = guarded_envelope(p, g, q, velocity, previous)
    gains, ranges = g.creature["spec"]["velocity_gains"], np.asarray(g.creature["spec"]["force_ranges"])
    lo, hi = moment.mechanics.torque_envelope(envelope, velocity, gains, ranges)
    gravity = g.tree.gravity_torques(frame, [0., -9.81, 0.])
    wrenches, active, requests = [], [], []
    normal = float(normal_request(p, g.weight, g.length, sum(forces["moment_arm"][i] for i in selected), len(selected))) if selected else 0.
    for limb in selected:
        js = [2*limb, 2*limb+1]
        contact = linear[limb].T @ (normal*forces["direction"][limb])
        bounds = bounded_load_scale(gravity[js], contact, np.column_stack((lo[js], hi[js])))
        if bounds is None or bounds[1] <= 0.:
            continue
        scale = max(bounds[0], STATIC_RESERVE*bounds[1])
        force = normal*scale*forces["direction"][limb]
        active.append(limb)
        wrenches.append(dict(body_id=g.tree.body_ids[g.bank.distal[limb]], point=points[limb].tolist(),
                             force=force.tolist(), torque=[0., 0., 0.]))
        requests.append(dict(limb=limb, guarded_scale_interval=bounds, chosen_scale=float(scale),
            normal_request_n=float(normal*scale), moment_arm_m=float(forces["moment_arm"][limb]),
            rank=int(forces["rank"][limb])))
    quiet = [i for i in present if i not in active]
    contact_torque = g.tree.wrench_torques(frame, wrenches)
    requested = np.zeros(8)
    for limb in active:
        js = [2*limb, 2*limb+1]; requested[js] = -gravity[js]-contact_torque[js]
    projected = moment.mechanics.command_for_torque(envelope, velocity, gains, ranges, requested)
    projected.update(gravity_torque=gravity, contact_torque=contact_torque,
        static_joint_balance_residual=projected["predicted_torque"]+gravity+contact_torque,
        dynamic_feasibility_established=False, capability_estimated=False)
    targets = np.asarray(result["normalized_targets"])
    targets = np.where(targets>=0., targets*g.upper, -targets*g.lower)
    velocities = p["position_gain_s_inv"]*(targets-q)
    for limb in present:
        js = [2*limb, 2*limb+1]; velocities[js] = projected["target"][js]
        if limb in active:
            require(np.max(np.abs(projected["torque_error"][js]))<=1e-8, "Torque-map active request outside guards")
    info.update(reason="bounded_contact_request" if active else "no_positive_guarded_force",
        eligible_limbs=eligible, active_limbs=active, quiet_limbs=quiet, requests=requests,
        ranks=forces["rank"].tolist(), cone_feasible=forces["feasible"].tolist(),
        total_normal_request_n=float(sum(v["normal_request_n"] for v in requests)),
        quiet_torque_error_nm=[float(projected["torque_error"][j]) for i in quiet for j in (2*i, 2*i+1)])
    result.update(phase="contact_force" if active else "reach", active_limbs=active,
        proposed_velocities_rad_s=velocities.tolist(), geometric_contact_points_m=points.tolist(),
        measured_nonadjacent_gap_m=gap, requested_moment_nm=float(g.weight*g.length*p["moment_weight_length_ratio"]),
        proposed_moment_nm=float(sum(v["normal_request_n"]*v["moment_arm_m"] for v in requests)),
        requested_wrenches=wrenches,
        force_projection={k:v.tolist() if isinstance(v, np.ndarray) else v for k,v in projected.items()})
    return result
