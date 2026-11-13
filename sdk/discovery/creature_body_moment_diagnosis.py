"""Retained geometry profiling and path diagnosis; never construct a world.

Reuse the compact archive reader and the production geometry. These posthoc
observations never replace frozen scores or certify continuous collision freedom.
"""
import argparse
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
from creature_trajectory_diagnosis import Archive, require
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
    audit, selected = receipt["audit"], {}
    for group in audit["trajectory_screen"]["groups"]:
        if not group["progress_leads"]:
            continue
        timed = [r for r in group["observations"] if r["candidate_index"] == 1]
        require(len(timed) == 1, "Clearance fresh same-body comparator")
        for row in [*group["progress_leads"], *timed]:
            require(row["cell_id"] not in selected, "Clearance duplicate selected cell")
            selected[row["cell_id"]] = row
    require(selected, "Clearance empty selection")
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
            outcomes.append(dict(frozen_observation=frozen, role="timed_comparator" if e["candidate_index"] == 1 else "raw_progress_lead",
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--receipt-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-commit")
    parser.add_argument("--clearance", action="store_true")
    args = parser.parse_args()
    require(not args.output.exists(), "Geometry diagnostic output already exists")
    require(not (args.clearance and args.reference_commit), "Clearance does not use a benchmark reference")
    result = (diagnose_clearance(args.archive, args.receipt_sha256) if args.clearance
              else profile_geometry(args.archive, args.receipt_sha256, args.reference_commit))
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ("ok", "retained_frames_matched", "paired_seconds", "native_samples") if k in result}))


if __name__ == "__main__":
    main()
