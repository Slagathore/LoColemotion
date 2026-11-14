"""Compare retained force proposals with solved reactions; open no worlds.

The chosen axis and modeled center of mass are held at the prepared decision
for all five solved substeps. These posthoc measurements do not change scores.
"""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import xml.etree.ElementTree as ET

import mujoco
import numpy as np

from actuation_recovery_mechanics import RigidTree, quaternion_rotation, xyz
from creature_body_moment_diagnosis import bound_archive
import creature_contact_reactions as reactions
from creature_trajectory_diagnosis import require
from sporespore_mujoco_adapter.selected_policy_development import _canonical_to_mujoco

ROLES = ("requested_feet", "unrequested_feet", "torso", "upper_legs", "net")
GEOMS = ["ground", "torso_geom"] + [f"{limb}_{part}_geom"
    for limb in ("front_left", "front_right", "rear_left", "rear_right")
    for part in ("upper", "distal")]


def prepared(row, profile, tree):
    """Reconstruct the proposed moment, independent of the cone's scalar sum."""
    state = row["request"]["state"]
    decision = row["resolution"]["body_moment"]
    require(decision["torque_map"]["policy"] == profile["torque_map"], "Reaction profile binding")
    pose = state["base_pose_world"]
    quaternion = [pose["orientation_xyzw"][k] for k in "xyzw"]
    frame = tree.kinematics(xyz(pose["position_m"]), quaternion,
                           [j["position_rad"] for j in state["ordered_joint_observations"]])
    sign = decision["state_after"]["sign"]
    require(type(sign) is int and sign in (-1, 1), "Reaction chosen sign")
    axis = _canonical_to_mujoco(quaternion_rotation(quaternion) @ (np.asarray(profile["axis_body"])*sign))
    require(abs(float(axis @ axis)-1.) < 1e-10, "Reaction unit axis")
    center = _canonical_to_mujoco(frame["whole_body_com"])
    active = decision["active_limbs"]
    require(all(type(i) is int and 0 <= i < 4 for i in active)
            and len(set(active)) == len(active)
            and active == decision["torque_map"]["active_limbs"], "Reaction active limbs")
    forces = np.zeros((10, 3)); moment = np.zeros(3)
    require(len(decision["requested_wrenches"]) == len(active), "Reaction wrench population")
    for limb, wrench in zip(active, decision["requested_wrenches"], strict=True):
        geom = 3+2*limb
        require(wrench["body_id"]+"_geom" == GEOMS[geom], "Reaction wrench body")
        force, point, torque = [_canonical_to_mujoco(wrench[k]) for k in ("force", "point", "torque")]
        require(np.isfinite([force, point, torque]).all(), "Reaction finite wrench")
        forces[geom] = force
        moment += np.cross(point-center, force)+torque
    proposed = float(moment @ axis)
    require(np.isfinite(proposed) and np.isclose(proposed, decision["proposed_moment_nm"], atol=1e-9, rtol=1e-9)
            and (proposed > 0.) == bool(active), "Reaction reconstructed proposed moment")
    return dict(axis=axis, center=center, active=active, forces=forces, proposed=proposed,
        proposal_reconstruction_error_nm=abs(proposed-decision["proposed_moment_nm"]),
        prepared_com_error_m=float(np.linalg.norm(center-np.asarray(row["native_observation"]["subtree_com"][1]))),
        predicted_torque=reactions.array(decision["post_guard_predicted_torque_nm"], (8,)))


def measured(model, decoded, reaction, native):
    """Move moments to one reference before summing; torque is a pseudovector."""
    force = decoded["force_by_geom"]
    shifted = decoded["moment_by_geom"] + np.cross(np.asarray(reaction["center_of_mass"])-model["center"], force)
    projected = shifted @ model["axis"]
    active = [3+2*i for i in model["active"]]
    others = [i for i in (3, 5, 7, 9) if i not in active]
    roles = [float(sum(projected[indices])) for indices in (active, others, [1], [2, 4, 6, 8])]
    roles.append(float(sum(projected)))
    require(np.isclose(sum(roles[:4]), roles[4], atol=1e-10, rtol=1e-10), "Reaction role partition")
    joints = [j for i in model["active"] for j in (2*i, 2*i+1)]
    actual = reactions.array(native["actuator_force_nm"], (8,))
    return dict(moment_by_role_nm=roles,
        net_moment_about_solved_com_nm=float(np.sum(decoded["moment_by_geom"], axis=0) @ model["axis"]),
        com_motion_from_prepared_m=float(np.linalg.norm(np.asarray(reaction["center_of_mass"])-model["center"])),
        active_force_error_n=float(np.mean(np.linalg.norm(force[active]-model["forces"][active], axis=1))) if active else None,
        active_torque_error_nm=float(np.mean(np.abs(actual[joints]-model["predicted_torque"][joints]))) if joints else None,
        all_joint_torque_error_nm=float(np.mean(np.abs(actual-model["predicted_torque"]))))


