"""Retained geometry profiling and path diagnosis; never construct a world.

Reuse the compact archive reader and the production geometry. These posthoc
observations never replace frozen scores or certify continuous collision freedom.
"""
import argparse
import collections
import cProfile
import hashlib
import json
import math
from pathlib import Path
import pstats
import struct
import subprocess
import time
import types

import numpy as np

import creature_body_moment as moment
from creature_trajectory_diagnosis import Archive, DT, f32, require
from creature_contact_moment import TOLERANCE_M

ROOT = Path(__file__).resolve().parents[2]


def bound_archive(root, digest):
    raw = (root / "receipt.json").read_bytes()
    require(hashlib.sha256(raw).hexdigest() == digest, "Geometry receipt binding")
    receipt = json.loads(raw)
    require(receipt["ok"] and receipt["source_runtime_unchanged"] and not receipt["source_status"],
            "Geometry retained owner state")
    archive = Archive(root, receipt)
    require(archive.document("independent-audit.json") == receipt["audit"], "Geometry audit binding")
    return archive, receipt


def profile_geometry(root, digest, reference_commit=None):
    """Profile retained full-route inputs before edits; optionally pair with Git bytes."""
    archive, receipt = bound_archive(root, digest)
    require(receipt["contract"]["capture_mode"] == "full", "Geometry profile needs full capture")
    frames, maximum_intrinsic_difference = [], 0.
    for group in receipt["worker"]["groups"]:
        prefix = "native/" + group["batch_id"]
        geometries = {}
        for line in archive.lines(prefix + "/controller.jsonl"):
            row = json.loads(line)
            if "body_moment" not in row["resolution"]:
                continue
            cell = row["cell"]
            if cell not in geometries:
                geometries[cell] = moment.Geometry(archive.document(prefix + f"/cell_{cell}/creature.json"))
            geometry, state = geometries[cell], row["request"]["state"]
            q = [j["position_rad"] for j in state["ordered_joint_observations"]]
            pose = state["base_pose_world"]
            frame = geometry.tree.kinematics([pose["position_m"][k] for k in "xyz"],
                [pose["orientation_xyzw"][k] for k in "xyzw"], q)
            points, gap = geometry.measured(frame)
            recorded = row["resolution"]["body_moment"]
            require(points.tobytes() == np.asarray(recorded["geometric_contact_points_m"]).tobytes()
                and struct.pack("d", gap) == struct.pack("d", recorded["measured_nonadjacent_gap_m"]),
                "Geometry changed retained points or gap")
            intrinsic = geometry.measured(geometry.tree.kinematics([0., 0., 0.], [0., 0., 0., 1.], q))[1]
            difference = abs(intrinsic-gap)
            require(difference <= 1e-12, "Geometry root invariance")
            maximum_intrinsic_difference = max(maximum_intrinsic_difference, difference)
            frames.append((geometry, frame))
    require(len(frames) >= 512, "Geometry profile input population")
    sample = [frames[i] for i in np.linspace(0, len(frames)-1, 512, dtype=int)]
    current = moment.Geometry.measured
    methods = {"current": current}
    reference_digest = None
    if reference_commit is not None:
        require(len(reference_commit) == 40 and all(c in "0123456789abcdef" for c in reference_commit),
                "Geometry reference commit")
        raw = subprocess.check_output(["git", "show", reference_commit + ":sdk/discovery/creature_body_moment.py"], cwd=ROOT)
        reference_digest = hashlib.sha256(raw).hexdigest()
        module = types.ModuleType("frozen_body_moment")
        exec(compile(raw, "frozen_body_moment", "exec"), module.__dict__)
        methods["reference"] = module.Geometry.measured
        for geometry, frame in frames:
            before, after = methods["reference"](geometry, frame), current(geometry, frame)
            require(before[0].tobytes() == after[0].tobytes() and struct.pack("d", before[1]) == struct.pack("d", after[1]),
                    "Geometry reference parity")
    profiler = cProfile.Profile()
    profiler.enable()
    for geometry, frame in sample:
        current(geometry, frame)
    profiler.disable()
    stats = pstats.Stats(profiler)
    timings = {name: [] for name in methods}
    for repeat in range(4):
        # Alternate paired order so cache and machine activity do not always favor one arm.
        for name in list(methods)[::1 if repeat % 2 == 0 else -1]:
            started = time.perf_counter()
            for geometry, frame in sample:
                methods[name](geometry, frame)
            timings[name].append(time.perf_counter()-started)
    return dict(ok=True, source_receipt_sha256=digest, source_commit=receipt["source_commit"],
        world_build_count=0, solver_steps=0, retained_frames_matched=len(frames), benchmark_frames=len(sample),
        maximum_root_invariance_difference_m=maximum_intrinsic_difference, reference_commit=reference_commit,
        reference_source_sha256=reference_digest, paired_seconds=timings,
        profile_total_s=stats.total_tt, profile_functions=[dict(file=Path(k[0]).name, line=k[1], function=k[2],
            calls=v[1], self_seconds=v[2], cumulative_seconds=v[3])
            for k, v in sorted(stats.stats.items(), key=lambda item: -item[1][3])[:25]],
        input_files=list(archive.verified.values()),
        scope="Retained-input geometry computation only; excludes kinematics, controller logic, capture and native stepping.")


