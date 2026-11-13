"""Read-only pose timing and actuator-response diagnosis of retained discovery.

This reconstructs only the pose schedule and velocity-command calculation.
It does not reconstruct detailed contacts, mechanics or the complete controller
interface, and never changes eligibility or opens a simulation world.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import struct

DT = 1 / 120
FORCE_SATURATION_FRACTION = .999


def require(ok, message):
    if not ok:
        raise ValueError(message)


def f32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def angles(joints, pose):
    return [v * (j["upper_limit_rad"] if v >= 0 else -j["lower_limit_rad"])
            for j, v in zip(joints, pose, strict=True)]


class Motion:
    def __init__(self, profile, creature, identity):
        self.profile, self.creature, self.identity = profile, creature, identity
        spec = creature["compiled"]["morphology"]["morphology_spec"]
        self.joints, self.motors = spec["joints"], spec["actuators"]
        require(len(self.joints) == len(self.motors) == 8, "Diagnostic joint population")
        self.distal = {creature["spec"]["geom_names"].index(s["body_id"] + "_geom")
                       for s in spec["contact_sites"]}
        self.force_caps = [max(abs(f32(v)) for v in bounds)
                           for bounds in creature["spec"]["force_ranges"]]
        self.speeds = [min(m["maximum_target_speed_rad_s"], profile["maximum_speed_rad_s"])
                       for m in self.motors]
        require(profile["mode"] in ("pose_sequence", "rock", "zero_velocity_brake"),
                "Diagnostic unsupported controller mode")
        if profile["mode"] == "pose_sequence":
            require(all(p["advance_when"] == "pose" for p in profile["phases"]),
                    "Diagnostic requires pose-only transitions")
        self.step, self.phase, self.elapsed = 0, 0, 0
        self.held, self.previous = None, [0.] * 8
        self.counts = collections.Counter()
        self.sums = collections.Counter()
        self.maxima = collections.defaultdict(float)
        self.phase_reports = []
        self.active_phase = None

    def enter(self, positions):
        phase = self.profile["phases"][self.phase]
        target = angles(self.joints, phase["pose"])
        distances = [abs(x - q) for x, q in zip(target, positions, strict=True)]
        # A slew-free, ideal target-speed estimate is not a physical speed bound:
        # measured joint velocity can exceed the commanded motor target speed.
        times = [(phase["maximum_hold_steps"] - phase["limb_delay_steps"][i // 2]) * DT
                 for i in range(8)]
        misses = sum(max(0., d - phase["threshold"]) > speed * available
                     for d, speed, available in zip(distances, self.speeds, times, strict=True))
        self.active_phase = dict(phase_id=phase["id"], entry_outer_step=self.step,
            entry_maximum_pose_error_rad=max(distances),
            ideal_target_speed_travel_seconds=max(d / s for d, s in zip(distances, self.speeds, strict=True)),
            maximum_hold_seconds=phase["maximum_hold_steps"] * DT,
            joints_missing_deadline_at_ideal_target_speed=misses,
            completed=False, exit_reason=None, exit_maximum_pose_error_rad=None)
        self.phase_reports.append(self.active_phase)

    def targets(self, positions):
        p = self.profile
        if p["mode"] != "pose_sequence":
            return angles(self.joints, p["pose_a" if (self.step // p["half_period_steps"]) % 2 == 0 else "pose_b"])
        if self.held is None:
            self.held = [max(-.9, min(.9, q / (j["upper_limit_rad"] if q >= 0 else -j["lower_limit_rad"])))
                         for q, j in zip(positions, self.joints, strict=True)]
            self.enter(positions)
        phase = p["phases"][self.phase]
        error = max(abs(x - q) for x, q in zip(angles(self.joints, phase["pose"]), positions, strict=True))
        ready = error <= phase["threshold"]
        if self.elapsed >= phase["minimum_hold_steps"] and (ready or self.elapsed >= phase["maximum_hold_steps"]):
            self.active_phase.update(completed=True, exit_outer_step=self.step,
                elapsed_steps=self.elapsed, exit_reason="measured_pose" if ready else "bounded_fallback",
                exit_maximum_pose_error_rad=error)
            self.held = phase["pose"][:]
            self.phase = (self.phase + 1) % len(p["phases"])
            self.elapsed = 0
            self.enter(positions)
        phase = p["phases"][self.phase]
        pose = [v if self.elapsed >= phase["limb_delay_steps"][i // 2] else self.held[i]
                for i, v in enumerate(phase["pose"])]
        self.elapsed += 1
        return angles(self.joints, pose)

    def consume(self, row):
        require(row["outer_step"] == self.step and row["binding"]["cell_id"] == self.identity["cell_id"]
                and row["binding"]["candidate_id"] == self.profile["id"], "Diagnostic row identity or order")
        require(row["safe_no_actuation"] is False and len(row["samples"]) == 5, "Diagnostic capture scope")
        q = row["prepared_qpos"]
        require(1 - 2 * (q[4] ** 2 + q[5] ** 2) < .9, "Diagnostic does not cover upright-stance switching")
        positions = q[7:]
        target = self.targets(positions)
        command = []
        for i, (joint, actual, goal, speed) in enumerate(zip(self.joints, positions, target, self.speeds, strict=True)):
            lo, hi = joint["lower_limit_rad"], joint["upper_limit_rad"]
            desired = 0. if self.profile["mode"] == "zero_velocity_brake" else self.profile["position_gain_s_inv"] * (goal - actual)
            bounded = max(-speed, min(speed, desired))
            slew = self.profile["maximum_slew_rad_s_per_step"]
            slewed = max(self.previous[i] - slew, min(self.previous[i] + slew, bounded))
            guarded = max(min(0., (lo - actual) / DT), min(max(0., (hi - actual) / DT), slewed))
            command.append(guarded)
            self.counts["speed_limited_commands"] += bounded != desired
            self.counts["slew_limited_commands"] += slewed != bounded
            self.counts["joint_guard_commands"] += guarded != slewed
            self.counts["prepared_out_of_bounds_joint_observations"] += not lo <= actual <= hi
            self.counts["outward_commands_at_or_beyond_bound"] += (actual >= hi and guarded > 0) or (actual <= lo and guarded < 0)
        require([struct.pack("<f", v) for v in command] == [struct.pack("<f", v) for v in row["native_targets"]],
                f"Diagnostic velocity-command mismatch at {self.identity['cell_id']} step {self.step}")
        self.previous = command
        for sample in row["samples"]:
            self.counts["native_samples"] += 1
            contact = any(0 in h["geom"] and any(g in self.distal for g in h["geom"]) for h in sample["contacts"])
            self.counts["distal_contact_samples"] += contact
            violations = []
            for i, (joint, actual, velocity, force, goal, speed) in enumerate(zip(self.joints,
                    sample["qpos"][7:], sample["qvel"][6:], sample["actuator_force_nm"], target, self.speeds, strict=True)):
                excess = max(joint["lower_limit_rad"] - actual, actual - joint["upper_limit_rad"], 0.)
                violations.append(excess > 0)
                self.maxima["joint_limit_excess_rad"] = max(self.maxima["joint_limit_excess_rad"], excess)
                self.maxima["absolute_joint_speed_rad_s"] = max(self.maxima["absolute_joint_speed_rad_s"], abs(velocity))
                self.sums["absolute_position_error_rad"] += abs(goal - actual)
                self.sums["absolute_velocity_error_rad_s"] += abs(f32(command[i]) - velocity)
                self.counts["joint_samples"] += 1
                self.counts["force_saturated_joint_samples"] += abs(force) >= FORCE_SATURATION_FRACTION * self.force_caps[i]
                self.counts["joint_speed_above_target_cap_samples"] += abs(velocity) > speed
            self.counts["joint_limit_violation_samples"] += any(violations)
        self.step += 1

    def finish(self, expected):
        require(self.counts["native_samples"] == expected["trajectory_samples"]
                and self.counts["joint_limit_violation_samples"] == expected["joint_limit_violation_steps"]
                and self.counts["distal_contact_samples"] == expected["trajectory_distal_contact_samples"],
                "Diagnostic disagrees with retained outcome reader")
        count = self.counts["joint_samples"]
        require(count > 0, "Diagnostic empty capture")
        return dict(**self.identity, controller_rows=self.step, velocity_commands_matched=self.step * 8,
            counts=dict(self.counts), maxima=dict(self.maxima),
            mean_absolute_position_error_rad=self.sums["absolute_position_error_rad"] / count,
            mean_absolute_velocity_error_rad_s=self.sums["absolute_velocity_error_rad_s"] / count,
            phase_visits=self.phase_reports)


class Archive:
    def __init__(self, root, receipt):
        self.root = root.resolve()
        self.inventory = {v["path"]: v for v in receipt["artifacts"]}
        self.verified = {}

    def lines(self, name):
        p = (self.root / name).resolve()
        require(p.is_relative_to(self.root) and name in self.inventory, "Diagnostic unbound input path")
        h, count = hashlib.sha256(), 0
        with p.open("rb") as f:
            for line in f:
                h.update(line)
                count += len(line)
                yield line
        expected = self.inventory[name]
        require(count == expected["bytes"] and h.hexdigest() == expected["sha256"], "Diagnostic input hash or length")
        self.verified[name] = dict(path=name, sha256=h.hexdigest(), bytes=count)

    def document(self, name):
        return json.loads(b"".join(self.lines(name)))


def diagnose(root, closure):
    raw = (root / "receipt.json").read_bytes()
    require(hashlib.sha256(raw).hexdigest() == closure["receipt_sha256"], "Diagnostic receipt binding")
    receipt = json.loads(raw)
    require(receipt["ok"] and receipt["source_runtime_unchanged"] and receipt["source_status"] == [], "Diagnostic owner state")
    c = receipt["contract"]
    require(c["capture_mode"] == "compact_v1" and c["outer_steps"] == 720, "Diagnostic retained discovery scope")
    archive = Archive(root, receipt)
    audit = archive.document("independent-audit.json")
    require(audit == receipt["audit"], "Diagnostic retained audit binding")
    episodes = audit["assessment"]["episodes"]
    profiles = {p["id"]: p for p in c["righting_spec"]["profiles"]}
    outcomes = [None] * len(episodes)
    for group in receipt["worker"]["groups"]:
        prefix = "native/" + group["batch_id"]
        motions = []
        for local, global_index in enumerate(group["cell_indices"]):
            creature = archive.document(prefix + f"/cell_{local}/creature.json")
            e = episodes[global_index]
            identity = {k: e[k] for k in ("cell_id", "body_id", "body_index", "candidate_id", "candidate_index")}
            motions.append(Motion(profiles[e["candidate_id"]], creature, identity))
        rows = 0
        for line in archive.lines(prefix + "/compact.jsonl"):
            row = json.loads(line)
            require(row["cell"] == rows % len(motions), "Diagnostic batch row order")
            motions[row["cell"]].consume(row)
            rows += 1
        require(rows == len(motions) * c["outer_steps"], "Diagnostic batch denominator")
        for motion, global_index in zip(motions, group["cell_indices"], strict=True):
            outcomes[global_index] = motion.finish(episodes[global_index]["metrics"])
    require(all(o is not None for o in outcomes), "Diagnostic missing world")
    families = []
    for family, ids in (("brake", {0}), ("timed", {1}), ("wave", set(range(2, 18))),
                        ("impulse", set(range(18, 34))), ("waypoint", set(range(34, 50)))):
        rows = [o for o in outcomes if o["candidate_index"] in ids]
        counts = collections.Counter()
        for row in rows:
            counts.update(row["counts"])
        visits = [p for o in rows for p in o["phase_visits"]]
        exits = [p for p in visits if p["completed"]]
        families.append(dict(family=family, worlds=len(rows), counts=dict(counts), phase_entries=len(visits),
            measured_pose_exits=sum(p["exit_reason"] == "measured_pose" for p in exits),
            timeout_exits=sum(p["exit_reason"] == "bounded_fallback" for p in exits),
            entries_missing_ideal_target_speed_deadline=sum(p["joints_missing_deadline_at_ideal_target_speed"] > 0 for p in visits),
            mean_exit_pose_error_rad=sum(p["exit_maximum_pose_error_rad"] for p in exits) / len(exits) if exits else None,
            maximum_joint_limit_excess_rad=max(o["maxima"]["joint_limit_excess_rad"] for o in rows),
            mean_absolute_position_error_rad=sum(o["mean_absolute_position_error_rad"] for o in rows) / len(rows),
            mean_absolute_velocity_error_rad_s=sum(o["mean_absolute_velocity_error_rad_s"] for o in rows) / len(rows)))
    return dict(schema_version="locolemotion_trajectory_diagnosis_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp", authority_mode="retained_motion_diagnostic", question_class="development"),
        ok=True, source_receipt_sha256=closure["receipt_sha256"], source_commit=receipt["source_commit"],
        world_build_count=0, solver_steps=0, worlds_read=len(outcomes),
        controller_rows=sum(o["controller_rows"] for o in outcomes),
        velocity_commands_matched=sum(o["velocity_commands_matched"] for o in outcomes),
        force_saturation_fraction=FORCE_SATURATION_FRACTION, input_files=list(archive.verified.values()),
        families=families, outcomes=outcomes, eligibility_changed=False, full_controller_replay=False,
        physical_acceptance_authority=False, training_data_authority=False, release_authority=False,
        scope="Pose schedule and velocity-command calculation reconstructed from bound prepared states. Detailed controller observation, mechanics and contact geometry are not replayed. Timing estimates assume ideal tracking at target speed and are not physical feasibility bounds or causal conclusions.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--closure", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(not args.output.exists(), "Diagnostic output already exists")
    result = diagnose(args.archive, json.loads(args.closure.read_bytes()))
    with args.output.open("x", encoding="utf-8", newline="\n") as f:
        json.dump(result, f, indent=2)
        f.write("\n")
    print(json.dumps(dict(ok=True, worlds_read=result["worlds_read"], world_build_count=0,
                          controller_rows=result["controller_rows"], output=str(args.output))))


if __name__ == "__main__":
    main()
