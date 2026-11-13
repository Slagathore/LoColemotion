"""Batched fixed-pose floor and center-of-mass geometry, without a simulator.

Height changes along sampled orientations screen coordination proposals. They
do not model a realizable pose transition, contact forces, momentum or recovery.
"""
import argparse
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

import numpy as np

from actuation_recovery_mechanics import RigidTree, array, quaternion_rotation, require, xyz

ROOT = Path(__file__).resolve().parents[2]
MAX_POSES = 32768
FALSE_FLAGS = ("dynamic_feasibility_established", "recovery_benefit_established",
               "trained", "training_data_authority", "physical_acceptance_authority", "release_authority")


def pose_pool(states, uniform_count, edge_count, seed):
    bank = np.asarray(states)
    require(bank.dtype.kind in "fiu" and bank.ndim == 2 and bank.shape[1] == 2
            and 2 <= len(bank) <= 10, "Geometry limb-state bank")
    bank = array(bank, bank.shape, "Geometry finite limb states")
    require(np.max(np.abs(bank)) <= .9 and len(np.unique(bank, axis=0)) == len(bank),
            "Geometry limb-state bounds or aliases")
    require(all(type(v) is int and 0 <= v <= MAX_POSES for v in (uniform_count, edge_count))
            and type(seed) is int and 0 <= seed < 2**31
            and len(bank)**4 + uniform_count + edge_count <= MAX_POSES, "Geometry pool budget")
    combinations = np.asarray(list(itertools.product(range(len(bank)), repeat=4)))
    factored = bank[combinations].reshape(-1, 8)
    rng = np.random.Generator(np.random.PCG64(seed))
    uniform = rng.uniform(-.9, .9, size=(uniform_count, 8))
    # A separate declared population explores near-limit poses without changing
    # the controller's normalized envelope or discarding the interior samples.
    signs = 2*rng.integers(0, 2, size=(edge_count, 8))-1
    edges = .9*signs*(1-rng.random((edge_count, 8))**3)
    poses = np.vstack((factored, uniform, edges))
    require(len(np.unique(poses, axis=0)) == len(poses), "Geometry duplicate pose")
    return poses


def gravity_direction(progress_deg, azimuth_deg):
    require(all(type(v) in (int, float) and math.isfinite(v) for v in (progress_deg, azimuth_deg))
            and 0 <= progress_deg <= 180 and 0 <= azimuth_deg < 360, "Geometry orientation domain")
    progress, azimuth = map(math.radians, (progress_deg, azimuth_deg))
    return np.asarray([math.sin(progress)*math.cos(azimuth), -math.cos(progress),
                       math.sin(progress)*math.sin(azimuth)])


def unit_up(value):
    result = array(value, (3,), "Geometry body-frame world up")
    require(abs(float(result @ result)-1.) <= 1e-12, "Geometry unit world up")
    return result