class PathClearance:
    """Track the clear prefix, retaining overlaps even if the path later clears."""
    def __init__(self, geometry):
        self.geometry = geometry
        self.samples = 0
        self.last_time = -math.inf
        self.minimum = math.inf
        self.first_overlap = self.peak = self.prefix_peak = None
        self.overlap_samples = 0

    def observe(self, qpos, time_s):
        require(len(qpos) == 15 and all(type(v) in (int, float) and math.isfinite(v) for v in qpos)
                and math.isfinite(time_s) and time_s > self.last_time, "Clearance sample shape or time")
        g = self.geometry
        # Self-distance is root invariant. Actual native joint angles are never
        # clipped to the proposal bank's narrower normalized pose envelope.
        gap = g.measured(g.tree.kinematics([0., 0., 0.], [0., 0., 0., 1.], qpos[7:]))[1]
        require(math.isfinite(gap), "Clearance nonfinite gap")
        up = max(-1., min(1., 1-2*(qpos[4]**2+qpos[5]**2)))
        event = dict(sample_number=self.samples, time_s=time_s,
            rotation_degrees=math.degrees(math.acos(-up)), nonadjacent_gap_m=gap)
        self.minimum = min(self.minimum, gap)
        if gap < -TOLERANCE_M:
            self.overlap_samples += 1
            if self.first_overlap is None:
                self.first_overlap = event
        if self.peak is None or event["rotation_degrees"] > self.peak["rotation_degrees"]:
            self.peak = event
        if self.first_overlap is None and (self.prefix_peak is None
                or event["rotation_degrees"] > self.prefix_peak["rotation_degrees"]):
            self.prefix_peak = event
        self.samples += 1
        self.last_time = time_s

    def finish(self, native_samples, expected_peak):
        require(self.samples == native_samples+1 and self.peak is not None
                and abs(self.peak["rotation_degrees"]-expected_peak) <= 1e-12,
                "Clearance denominator or frozen peak")
        return dict(native_samples=native_samples, initial_states=1, minimum_nonadjacent_gap_m=self.minimum,
            overlap_samples=self.overlap_samples, first_overlap=self.first_overlap,
            peak=self.peak, peak_before_first_overlap=self.prefix_peak,
            sampled_path_clear=self.first_overlap is None)


def diagnose_clearance(root, digest):
    archive, receipt = bound_archive(root, digest)
    require(receipt["contract"]["capture_mode"] == "compact_v1", "Clearance needs compact native samples")
    audit, selected, reference_ids = receipt["audit"], {}, set()
    for group in audit["trajectory_screen"]["groups"]:
        if not group["progress_leads"]:
            continue
        timed = [r for r in group["observations"] if r["candidate_index"] == group.get("reference_candidate_index",1)]
        require(len(timed) == 1, "Clearance fresh same-body comparator")
        reference_ids.add(timed[0]["cell_id"])
        for row in [*group["progress_leads"], *timed]:
            require(row["cell_id"] not in selected, "Clearance duplicate selected cell")
            selected[row["cell_id"]] = row
    episodes = audit["assessment"]["episodes"]
    outcomes = []
    for group in receipt["worker"]["groups"]:
        prefix, motions = "native/" + group["batch_id"], {}
        for local, index in enumerate(group["cell_indices"]):
            e = episodes[index]
            if e["cell_id"] in selected:
                creature = archive.document(prefix + f"/cell_{local}/creature.json")
                motions[local] = PathClearance(moment.Geometry(creature))
        if not motions:
            continue
        rows, n = 0, len(group["cell_indices"])
        for line in archive.lines(prefix + "/compact.jsonl"):
            row = json.loads(line)
            require(row["cell"] == rows % n and row["outer_step"] == rows // n, "Clearance batch order")
            rows += 1
            if row["cell"] not in motions:
                continue
            motion = motions[row["cell"]]
            e = episodes[group["cell_indices"][row["cell"]]]
            require(row["binding"]["cell_id"] == e["cell_id"] and row["binding"]["candidate_id"] == e["candidate_id"]
                    and len(row["samples"]) == 5 and row["safe_no_actuation"] is False, "Clearance selected identity")
            if row["outer_step"] == 0:
                motion.observe(row["prepared_qpos"], row["prepared_time_s"])
            for sample in row["samples"]:
                motion.observe(sample["qpos"], sample["time_s"])
        require(rows == n*receipt["contract"]["outer_steps"], "Clearance stream denominator")
        for local, motion in motions.items():
            e = episodes[group["cell_indices"][local]]
            frozen = selected[e["cell_id"]]
            role=("timed_comparator" if e["candidate_index"]==1 else "reference_comparator") if e["cell_id"] in reference_ids else "raw_progress_lead"
            outcomes.append(dict(frozen_observation=frozen, role=role,
                **motion.finish(e["metrics"]["trajectory_samples"], frozen["peak_rotation_degrees"])))
        print(json.dumps(dict(batch=group["batch_id"], trajectories_completed=len(outcomes))), flush=True)
    require(len(outcomes) == len(selected), "Clearance missing selected trajectory")
    return dict(ok=True, schema_version="locolemotion_retained_path_clearance_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp", authority_mode="retained_motion_diagnostic", question_class="development"),
        source_receipt_sha256=digest, source_commit=receipt["source_commit"], world_build_count=0, solver_steps=0,
        overlap_tolerance_m=TOLERANCE_M, native_samples=sum(o["native_samples"] for o in outcomes),
        initial_states=len(outcomes), outcomes=outcomes, input_files=list(archive.verified.values()),
        eligibility_changed=False, recovery_qualified=False, training_data_authority=False,
        physical_acceptance_authority=False, release_authority=False,
        scope="Posthoc samples, including each initial state; no continuous-time clearance or collision-response proof. Native robot self-collision remains disabled.")