def joined(controller, native, reaction, cell, outer, sub, previous):
    require(controller["cell"] == native["cell"] == reaction["cell"] == cell
        and controller["outer_step"] == controller["request"]["state"]["semantic_step"] == outer
        and native["step"] == reaction["step"] == 5*outer+sub+1, "Reaction stream order")
    expected = controller["native_observation"] if sub == 0 else previous
    require(all(native["before_"+k] == expected[k] for k in ("qpos", "qvel")), "Reaction prepared/solved continuity")
    if sub == 0 and previous is not None:
        require(all(expected[k] == previous[k] for k in ("qpos", "qvel")), "Reaction interval continuity")
    require(native["ctrl"] == np.asarray(controller["native_targets"], dtype=np.float32).astype(float).tolist(),
            "Reaction held command")


class Summary:
    def __init__(self):
        self.rows = []

    def add(self, row):
        samples = row["samples"]
        require(len(samples) == 5, "Reaction five solved substeps")
        moments = np.asarray([s["moment_by_role_nm"] for s in samples])
        require(moments.shape == (5, 5) and np.isfinite(moments).all(), "Reaction finite interval")
        self.rows.append(dict(proposed=row["proposed_moment_nm"], first=moments[0], mean=moments.mean(axis=0),
            force=[s["active_force_error_n"] for s in samples], torque=[s["active_torque_error_nm"] for s in samples],
            actual_com=[s["net_moment_about_solved_com_nm"] for s in samples],
            com=max(s["com_motion_from_prepared_m"] for s in samples)))

    def finish(self):
        result = {}
        for name, active in (("positive_request", True), ("no_request", False)):
            rows = [r for r in self.rows if (r["proposed"] > 0.) == active]
            if not rows:
                result[name] = dict(intervals=0); continue
            first, mean = [np.asarray([r[k] for r in rows]) for k in ("first", "mean")]
            proposed = np.asarray([r["proposed"] for r in rows])
            value = dict(intervals=len(rows), proposed_moment_mean_nm=float(proposed.mean()),
                first_moment_mean_by_role_nm=dict(zip(ROLES, first.mean(axis=0).tolist())),
                held_moment_mean_by_role_nm=dict(zip(ROLES, mean.mean(axis=0).tolist())),
                held_net_moment_about_solved_com_mean_nm=float(np.mean([r["actual_com"] for r in rows])),
                held_net_nonpositive_intervals=int(np.sum(mean[:, 4] <= 0.)),
                held_net_range_nm=[float(mean[:, 4].min()), float(mean[:, 4].max())],
                maximum_com_motion_m=max(r["com"] for r in rows))
            if active:
                value.update(first_active_force_error_mean_n=float(np.mean([r["force"][0] for r in rows])),
                    held_active_force_error_mean_n=float(np.mean([r["force"] for r in rows])),
                    first_active_torque_error_mean_nm=float(np.mean([r["torque"][0] for r in rows])),
                    held_active_torque_error_mean_nm=float(np.mean([r["torque"] for r in rows])),
                    held_requested_feet_moment_error_mean_nm=float(np.mean(np.abs(mean[:, 0]-proposed))))
            result[name] = value
        return result