class PoseGeometry:
    """Own a bounded pose population and its body-frame rigid-tree geometry."""
    def __init__(self, spec, poses):
        self.tree = RigidTree(spec)
        tree = self.tree
        raw = np.asarray(poses)
        require(tree.n == 8 and raw.ndim == 2 and raw.shape[1] == tree.n
                and 1 <= len(raw) <= MAX_POSES, "Geometry pose population")
        self.poses = array(raw, raw.shape, "Geometry finite poses").copy()
        require(np.max(np.abs(self.poses)) <= .9, "Geometry normalized pose envelope")
        lower = np.asarray([j["lower_limit_rad"] for j in tree.joints])
        upper = np.asarray([j["upper_limit_rad"] for j in tree.joints])
        require((lower < 0).all() and (upper > 0).all(), "Geometry neutral joint pose")
        self.joints = np.where(self.poses >= 0, self.poses*upper, -self.poses*lower)
        self.positions = np.zeros((len(raw), len(tree.bodies), 3))
        self.rotations = np.zeros((len(raw), len(tree.bodies), 3, 3))
        self.rotations[:, 0] = np.eye(3)
        self.shapes = []
        for body in tree.bodies:
            shape = body["collision"]
            require(shape["kind"] in ("box", "capsule"), "Geometry unsupported collision")
            if shape["kind"] == "box":
                half = xyz(shape["size_m"])/2
                require((half > 0).all(), "Geometry positive box")
                self.shapes.append(("box", half))
            else:
                values = array([shape["length_m"]/2, shape["radius_m"]], (2,), "Geometry capsule")
                require((values > 0).all(), "Geometry positive capsule")
                self.shapes.append(("capsule", values))
        for i, joint in enumerate(tree.joints):
            parent, child = tree.parent[i], tree.child[i]
            x, y, z = xyz(joint["axis_parent_unit"])
            skew = np.asarray([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
            angles = self.joints[:, i, None, None]
            turns = np.eye(3)+np.sin(angles)*skew+(1-np.cos(angles))*(skew @ skew)
            self.rotations[:, child] = self.rotations[:, parent] @ turns
            anchor = self.positions[:, parent]+self.rotations[:, parent] @ xyz(joint["anchor_parent_m"])
            self.positions[:, child] = anchor-self.rotations[:, child] @ xyz(joint["anchor_child_m"])
        centers = self.positions+np.einsum("nbij,bj->nbi", self.rotations, tree.local_com)
        self.com = np.einsum("nbi,b->ni", centers, tree.mass)/sum(tree.mass)
        for value in (self.poses, self.joints, self.positions, self.rotations, self.com):
            value.setflags(write=False)

    def evaluate(self, up_body):
        up = unit_up(up_body)
        heights = np.einsum("nbi,i->nb", self.positions, up)
        extents = np.empty_like(heights)
        for index, (kind, shape) in enumerate(self.shapes):
            local_up = np.einsum("nji,j->ni", self.rotations[:, index], up)
            extents[:, index] = np.abs(local_up) @ shape if kind == "box" else np.abs(local_up[:, 1])*shape[0]+shape[1]
        lowest = heights-extents
        floor = -np.min(lowest, axis=1)
        return dict(floor_height_m=floor, com_height_m=floor+self.com @ up,
                    lowest_body_indices=np.argmin(lowest, axis=1))


def scalar_reference(spec, pose, up_body):
    """Independent scalar tree plus explicit box corners/capsule endpoints."""
    up = unit_up(up_body)
    cross = np.cross(up, [0., 1., 0.])
    length = float(np.linalg.norm(cross))
    if length <= 1e-14:
        quaternion = [0., 0., 0., 1.] if up[1] > 0 else [1., 0., 0., 0.]
    else:
        angle = math.acos(float(np.clip(up[1], -1., 1.)))
        quaternion = [*(cross/length*math.sin(angle/2)), math.cos(angle/2)]
    tree = RigidTree(spec)
    joints = [float(v)*(j["upper_limit_rad"] if v >= 0 else -j["lower_limit_rad"])
              for v, j in zip(pose, tree.joints, strict=True)]
    frame = tree.kinematics([0., 0., 0.], quaternion, joints)
    lows = []
    for body, position, rotation in zip(tree.bodies, frame["positions"], frame["rotations"], strict=True):
        shape = body["collision"]
        if shape["kind"] == "box":
            corners = np.asarray(list(itertools.product((-1., 1.), repeat=3)))*xyz(shape["size_m"])/2
            lows.append(float(np.min((position+corners @ rotation.T)[:, 1])))
        else:
            ends = np.asarray([[0., -shape["length_m"]/2, 0.], [0., shape["length_m"]/2, 0.]])
            lows.append(float(np.min((position+ends @ rotation.T)[:, 1]))-shape["radius_m"])
    floor = -min(lows)
    return dict(floor_height_m=floor, com_height_m=floor+float(frame["whole_body_com"][1]))


def interval_summary(table, tolerance_m=1e-9, tie_tolerance_m=1e-12):
    values = np.asarray(table)
    require(values.dtype.kind in "fiu" and values.ndim == 2 and min(values.shape) >= 2
            and np.isfinite(values).all(), "Geometry height table")
    require(type(tolerance_m) in (int, float) and type(tie_tolerance_m) in (int, float)
            and 0 < tie_tolerance_m < tolerance_m <= 1e-6, "Geometry numerical tolerances")
    changes = np.diff(values.astype(np.float64), axis=0)
    require(np.isfinite(changes).all(), "Geometry finite height differences")
    result = []
    for index, change in enumerate(changes):
        minimum = float(np.min(change))
        witness = int(np.flatnonzero(change <= minimum+tie_tolerance_m)[0])
        result.append(dict(interval=index, minimum_delta_com_height_m=minimum,
            witness_pose_index=witness, witness_delta_com_height_m=float(change[witness]),
            classification="ascending_for_all_sampled_poses" if minimum > tolerance_m else
                "descending_sample_exists" if minimum < -tolerance_m else "numerically_unresolved"))
    return result


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, indent=2)+"\n")


