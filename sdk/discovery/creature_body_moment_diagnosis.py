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


def diagnose_commands(root, digest):
    """Read every moment-controller row and native sample from a full archive."""
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
            if p["mode"] == moment.MODE:
                identity = {k:e[k] for k in ("cell_id", "body_index", "body_id", "candidate_index", "candidate_id")}
                motions[cell] = MomentCommands(p, archive.document(prefix+f"/cell_{cell}/creature.json"), identity, contract["outer_steps"])
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
    return dict(ok=True, schema_version="locolemotion_moment_command_diagnosis_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp", authority_mode="retained_motion_diagnostic", question_class="development"),
        source_receipt_sha256=digest, native_source_commit=receipt["source_commit"], world_build_count=0, solver_steps=0,
        full_controller_rows_read=controller_rows, full_native_samples_read=native_rows, outcomes=results,
        input_files=list(archive.verified.values()),
        scope="Posthoc descriptions of recorded worlds only. Torque errors concern active joints. Predictions use prepared velocity; observed actuator force evolves during the held interval and is not measured contact reaction. Release motion is sampled at controller observations. No counterfactual trajectories, causal isolation or new eligibility decisions.",
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
    args = parser.parse_args()
    require(not args.output.exists(), "Geometry diagnostic output already exists")
    require(sum((args.clearance, args.commands, args.reference_commit is not None)) <= 1,
            "Select one diagnostic mode")
    result = (diagnose_commands(args.archive, args.receipt_sha256) if args.commands else
              diagnose_clearance(args.archive, args.receipt_sha256) if args.clearance
              else profile_geometry(args.archive, args.receipt_sha256, args.reference_commit))
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ("ok", "retained_frames_matched", "paired_seconds", "native_samples") if k in result}))


if __name__ == "__main__":
    main()