def diagnose(root, digest, intervals):
    archive, receipt = bound_archive(root, digest)
    contract, audit = receipt["contract"], receipt["audit"]
    require(reactions.enabled(contract) and audit["capture"]["controller_replay_verified"]
            and audit["capture"]["detailed_native_capture_verified"]
            and contract["internal_steps_per_outer"] == 5, "Reaction full replayed capture")
    episodes, cells = audit["assessment"]["episodes"], contract["cells"]
    require([i for g in receipt["worker"]["groups"] for i in g["cell_indices"]] == list(range(len(cells)))
            and len(episodes) == len(cells), "Reaction archive population")
    results = []; counts = dict(controller=0, native=0, modeled=0)
    maxima = dict(proposal_reconstruction_error_nm=0., prepared_com_error_m=0., force_balance_error_n=0., moment_balance_error_nm=0.)
    for group in receipt["worker"]["groups"]:
        prefix = "native/"+group["batch_id"]; indices = group["cell_indices"]
        creatures = [archive.document(prefix+f"/cell_{i}/creature.json") for i in range(len(indices))]
        require(all(c["spec"]["geom_names"] == GEOMS for c in creatures), "Reaction geometry roles")
        trees = [RigidTree(c["compiled"]["morphology"]["morphology_spec"]) for c in creatures]
        cones = [{"pyramidal": 0, "elliptic": 1}[ET.fromstring(c["model_xml"]).find("option").attrib["cone"]] for c in creatures]
        summaries = [Summary() for _ in indices]; previous = [None for _ in indices]
        streams = [iter(archive.lines(prefix+"/"+name+".jsonl")) for name in ("controller", "trace", "reactions")]
        for outer in range(contract["outer_steps"]):
            controllers, models, rows = [], [], []
            for local, index in enumerate(indices):
                row = json.loads(next(streams[0])); cell = cells[index]
                require(row["binding"] == dict(creatures[local]["binding"], cell_id=cell["cell_id"], candidate_id=cell["profile"]["id"])
                        and row["binding"]["cell_id"] == episodes[index]["cell_id"], "Reaction controller identity")
                model = prepared(row, cell["profile"], trees[local]) if "torque_map" in cell["profile"] else None
                controllers.append(row); models.append(model); counts["controller"] += 1
                out = None
                if model is not None:
                    out = dict(cell_id=cell["cell_id"], outer_step=outer, active_limbs=model["active"],
                        axis_world=model["axis"].tolist(), prepared_modeled_com_m=model["center"].tolist(),
                        proposed_moment_nm=model["proposed"], samples=[])
                    counts["modeled"] += 1
                    for k in ("proposal_reconstruction_error_nm", "prepared_com_error_m"):
                        maxima[k] = max(maxima[k], model[k])
                rows.append(out)
            for sub in range(5):
                for local in range(len(indices)):
                    native, reaction = [json.loads(next(stream)) for stream in streams[1:]]
                    joined(controllers[local], native, reaction, local, outer, sub, previous[local])
                    decoded = reactions.verify(reaction, native, creatures[local]["binding"], cones[local], GEOMS)
                    for field, target in (("force_balance_error", "force_balance_error_n"), ("moment_balance_error", "moment_balance_error_nm")):
                        maxima[target] = max(maxima[target], decoded[field])
                    if models[local] is not None:
                        rows[local]["samples"].append(measured(models[local], decoded, reaction, native))
                    previous[local] = native; counts["native"] += 1
            for local, row in enumerate(rows):
                if row is not None:
                    summaries[local].add(row)
                    intervals.write(json.dumps(row, separators=(",", ":"), allow_nan=False)+"\n")
        # Exhaust each generator: its final read verifies the complete file hash.
        for stream in streams:
            require(next(stream, None) is None, "Reaction extra stream rows")
        for local, index in enumerate(indices):
            results.append(dict(frozen_episode=episodes[index], model_compared=bool(summaries[local].rows),
                                reaction_comparison=summaries[local].finish()))
        print(json.dumps(dict(batch=group["batch_id"], **counts)), flush=True)
    require(counts["controller"] == audit["controller_rows_replayed"]
            and counts["native"] == audit["native_rows_verified"]
            and counts["modeled"] == contract["outer_steps"]*sum("torque_map" in c["profile"] for c in cells),
            "Reaction final denominators")
    return dict(ok=True, schema_version="locolemotion_contact_reactions_diagnosis_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp", authority_mode="retained_motion_diagnostic", question_class="development"),
        native_source_commit=receipt["source_commit"], source_receipt_sha256=digest,
        world_build_count=0, solver_steps=0, counts=counts, maxima=maxima, outcomes=results,
        input_files=list(archive.verified.values()), moment_role_order=ROLES,
        reference="Native world z-up; chosen signed axis and modeled COM held at preparation for five solved substeps. First sample and equal-weight five-sample mean are separate. Forces act on the robot. Net contains feet, torso and upper links; gravity has zero moment about instantaneous whole-body COM. No inertial/gravity balance is claimed about the held reference.",
        model_limits="Requested forces are static proposals; native constraint forces solve coupled contact and motion. Model gravity is 9.81 m/s2, native gravity is 9.8 m/s2. Errors average each active limb/joint within an interval, then equally across intervals. Nonpositive counts are descriptive signs, not qualification thresholds. Reference profiles are retained but not interpreted through torque-map semantics.",
        eligibility_changed=False, recovery_qualified=False, controller_adopted=False,
        training_data_authority=False, physical_acceptance_authority=False, release_authority=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--receipt-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(); args.output.mkdir()
    with ExitStack() as stack:
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            stack.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in retained reaction diagnosis")))
        path = args.output/"intervals.jsonl"
        with path.open("x", encoding="utf-8", newline="\n") as stream:
            result = diagnose(args.archive, args.receipt_sha256, stream)
    result["intervals"] = dict(path=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), byte_length=path.stat().st_size)
    with (args.output/"result.json").open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False); stream.write("\n")
    print(json.dumps(dict(ok=True, counts=result["counts"], maxima=result["maxima"])))


if __name__ == "__main__":
    main()