def observed_progress(retained, owner):
    """Posthoc boundary-angle summaries; never relabel the native eligibility."""
    c = owner["contract"]
    inventory = {b["path"]: b for b in owner["artifacts"]}
    rows = [dict(cell_id=m["cell_id"], body_id=m["body_id"], candidate_id=m["candidate_id"],
                 samples=0, maximum_progress_degrees=0.) for m in c["righting_metadata"]]
    for group in owner["preflight"]["batches"]:
        relative = f"native/{group['batch_id']}/controller.jsonl"
        require(sha(retained/relative) == inventory[relative]["sha256"], "Geometry native observation binding")
        with (retained/relative).open(encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                index = group["cell_indices"][row["cell"]]
                summary = rows[index]
                require(row["binding"]["cell_id"] == summary["cell_id"]
                        and row["outer_step"] == summary["samples"], "Geometry native boundary population")
                q = row["request"]["state"]["base_pose_world"]["orientation_xyzw"]
                q = array([q[k] for k in ("x", "y", "z", "w")], (4,), "Geometry observed quaternion")
                require(abs(float(q @ q)-1.) <= 1e-6, "Geometry observed quaternion norm")
                up = float(quaternion_rotation(q/np.linalg.norm(q))[1, 1])
                progress = math.degrees(math.acos(float(np.clip(-up, -1., 1.))))
                summary["maximum_progress_degrees"] = max(summary["maximum_progress_degrees"], progress)
                summary["samples"] += 1
    require(all(r["samples"] == c["outer_steps"] for r in rows), "Geometry incomplete native boundaries")
    return rows


def run(contract_path, output):
    contract_path = contract_path.resolve(strict=True)
    evidence = (ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    output = output.resolve()
    require(contract_path.is_relative_to(ROOT) and output.is_relative_to(evidence)
            and not output.exists() and output.parent.is_dir(), "Geometry source/output boundary")
    contract = json.loads(contract_path.read_bytes())
    require(contract["schema_version"] == "locolemotion_righting_geometry_v1"
            and re.fullmatch(r"[a-z][a-z0-9_]{0,95}", contract["campaign_id"])
            and contract["runtime_numpy"] == np.__version__, "Geometry declaration identity/runtime")
    require(contract["progress_degrees"] == list(range(0, 181, 5))
            and contract["azimuth_degrees"] == list(range(0, 360, 45))
            and all(contract[k] is False for k in FALSE_FLAGS), "Geometry declared scope")
    require(contract["ledger_scope"] == dict(subsystem="discovery", engine_scope="core",
            authority_mode="zero_world_geometry_diagnostic", question_class="development"),
            "Geometry authority boundary")
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
    require(git("rev-parse", "--show-toplevel") == ROOT.as_posix()
            and git("remote", "get-url", "origin") == "https://github.com/Slagathore/LoColemotion.git"
            and git("config", "core.hooksPath") == ".githooks", "Geometry repository identity")
    source, status = git("rev-parse", "HEAD"), git("status", "--porcelain")
    predecessor_path = ROOT/contract["predecessor"]["path"]
    require(predecessor_path.resolve().is_relative_to(ROOT)
            and sha(predecessor_path) == contract["predecessor"]["sha256"], "Geometry predecessor binding")
    predecessor = json.loads(predecessor_path.read_bytes())
    retained = (evidence/predecessor["archive_relative_path"]).resolve(strict=True)
    require(retained.is_relative_to(evidence) and sha(retained/"receipt.json") == predecessor["receipt_sha256"]
            and sha(retained/"independent-audit.json") == predecessor["independent_audit_sha256"], "Geometry retained inputs")
    owner = json.loads((retained/"receipt.json").read_bytes())
    require(owner["ok"] is True and owner["source_runtime_unchanged"] is True, "Geometry native predecessor incomplete")
    files = [contract_path, Path(__file__).resolve(), ROOT/"sdk/discovery/test_creature_righting_geometry.py",
             ROOT/"sdk/discovery/actuation_recovery_mechanics.py", predecessor_path]
    pins = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
    runtime_files = {"python_launcher": Path(sys.executable), "python_base": Path(sys._base_executable),
                     "numpy_package": Path(np.__file__), "numpy_core": Path(np._core._multiarray_umath.__file__)}
    runtime_pins = {key: dict(path=str(path), sha256=sha(path)) for key, path in runtime_files.items()}
    pool = contract["pose_pool"]
    poses = pose_pool(pool["limb_states"], pool["uniform_count"], pool["edge_count"], pool["seed"])
    output.mkdir()
    for path in files:
        target = output/"source"/path.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(path.read_bytes())
    write_new(output/"declaration.json", dict(contract=contract, source_commit=source,
        source_status=status.splitlines(), source_pins=pins, runtime_pins=runtime_pins,
        python=sys.version, numpy=np.__version__))
    with (output/"poses.npy").open("xb") as stream:
        np.save(stream, poses, allow_pickle=False)
    artifacts = [dict(path="poses.npy", sha256=sha(output/"poses.npy"), bytes=(output/"poses.npy").stat().st_size)]
    inventory = {b["path"]: b for b in owner["artifacts"]}
    c = owner["contract"]
    rows = [m for m in c["righting_metadata"] if m["condition_index"] == m["start_index"] == m["candidate_index"] == 0]
    require(len(rows) == contract["body_count"] == 16, "Geometry body denominator")
    bodies, reference_checks, started = [], 0, time.monotonic()
    for metadata in rows:
        global_index = next(i for i, m in enumerate(c["righting_metadata"]) if m["cell_id"] == metadata["cell_id"])
        group = next(g for g in owner["preflight"]["batches"] if global_index in g["cell_indices"])
        slot = group["cell_indices"].index(global_index)
        relative = f"native/{group['batch_id']}/cell_{slot}/creature.json"
        require(sha(retained/relative) == inventory[relative]["sha256"], "Geometry original body bytes")
        creature = json.loads((retained/relative).read_bytes())
        require(creature["descriptor"] == c["cells"][global_index]["descriptor"], "Geometry crossed body")
        spec = creature["compiled"]["morphology"]["morphology_spec"]
        model = PoseGeometry(spec, poses)
        table = np.empty((len(contract["azimuth_degrees"]), len(contract["progress_degrees"]), len(poses)))
        directions = []
        for ai, azimuth in enumerate(contract["azimuth_degrees"]):
            for pi, progress in enumerate(contract["progress_degrees"]):
                table[ai, pi] = model.evaluate(gravity_direction(progress, azimuth))["com_height_m"]
            intervals = interval_summary(table[ai], contract["numerical_tolerance_m"], contract["tie_tolerance_m"])
            for row in intervals:
                pi, witness = row["interval"], row["witness_pose_index"]
                row.update(from_degrees=contract["progress_degrees"][pi], to_degrees=contract["progress_degrees"][pi+1])
                for index in (pi, pi+1):
                    expected = scalar_reference(spec, poses[witness], gravity_direction(contract["progress_degrees"][index], azimuth))
                    require(abs(expected["com_height_m"]-table[ai, index, witness]) <= 2e-12, "Geometry scalar witness mismatch")
                    reference_checks += 1
            directions.append(dict(azimuth_degrees=azimuth, intervals=intervals))
        filename = f"body_{metadata['body_index']:02d}_heights.npy"
        with (output/filename).open("xb") as stream:
            np.save(stream, table, allow_pickle=False)
        artifacts.append(dict(path=filename, sha256=sha(output/filename), bytes=(output/filename).stat().st_size))
        bodies.append(dict(body_index=metadata["body_index"], body_id=metadata["body_id"],
            body_shape_sha256=creature["binding"]["body_shape_sha256"], input_file=relative,
            input_sha256=inventory[relative]["sha256"], table_file=filename, directions=directions))
        print(json.dumps(dict(body=metadata["body_id"], poses=len(poses), completed=len(bodies))), flush=True)
    observations = observed_progress(retained, owner)
    require(pins == {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
            and runtime_pins == {key: dict(path=str(path), sha256=sha(path)) for key, path in runtime_files.items()}
            and git("rev-parse", "HEAD") == source and git("status", "--porcelain") == status, "Geometry source drift")
    result = dict(schema_version="locolemotion_righting_geometry_result_v1", ledger_scope=contract["ledger_scope"],
        ok=True, source_commit=source, source_runtime_unchanged=True, contract_sha256=sha(contract_path),
        source_pins=pins, runtime_pins=runtime_pins, predecessor=contract["predecessor"],
        pose_count=len(poses), body_count=len(bodies),
        configurations_evaluated=len(poses)*len(bodies)*table.shape[0]*table.shape[1],
        scalar_witness_checks=reference_checks, bodies=bodies, artifacts=artifacts,
        observed_native_boundaries=observations, observed_boundary_count=sum(r["samples"] for r in observations),
        observed_boundaries_are_posthoc=True, wall_s=time.monotonic()-started,
        world_build_count=0, solver_steps=0, **{key: False for key in FALSE_FLAGS},
        limits=contract["limits"])
    write_new(output/"result.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    report = run(args.contract, args.output)
    print(json.dumps({k: report[k] for k in ("ok", "pose_count", "body_count", "configurations_evaluated",
                                            "scalar_witness_checks", "world_build_count", "wall_s")}))