class MomentCommands:
    """Separate observed motion, instantaneous torque predictions and native force.

    Release intervals use their entry observation and the next push observation.
    An unfinished last interval stays unfinished. No alternative action is run.
    """
    def __init__(self, profile, creature, identity, steps):
        self.profile, self.creature, self.identity, self.steps = profile, creature, identity, steps
        self.counts, self.sums, self.banks = collections.Counter(), collections.Counter(), collections.Counter()
        self.frames, self.releases, self.tail_rotations = [], [], []
        self.open_release = self.first_contact = self.first_steering = self.previous_bank = None
        self.first_force = self.peak = self.last = None

    def consume(self, row):
        step, state, resolution = row["outer_step"], row["request"]["state"], row["resolution"]
        require(step == len(self.frames) == state["semantic_step"] and step < self.steps
                and row["binding"]["cell_id"] == self.identity["cell_id"]
                and row["binding"]["candidate_id"] == self.profile["id"], "Moment diagnostic row identity/order")
        d = resolution["body_moment"]
        up = resolution["observed_up_dot"]
        require(math.isfinite(up) and -1.000001 <= up <= 1.000001, "Moment diagnostic finite orientation")
        rotation = math.degrees(math.acos(max(-1., min(1., -up))))
        point = dict(outer_step=step, time_s=step*DT, rotation_degrees=rotation)
        if self.peak is None or rotation > self.peak["rotation_degrees"]:
            self.peak = point.copy()
        contacts = state["ordered_contact_observations"]
        require(len(contacts) == 4, "Moment diagnostic contacts")
        touching = any(c["presence"] for c in contacts)
        if touching and self.first_contact is None:
            self.first_contact = point.copy()
        active = d["active_limbs"]
        require(active == sorted(set(active), key=active.index)
                and all(type(i) is int and 0 <= i < 4 and contacts[i]["presence"] for i in active),
                "Moment diagnostic active contacts")
        joints = [j for limb in active for j in (2*limb, 2*limb+1)]
        commands = resolution["ordered_commands"]
        require(len(commands) == 8 and [c["canonical_velocity_rad_s"] for c in commands] == row["native_targets"],
                "Moment diagnostic resolved commands")
        velocity = [j["velocity_rad_s"] for j in state["ordered_joint_observations"]]
        spec = self.creature["spec"]
        post = moment.mechanics.motor_torque(row["native_targets"], velocity,
                                             spec["velocity_gains"], spec["force_ranges"])
        require(np.array_equal(post, d["post_guard_predicted_torque_nm"]), "Moment diagnostic post-guard torque")
        projection = d["force_projection"]
        require(bool(active) == (projection is not None), "Moment diagnostic projection population")
        requested = None
        if active:
            requested = moment.mechanics.array(projection["requested_torque"], (8,), "Diagnostic requested torque")
            pre = moment.mechanics.motor_torque(projection["target"], velocity,
                                                spec["velocity_gains"], spec["force_ranges"])
            require(np.array_equal(pre, projection["predicted_torque"]), "Moment diagnostic pre-guard torque")
            for j in joints:
                self.sums["requested_abs_nm"] += abs(requested[j])
                self.sums["pre_guard_error_nm"] += abs(pre[j]-requested[j])
                self.sums["post_guard_error_nm"] += abs(post[j]-requested[j])
                self.counts["active_joint_commands"] += 1
                self.counts["active_joint_guard_commands"] += commands[j]["joint_guard_applied"]
                self.counts["active_joint_error_increased_after_guard"] += int(abs(post[j]-requested[j]) > abs(pre[j]-requested[j])+1e-9)
            if self.first_force is None:
                self.first_force = dict(point, active_limbs=active[:], joint_indices=joints,
                    requested_torque_nm=requested[joints].tolist(), pre_guard_torque_nm=pre[joints].tolist(),
                    post_guard_torque_nm=post[joints].tolist())
        h = d.get("handoff")
        if h and h["upright_steering_available"] and self.first_steering is None:
            self.first_steering = point.copy()
        release = d["phase"] == "contact_release"
        if release:
            require(not active and not d["requested_wrenches"] and d["normalized_targets"] == [0.]*8,
                    "Moment diagnostic release must have neutral targets and no force request")
            if self.open_release is None:
                self.open_release = dict(entry=point.copy(), trigger=h["reason"], contact_rows=0)
            self.open_release["contact_rows"] += touching
        elif self.open_release is not None:
            self.close_release(point, complete=True)
        inner = d["state_after"].get("inner", d["state_after"])
        inner = inner.get("base", inner)
        target = inner.get("target")
        bank = None if target is None else target["bank_index"]
        self.banks[bank] += 1
        self.counts["target_changes"] += step > 0 and bank != self.previous_bank
        self.previous_bank = bank
        for name, value in (("controller_rows", 1), (d["phase"]+"_rows", 1), ("contact_rows", touching),
                            ("active_force_rows", bool(active))):
            self.counts[name] += value
        if step >= 2*self.steps//3:
            self.tail_rotations.append(rotation)
        self.frames.append(dict(joints=joints, requested=requested, targets=row["native_targets"]))
        self.last = point

    def close_release(self, point, *, complete):
        entry = self.open_release["entry"]
        self.releases.append(dict(self.open_release, exit=point.copy(), complete=complete,
            observed_duration_s=(point["outer_step"]-entry["outer_step"])*DT,
            observed_rotation_change_degrees=point["rotation_degrees"]-entry["rotation_degrees"]))
        self.open_release = None

    def native(self, row):
        sample = self.counts["native_samples"]
        # Native rows are post-step observations, numbered from one.
        require(row["step"] == sample+1 and sample < 5*self.steps, "Moment diagnostic native sample order")
        frame = self.frames[sample//5]
        require(row["ctrl"] == [f32(v) for v in frame["targets"]], "Moment diagnostic native command binding")
        forces = moment.mechanics.array(row["actuator_force_nm"], (8,), "Diagnostic native actuator force")
        self.counts["native_samples"] += 1
        for j in frame["joints"]:
            self.counts["active_joint_native_samples"] += 1
            self.sums["observed_force_abs_nm"] += abs(forces[j])
            self.sums["observed_force_to_prepared_request_error_nm"] += abs(forces[j]-frame["requested"][j])

    def finish(self, expected):
        require(len(self.frames) == self.steps and self.counts["native_samples"] == 5*self.steps,
                "Moment diagnostic incomplete capture")
        if self.open_release is not None:
            self.close_release(self.last, complete=False)
        n, m = self.counts["active_joint_commands"], self.counts["active_joint_native_samples"]
        return dict(**self.identity, counts=dict(self.counts), first_contact=self.first_contact,
            first_force=self.first_force, first_steering=self.first_steering, releases=self.releases,
            peak_prepared_rotation=self.peak, last_prepared_rotation=self.last,
            native_peak_rotation_degrees=math.degrees(math.acos(max(-1., min(1., -expected["trajectory_maximum_up_dot"])))),
            tail_window_start_step=2*self.steps//3,
            tail_prepared_rotation_range_degrees=max(self.tail_rotations)-min(self.tail_rotations),
            target_bank_rows=[dict(bank_index=k, rows=v) for k,v in self.banks.most_common()],
            mean_requested_abs_torque_nm=self.sums["requested_abs_nm"]/n if n else None,
            mean_pre_guard_torque_error_nm=self.sums["pre_guard_error_nm"]/n if n else None,
            mean_post_guard_torque_error_nm=self.sums["post_guard_error_nm"]/n if n else None,
            mean_observed_active_joint_force_abs_nm=self.sums["observed_force_abs_nm"]/m if m else None,
            mean_observed_force_to_prepared_request_error_nm=self.sums["observed_force_to_prepared_request_error_nm"]/m if m else None)




from creature_support_sharing_bounds import bounded_load_scale


class ExchangeCommands(MomentCommands):
    """Describe every exposed exchange and each transfer's realized commands."""
    def __init__(self, *args):
        super().__init__(*args)
        self.transfers, self.exchange_counts, self.phase_metrics = [], collections.Counter(), {}
        self.open_transfer = self.last_exchange = None
        self.previous_exchange_state = None

    def snapshot(self, row, old, replacement):
        d, state = row["resolution"]["body_moment"], row["request"]["state"]
        e, commands = d["support_exchange"], row["resolution"]["ordered_commands"]
        points = moment.mechanics.array(d["geometric_contact_points_m"], (4, 3), "Exchange points")
        q = moment.mechanics.array([x["position_rad"] for x in state["ordered_joint_observations"]], (8,), "Exchange positions")
        qd = moment.mechanics.array([x["velocity_rad_s"] for x in state["ordered_joint_observations"]], (8,), "Exchange velocity")
        position = moment.mechanics.xyz(state["base_pose_world"]["position_m"])
        projection = d["force_projection"]
        requested = self.frames[-1]["requested"]
        pre = None if projection is None else projection["predicted_torque"]
        active = d["active_limbs"]
        require(len(d["requested_wrenches"]) == len(active), "Exchange wrench population")
        normals = {}
        spec = self.creature["compiled"]["morphology"]["morphology_spec"]
        for limb, wrench in zip(active, d["requested_wrenches"], strict=True):
            require(wrench["body_id"] == spec["bodies"][2+2*limb]["body_id"], "Exchange wrench body")
            force = moment.mechanics.array(wrench["force"], (3,), "Exchange requested force")
            require(force[1] > 0., "Exchange positive requested normal")
            normals[limb] = float(force[1])
        limbs = {}
        for role, limb in (("old_primary", old[0]), ("replacement", replacement)):
            js = [2*limb, 2*limb+1]
            limits = [self.creature["spec"]["force_ranges"][j] for j in js]
            selected = lambda v: None if v is None else [float(v[j]) for j in js]
            loads = None
            if limb in active:
                gravity = selected(projection["gravity_torque"])
                contact = selected(projection["contact_torque"])
                require(np.allclose(-np.asarray(gravity)-contact, requested[js], rtol=0., atol=1e-9),
                        "Exchange static request identity")
                envelope = [[projection["lower_torque"][j], projection["upper_torque"][j]] for j in js]
                loads = dict(requested_normal_n=normals[limb],
                    force_cap_scale_interval=bounded_load_scale(gravity, contact, limits),
                    pre_guard_command_scale_interval=bounded_load_scale(gravity, contact, envelope))
            limbs[role] = dict(limb=limb, contact_present=state["ordered_contact_observations"][limb]["presence"],
                geometric_foot_height_m=float(points[limb, 1]), position_rad=selected(q), velocity_rad_s=selected(qd),
                target_position_rad=[commands[j]["target_position_rad"] for j in js],
                resolved_velocity_rad_s=selected(row["native_targets"]), requested_torque_nm=selected(requested),
                pre_guard_predicted_torque_nm=selected(pre), post_guard_predicted_torque_nm=selected(d["post_guard_predicted_torque_nm"]),
                force_requested=limb in active, actuator_force_ranges_nm=limits,
                requested_torque_outside_force_cap=[bool(requested is not None and not limits[k][0] <= requested[j] <= limits[k][1]) for k,j in enumerate(js)],
                guard_applied=[commands[j]["joint_guard_applied"] for j in js],
                slew_limited=[commands[j]["slew_limited"] for j in js], static_request_bounds=loads)
        return dict(outer_step=row["outer_step"], phase=e["phase"], reason=e["reason"],
            rotation_degrees=self.last["rotation_degrees"], base_height_m=float(position[1]),
            touching_limbs=[i for i,c in enumerate(state["ordered_contact_observations"]) if c["presence"]],
            active_force_limbs=active[:], limbs=limbs)

    def consume(self, row):
        d = row["resolution"]["body_moment"]
        before, after, e = d["state_before"], d["state_after"], d["support_exchange"]
        require(e["phase"] in ("reference", "seek", "transfer") and e["phase"] == after["phase"]
                and (self.previous_exchange_state is None or before == self.previous_exchange_state),
                "Exchange state continuity")
        super().consume(row)
        self.previous_exchange_state = after
        phase = e["phase"]
        self.exchange_counts[phase+"_rows"] += 1
        self.exchange_counts["reason_"+e["reason"]] += 1
        frame = self.frames[-1]
        frame.update(exchange_phase=phase, transfer=None)
        stats = self.phase_metrics.setdefault(phase, collections.Counter())
        for j in frame["joints"]:
            stats["active_joint_commands"] += 1
            req = frame["requested"][j]
            lo, hi = self.creature["spec"]["force_ranges"][j]
            stats["requests_outside_force_cap"] += int(not lo <= req <= hi)
            stats["guard_commands"] += int(row["resolution"]["ordered_commands"][j]["joint_guard_applied"])
            stats["pre_guard_error_sum_nm"] += abs(d["force_projection"]["predicted_torque"][j]-req)
            stats["post_guard_error_sum_nm"] += abs(d["post_guard_predicted_torque_nm"][j]-req)
        if phase in ("seek", "transfer") or before["phase"] == "transfer":
            roles = after if phase in ("seek", "transfer") else before
            old, replacement = roles["support_limbs"], roles["replacement_limb"]
            require(type(old) is list and old and len(set(old)) == len(old)
                    and all(type(i) is int and 0 <= i < 4 for i in old)
                    and type(replacement) is int and 0 <= replacement < 4 and replacement not in old,
                    "Exchange support identities")
            point = self.snapshot(row, old, replacement)
            if phase == "transfer":
                require(d["active_limbs"] == old[1:]+[replacement], "Exchange transfer active limbs")
                if self.open_transfer is None:
                    require(e["reason"] == "measured_replacement_contact" and before["phase"] == "seek"
                            and self.last_exchange is not None and self.last_exchange["phase"] == "seek"
                            and self.last_exchange["outer_step"]+1 == row["outer_step"]
                            and after["contact_count"] >= self.profile["support_exchange"]["contact_dwell_steps"],
                            "Exchange transfer entry")
                    self.open_transfer = dict(before=self.last_exchange, entry=point, last=point,
                        command_intervals=0, complete=False, native={})
                    self.transfers.append(self.open_transfer)
                self.open_transfer["last"] = point
                self.open_transfer["command_intervals"] += 1
                frame["transfer"] = self.open_transfer
            elif self.open_transfer is not None:
                event = self.open_transfer
                require(before["phase"] == "transfer" and row["outer_step"]-event["entry"]["outer_step"] == event["command_intervals"],
                        "Exchange transfer exit")
                event.update(exit=point, complete=True,
                    observed_duration_s=event["command_intervals"]*DT,
                    observed_rotation_change_degrees=point["rotation_degrees"]-event["entry"]["rotation_degrees"])
                self.open_transfer = None
            self.last_exchange = point
        else:
            require(self.open_transfer is None, "Exchange missing transfer exit")
            self.last_exchange = None

    def native(self, row):
        super().native(row)
        frame = self.frames[(row["step"]-1)//5]
        stats = self.phase_metrics[frame["exchange_phase"]]
        forces = row["actuator_force_nm"]
        for j in frame["joints"]:
            stats["active_joint_native_samples"] += 1
            stats["observed_error_sum_nm"] += abs(forces[j]-frame["requested"][j])
        event = frame["transfer"]
        if event is not None:
            for role, data in event["entry"]["limbs"].items():
                stats = event["native"].setdefault(role, collections.Counter())
                for j in (2*data["limb"], 2*data["limb"]+1):
                    stats["joint_samples"] += 1
                    stats["force_sum_nm"] += forces[j]
                    stats["absolute_force_sum_nm"] += abs(forces[j])
                    stats["prepared_request_error_sum_nm"] += abs(forces[j]-frame["requested"][j])
                    lo, hi = self.creature["spec"]["force_ranges"][j]
                    stats["at_force_cap_samples"] += int(min(abs(forces[j]-lo),abs(forces[j]-hi)) <= 1e-5)

    def finish(self, expected):
        result = super().finish(expected)
        if self.open_transfer is not None:
            event = self.open_transfer
            event.update(exit=None, observed_duration_s=(event["last"]["outer_step"]-event["entry"]["outer_step"])*DT,
                         observed_rotation_change_degrees=event["last"]["rotation_degrees"]-event["entry"]["rotation_degrees"])
        for event in self.transfers:
            for stats in event["native"].values():
                n = stats["joint_samples"]
                require(n == event["command_intervals"]*10, "Exchange native transfer population")
                for key in ("force", "absolute_force", "prepared_request_error"):
                    stats["mean_"+key+"_nm"] = stats.pop(key+"_sum_nm")/n
        phases = {}
        for phase, stats in self.phase_metrics.items():
            n, m = stats["active_joint_commands"], stats["active_joint_native_samples"]
            phases[phase] = dict(stats)
            for key in ("pre_guard", "post_guard", "observed"):
                count = m if key == "observed" else n
                phases[phase]["mean_"+key+"_torque_error_nm"] = stats[key+"_error_sum_nm"]/count if count else None
                phases[phase].pop(key+"_error_sum_nm", None)
        return dict(result, exchange_counts=dict(self.exchange_counts), exchange_phases=phases,
                    transfers=self.transfers)


def force_identifiability(linear, force, lever, axis):
    """Split a proposed force by the joint-torque map, not by physical authority.

    The null component leaves every modeled joint torque unchanged. Neither
    component is a measured reaction or a dynamically feasible alternative.
    """
    raw = np.asarray(linear)
    require(raw.dtype.kind in "fiu" and raw.ndim == 2 and raw.shape[0] == 3
            and raw.shape[1] > 0 and np.isfinite(raw).all(), "Force diagnostic Jacobian")
    force = moment.mechanics.array(force, (3,), "Force diagnostic force")
    lever = moment.mechanics.array(lever, (3,), "Force diagnostic lever")
    axis = moment.mechanics.array(axis, (3,), "Force diagnostic axis")
    require(abs(float(axis @ axis)-1.) <= 1e-10, "Force diagnostic unit axis")
    matrix = np.asarray(raw, dtype=float).T
    _, singular, vectors = np.linalg.svd(matrix, full_matrices=False)
    tolerance = max(float(singular[0]), 1.)*1e-10
    rank = int(np.count_nonzero(singular > tolerance))
    visible = vectors[:rank].T @ (vectors[:rank] @ force)
    hidden = force-visible
    residual = float(np.max(np.abs(matrix @ hidden)))
    require(residual <= 1e-8, "Force diagnostic null torque residual")
    signed = lambda value: float(np.cross(lever, value) @ axis)
    return dict(rank=rank, singular_values_m=singular.tolist(), rank_tolerance_m=tolerance,
        requested_force_n=force.tolist(), torque_visible_force_n=visible.tolist(),
        torque_null_force_n=hidden.tolist(), null_joint_torque_residual_nm=residual,
        requested_moment_nm=signed(force), torque_visible_moment_nm=signed(visible),
        torque_null_moment_nm=signed(hidden), measured_ground_reaction=False)


class SharingCommands(MomentCommands):
    """Add phase-specific response, actual contact inventory and force ambiguity."""
    def __init__(self, profile, creature, identity, steps):
        super().__init__(profile, creature, identity, steps)
        spec = creature["compiled"]["morphology"]["morphology_spec"]
        self.tree = moment.mechanics.RigidTree(spec)
        names = creature["spec"]["geom_names"]
        self.ground = names.index("ground")
        self.torso = names.index(spec["bodies"][0]["body_id"]+"_geom")
        self.distal = [names.index(c["body_id"]+"_geom") for c in spec["contact_sites"]]
        require(len(self.distal) == len(set(self.distal)) == 4, "Sharing diagnostic distal mapping")
        self.geom_count = len(names)
        self.previous_sharing = self.open_segment = None
        self.sharing_phases, self.segments = {}, []

    def point(self, row, roles):
        state, d = row["request"]["state"], row["resolution"]["body_moment"]
        points = moment.mechanics.array(d["geometric_contact_points_m"], (4,3), "Sharing diagnostic points")
        old, replacement = roles.get("support_limbs"), roles.get("replacement_limb")
        return dict(outer_step=row["outer_step"], rotation_degrees=self.last["rotation_degrees"],
            touching_limbs=[i for i,c in enumerate(state["ordered_contact_observations"]) if c["presence"]],
            old_primary_limb=old[0] if old else None, replacement_limb=replacement,
            geometric_foot_heights_m=points[:,1].tolist(),
            active_force_limbs=d["active_limbs"][:], axis_angular_rate_rad_s=d["axis_angular_rate_rad_s"])

    def consume(self, row):
        d, state = row["resolution"]["body_moment"], row["request"]["state"]
        before, after, event = d["state_before"], d["state_after"], d["support_sharing"]
        phase = event["phase"]
        require(phase in ("reference","seek","load","unload","transfer") and phase == after["phase"]
                and (self.previous_sharing is None or before == self.previous_sharing),
                "Sharing diagnostic state continuity")
        super().consume(row)
        self.previous_sharing = after
        if self.open_segment is not None and phase != self.open_segment["phase"]:
            segment = self.open_segment
            point = self.point(row, before)
            require(row["outer_step"]-segment["entry"]["outer_step"] == segment["counts"]["controller_rows"],
                    "Sharing diagnostic phase intervals")
            segment.update(exit=point, complete=True,
                observed_duration_s=segment["counts"]["controller_rows"]*DT,
                observed_rotation_change_degrees=point["rotation_degrees"]-segment["entry"]["rotation_degrees"])
            self.open_segment = None
        if phase != "reference":
            old, replacement = after["support_limbs"], after["replacement_limb"]
            require(type(old) is list and old and len(set(old)) == len(old)
                    and all(type(i) is int and 0 <= i < 4 for i in old)
                    and type(replacement) is int and 0 <= replacement < 4 and replacement not in old,
                    "Sharing diagnostic support identities")
            expected = old if phase == "seek" else old[1:]+[replacement] if phase == "transfer" else old+[replacement]
            require(d["active_limbs"] == expected, "Sharing diagnostic active support mapping")
            if self.open_segment is None:
                self.open_segment = dict(phase=phase, entry=self.point(row, after), exit=None,
                    complete=False, counts=collections.Counter())
                self.segments.append(self.open_segment)
            self.open_segment["last_prepared"] = self.point(row, after)
        frame = self.frames[-1]
        frame.update(sharing_phase=phase, sharing_segment=self.open_segment,
            old_primary=after["support_limbs"][0] if phase != "reference" else None,
            replacement=after["replacement_limb"] if phase != "reference" else None)
        counts = self.sharing_phases.setdefault(phase, collections.Counter())
        targets = [counts] + ([self.open_segment["counts"]] if self.open_segment is not None else [])
        values = collections.Counter(controller_rows=1, active_force_rows=bool(frame["joints"]))
        if frame["joints"]:
            pose = state["base_pose_world"]
            kinematics = self.tree.kinematics(moment.mechanics.xyz(pose["position_m"]),
                [pose["orientation_xyzw"][k] for k in "xyzw"],
                [j["position_rad"] for j in state["ordered_joint_observations"]])
            body_axis = after["axis_body"] if phase != "reference" else (
                np.asarray(self.profile["axis_body"])*after["base"]["sign"])
            axis = kinematics["rotations"][0] @ body_axis
            requested_moment = 0.
            reconstructed_contact = np.zeros(self.tree.n)
            for wrench in d["requested_wrenches"]:
                require(wrench["torque"] == [0.,0.,0.], "Sharing diagnostic force-only wrench")
                linear = self.tree.jacobian(kinematics, wrench["body_id"], wrench["point"])[0]
                split = force_identifiability(linear, wrench["force"],
                    np.asarray(wrench["point"])-kinematics["whole_body_com"], axis)
                reconstructed_contact += linear.T @ np.asarray(wrench["force"])
                values["wrenches"] += 1;values["rank_"+str(split["rank"])+"_wrenches"] += 1
                requested_moment += split["requested_moment_nm"]
                for key in ("requested_moment_nm","torque_visible_moment_nm","torque_null_moment_nm"):
                    values[key+"_sum"] += split[key]
                for target in targets:
                    target["maximum_null_torque_residual_nm"] = max(target["maximum_null_torque_residual_nm"],
                                                                   split["null_joint_torque_residual_nm"])
            projection = d["force_projection"]
            require(np.allclose(reconstructed_contact, projection["contact_torque"], rtol=0., atol=1e-8)
                    and abs(requested_moment-d["proposed_moment_nm"]) <= 1e-8,
                    "Sharing diagnostic wrench reconstruction")
            for j in frame["joints"]:
                request = frame["requested"][j]
                values["active_joint_commands"] += 1
                values["prepared_request_abs_nm_sum"] += abs(request)
                values["post_guard_error_nm_sum"] += abs(d["post_guard_predicted_torque_nm"][j]-request)
        for target in targets:
            target.update(values)

    def native(self, row):
        super().native(row)
        frame = self.frames[(row["step"]-1)//5]
        targets = [self.sharing_phases[frame["sharing_phase"]]]
        if frame["sharing_segment"] is not None:targets.append(frame["sharing_segment"]["counts"])
        ground = set()
        for contact in row["contacts"]:
            geoms = contact["geom"]
            require(len(geoms) == 2 and all(type(i) is int and 0 <= i < self.geom_count for i in geoms),
                    "Sharing diagnostic native contact geometry")
            if self.ground in geoms:ground.update(i for i in geoms if i != self.ground)
        touching = {i for i,g in enumerate(self.distal) if g in ground}
        active = {j//2 for j in frame["joints"]}
        values = collections.Counter(native_samples=1, torso_contact_samples=self.torso in ground,
            unrequested_distal_contact_samples=bool(touching-active),
            old_primary_contact_samples=frame["old_primary"] in touching,
            replacement_contact_samples=frame["replacement"] in touching)
        for limb in touching:values["distal_"+str(limb)+"_contact_samples"] += 1
        for j in frame["joints"]:
            force = row["actuator_force_nm"][j]
            values["active_joint_native_samples"] += 1
            values["native_active_force_abs_nm_sum"] += abs(force)
            values["native_prepared_request_error_nm_sum"] += abs(force-frame["requested"][j])
            lo,hi = self.creature["spec"]["force_ranges"][j]
            values["active_force_cap_samples"] += int(min(abs(force-lo),abs(force-hi)) <= 1e-5)
        for limb in touching-active:
            for j in (2*limb,2*limb+1):
                values["unrequested_contact_joint_samples"] += 1
                values["unrequested_contact_joint_force_abs_nm_sum"] += abs(row["actuator_force_nm"][j])
        for target in targets:target.update(values)

    @staticmethod
    def summarize(counts):
        result = dict(counts)
        require(counts["native_samples"] == 5*counts["controller_rows"],
                "Sharing diagnostic native phase population")
        for key, denominator in (
                ("prepared_request_abs_nm","active_joint_commands"),("post_guard_error_nm","active_joint_commands"),
                ("native_active_force_abs_nm","active_joint_native_samples"),
                ("native_prepared_request_error_nm","active_joint_native_samples"),
                ("unrequested_contact_joint_force_abs_nm","unrequested_contact_joint_samples"),
                ("requested_moment_nm","active_force_rows"),("torque_visible_moment_nm","active_force_rows"),
                ("torque_null_moment_nm","active_force_rows")):
            total = result.pop(key+"_sum", 0.)
            result["mean_"+key] = total/counts[denominator] if counts[denominator] else None
        return result

    def finish(self, expected):
        result = super().finish(expected)
        if self.open_segment is not None:
            segment = self.open_segment
            point = segment["last_prepared"]
            segment.update(observed_duration_s=(point["outer_step"]-segment["entry"]["outer_step"])*DT,
                observed_rotation_change_degrees=point["rotation_degrees"]-segment["entry"]["rotation_degrees"])
        return dict(result, sharing_phases={k:self.summarize(v) for k,v in self.sharing_phases.items()},
            sharing_segments=[dict(s, counts=self.summarize(s["counts"])) for s in self.segments],
            measured_ground_reaction=False, causal_failure_isolated=False)


def diagnose_commands(root, digest, *, exchange=False, sharing=False):
    """Read every moment-controller row and native sample from a full archive."""
    require(not (exchange and sharing), "Select one support diagnostic")
    archive, receipt = bound_archive(root, digest)
    audit, contract = receipt["audit"], receipt["contract"]
    require(contract["capture_mode"] == "full" and audit["capture"]["controller_replay_verified"]
            and audit["capture"]["detailed_native_capture_verified"], "Moment diagnostic needs replayed full capture")
    episodes = audit["assessment"]["episodes"]
    profiles = {p["id"]: p for p in contract["righting_spec"]["profiles"]}
    results, controller_rows, native_rows = [], 0, 0
    for group in receipt["worker"]["groups"]:
        prefix = "native/"+group["batch_id"]
        motions = {}
        for cell, index in enumerate(group["cell_indices"]):
            e = episodes[index]
            p = profiles[e["candidate_id"]]
            if p["mode"] == moment.MODE and (not exchange or "support_exchange" in p):
                identity = {k:e[k] for k in ("cell_id", "body_index", "body_id", "candidate_index", "candidate_id")}
                collector = SharingCommands if sharing and "support_sharing" in p else (ExchangeCommands if exchange else MomentCommands)
                motions[cell] = collector(p, archive.document(prefix+f"/cell_{cell}/creature.json"), identity, contract["outer_steps"])
        for line in archive.lines(prefix+"/controller.jsonl"):
            row = json.loads(line)
            require(0 <= row["cell"] < len(group["cell_indices"]), "Moment diagnostic controller cell")
            controller_rows += 1
            if row["cell"] in motions:
                motions[row["cell"]].consume(row)
        for line in archive.lines(prefix+"/trace.jsonl"):
            row = json.loads(line)
            require(0 <= row["cell"] < len(group["cell_indices"]), "Moment diagnostic native cell")
            native_rows += 1
            if row["cell"] in motions:
                motions[row["cell"]].native(row)
        results.extend(m.finish(episodes[group["cell_indices"][cell]]["metrics"]) for cell,m in motions.items())
    require(controller_rows == audit["controller_rows_replayed"] and native_rows == audit["native_rows_verified"],
            "Moment diagnostic full archive population")
    return dict(ok=True, schema_version=("locolemotion_support_sharing_diagnosis_v1" if sharing else "locolemotion_support_exchange_diagnosis_v1" if exchange
        else "locolemotion_moment_command_diagnosis_v1"),
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp", authority_mode="retained_motion_diagnostic", question_class="development"),
        source_receipt_sha256=digest, native_source_commit=receipt["source_commit"], world_build_count=0, solver_steps=0,
        full_controller_rows_read=controller_rows, full_native_samples_read=native_rows, outcomes=results,
        input_files=list(archive.verified.values()),
        scope=("Posthoc sharing phases and native actuator response. Requested forces split into the joint-torque row space and its null space; equal joint torques do not identify a unique ground force or body moment. Neither split force is a measured reaction, a dynamically feasible alternative, or proof that its moment was absent. Native contact presence and actuator torque do not measure contact load. Prepared observations delimit phase motion; terminal phases remain incomplete. No causal isolation, new worlds or changed eligibility." if sharing else
               "Posthoc descriptions of recorded support exchanges. Affine load scales bound static force requests at measured postures; they do not measure ground reaction, certify contact persistence or guarantee dynamic feasibility. Pre-guard envelopes include speed, slew and force caps; post-guard predictions and native actuator forces remain distinct. Prepared contact and posture observations delimit transfers. No counterfactual trajectories, causal isolation or new eligibility decisions." if exchange else
               "Posthoc descriptions of recorded worlds only. Torque errors concern active joints. Predictions use prepared velocity; observed actuator force evolves during the held interval and is not measured contact reaction. Release motion is sampled at controller observations. No counterfactual trajectories, causal isolation or new eligibility decisions."),
        controller_adopted=False, recovery_benefit_established=False, physical_acceptance_authority=False,
        training_data_authority=False, release_authority=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--receipt-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-commit")
    parser.add_argument("--clearance", action="store_true")
    parser.add_argument("--commands", action="store_true")
    parser.add_argument("--exchange", action="store_true")
    parser.add_argument("--sharing", action="store_true")
    args = parser.parse_args()
    require(not args.output.exists(), "Geometry diagnostic output already exists")
    require(sum((args.clearance, args.commands, args.exchange, args.sharing, args.reference_commit is not None)) <= 1,
            "Select one diagnostic mode")
    result = (diagnose_commands(args.archive, args.receipt_sha256, exchange=args.exchange, sharing=args.sharing) if args.commands or args.exchange or args.sharing else
              diagnose_clearance(args.archive, args.receipt_sha256) if args.clearance
              else profile_geometry(args.archive, args.receipt_sha256, args.reference_commit))
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ("ok", "retained_frames_matched", "paired_seconds", "native_samples") if k in result}))


if __name__ == "__main__":
    main()
