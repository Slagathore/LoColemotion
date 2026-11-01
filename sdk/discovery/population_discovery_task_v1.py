"""Frozen broad discovery population and reduced-recording evidence contract.

Only serialization is reduced. Every prepared observation and all five native
substeps still pass the live validators. Compact records cannot become training
or qualification evidence; a selected policy needs a fresh full-capture run.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import random

from gpu_quadruped_model import ROOT, FLAGS, sha, f32
from gpu_quadruped_probe import check_capture
from audit_gpu_batch_execution import finite_vector
from audit_gpu_portable_search import require

HERE = Path(__file__).resolve().parent
CONTRACT = HERE / "population_discovery_v1.json"
PARENT = HERE / "gpu_motor_effectiveness_v1.json"
PARENT_SHA = "ec1a00d8c63d0ba5b35b4c87e304538c4c15a414b8c8cd33fc8d63850d6cf269"
SOURCES = ["population_discovery_task_v1.py", "population_discovery_v1.py",
           "audit_population_discovery_v1.py", "run_population_discovery_v1.py",
           "test_population_discovery_v1.py"]
GATES = [
    ("measurement", "test_actuation_measurement", 7),
    ("quadruped", "test_gpu_quadruped_probe", 10),
    ("portable", "test_portable_search", 11),
    ("host-batch", "test_portable_batch", 7),
    ("graph-execution", "test_gpu_batch_execution", 7),
    ("repertoire", "test_gpu_repertoire_v2", 6),
    ("motor-task", "test_motor_effectiveness_task", 7),
    ("motor-route", "test_gpu_motor_effectiveness", 5),
    ("stage-lifecycle", "test_contained_stage_owner_v2", 17),
    ("containment", "test_contact_sequence_containment_v2", 1),
    ("provider", "adaptation_provider.test_conformance", 2),
    ("population", "test_population_discovery_v1", 20),
]


def population():
    """63 stratified joint vectors plus a true absent-provider baseline.

    Independent permutations spread each joint over its full declared interval.
    The generator seed and algorithm are fixed before any world is constructed.
    """
    rng = random.Random(1061101)
    columns = []
    for _ in range(8):
        column = list(range(63))
        rng.shuffle(column)
        columns.append(column)
    candidates = [dict(id="baseline", factor=None, ordered_coefficients=[0.] * 8)]
    for index in range(63):
        candidates.append(dict(id=f"joint_population_{index + 1:02d}", factor=0.,
            ordered_coefficients=[-.25 + .5 * (column[index] + .5) / 63 for column in columns]))
    return candidates


def expected_declaration():
    return dict(schema_version="locolemotion_population_discovery_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp",
                          authority_mode="development_discovery", question_class="development"),
        parent=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        seed=1061101, population=population(), population_size=64, batch_size=16,
        genome="eight independent multipliers of current canonical baseline joint velocity",
        coefficient_bounds=[-.25, .25], maximum_absolute_correction_rad_s=.25,
        maximum_slew_per_step_rad_s=.02, outer_steps=240, horizon_s=2.,
        internal_steps_per_outer=5, conditions=["nominal", "left_075"],
        starts=[dict(id="train_001", lateral_velocity_m_s=.001),
                dict(id="train_003", lateral_velocity_m_s=.003)],
        reserved_starts=[.0015, .0025, .0045, .0055], excluded_confirmation_starts=[.002, .005],
        canaries=dict(candidate_indices=[0, 1, 21, 42], start_id="train_001",
                      outer_steps=240, modes=["full", "compact"], compact_records_must_match_bitwise=True),
        planned_population_worlds=256, planned_canary_worlds=16,
        capture=dict(profile="compact_serialization_v1", native_reads_reduced=False,
            device_history_reduced=False, substeps_discarded=False, buffering_changed=False,
            retained="every solver input, prepared and completed boundary state, five sample clocks and metrics",
            full_canary="all controller requests, native observations, internal state, force and contact rows",
            qualification_requires_fresh_full_capture=True),
        selection=dict(minimum_height_m=.25, maximum_tilt_rad=.6,
            maximum_torso_contact_steps=0, maximum_safe_no_actuation_steps=0,
            minimum_ground_contact_steps=1, minimum_nonzero_force_steps=1,
            shortlist_per_condition=2, minimum_mean_absolute_coefficient_distance=.10,
            objective="minimize whole-episode planar velocity error to [0.2,0] across both exposed starts",
            eligibility="complete and eligible on both starts of the same condition; baseline is comparator only",
            tie_break="candidate_index", minimum_gain_over_baseline_m_s=0.,
            empty_shortlist_allowed=True),
        failure_policy="retain expected performance failures through the fixed horizon; invalid execution stops the phase",
        safety_controls=[dict(name=name, module=module, count=count) for name, module, count in GATES],
        safety_control_count=sum(count for _, _, count in GATES),
        production_entrypoints=["condition_inputs", "RepertoireController.step", "mjw.step1", "mjw.step2",
            "SubstepHistory", "LiveBlock.reduce", "compact_trial", "audit_gpu_motor_effectiveness.audit_trial"],
        coverage=["fresh per-world controller and solver state", "bounded joint corrections through actual scalar and batch ABI",
            "both declared actuator profiles", "force sampling before subsequent prepare", "complete contact attribution",
            "native capacity, finite values, solver input, clock and state continuity", "retained-handle owner cleanup",
            "recording cost measured with two predetermined full/compact pairs", "all trials retained and complete ranking"],
        not_covered=["reduced GPU readback", "longer than two seconds", "CPU physical transfer", "learned controller selection",
            "other terrain or morphology", "calibration or evaluation", "recovery success or safe withdrawal", "qualification"],
        maximum_worker_wall_seconds=3600, maximum_reader_wall_seconds=900,
        maximum_trace_bytes_per_trial=268435456, minimum_free_storage_bytes=8 * 2**30,
        scope="candidate discovery only; no fitted memory, online choice, held-out evidence or release",
        **{key: False for key in FLAGS})


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration() and sha(PARENT) == PARENT_SHA, "Population declaration or parent drift")
    c = json.loads(PARENT.read_text(encoding="utf-8"))
    # Reuse model and controller settings, never the consumed parent's campaign.
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], outer_steps=d["outer_steps"], warmup_outer_steps=0,
        provider=dict(kind="untrained_joint_population_v1", candidates=d["population"],
            maximum_absolute_correction_rad_s=d["maximum_absolute_correction_rad_s"],
            maximum_slew_per_step_rad_s=d["maximum_slew_per_step_rad_s"]),
        conditions=[r for r in c["conditions"] if r["condition_id"] in d["conditions"]],
        selection=d["selection"], maximum_trace_bytes_per_trial=d["maximum_trace_bytes_per_trial"],
        purpose=d["scope"], training_scope="none", corpus="reduced discovery records are not fitting data",
        **{key: False for key in FLAGS})
    return c


def plans(c, phase):
    require(phase in ("canaries", "population"), "Unknown population phase")
    d = c["challenge"]
    rows = []
    for ci, condition in enumerate(d["conditions"]):
        starts = d["starts"][:1] if phase == "canaries" else d["starts"]
        for si, start in enumerate(starts):
            batches = [d["canaries"]["candidate_indices"]] if phase == "canaries" else [
                list(range(begin, begin + d["batch_size"])) for begin in range(0, d["population_size"], d["batch_size"])]
            for bi, indices in enumerate(batches):
                # Reverse the order for the second condition to expose warmup bias.
                modes = (["full", "compact"] if ci == 0 else ["compact", "full"]) if phase == "canaries" else ["compact"]
                group = f"{condition}_{start['id']}_b{bi:02d}"
                for mode in modes:
                    rows.append(dict(trial_id=f"{group}_{mode}", group_id=group, phase=phase,
                        partition="exposed_development", condition_id=condition, start_id=start["id"],
                        seed=d["seed"] + si, arm="batch_graph", capture_mode=mode, nworld=len(indices),
                        candidate_indices=indices, initial_native_roll_rad=0.,
                        initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
                        outer_steps=d["canaries"]["outer_steps"] if phase == "canaries" else c["outer_steps"]))
    return rows


def failure_codes(metric, c):
    s = c["selection"]
    return [name for name, failed in [
        ("height", metric["minimum_height_m"] < s["minimum_height_m"]),
        ("tilt", metric["maximum_tilt_rad"] > s["maximum_tilt_rad"]),
        ("torso_contact", metric["torso_contact_steps"] > s["maximum_torso_contact_steps"]),
        ("safe_no_actuation", metric["safe_no_actuation_steps"] > s["maximum_safe_no_actuation_steps"]),
        ("no_ground_contact", metric["ground_contact_steps"] < s["minimum_ground_contact_steps"]),
        ("no_actuator_force", metric["nonzero_force_steps"] < s["minimum_nonzero_force_steps"])] if failed]


class LiveBlock:
    """Validate all raw native rows before selecting the smaller retained record."""
    def __init__(self, c, plan, spec):
        self.c, self.plan, self.spec = c, plan, spec
        self.prior = [None] * plan["nworld"]
        self.outer = 0

    def reduce(self, controls, samples):
        c, p = self.c, self.plan
        require(len(controls) == p["nworld"] and len(samples) == 5 * p["nworld"], "Live block denominator")
        caps = [[f32(v) for v in pair] for pair in self.spec["force_ranges"]]
        cfg = dict(c, naconmax=p["nworld"] * c["naconmax_per_world"])
        result = []
        for cell, control in enumerate(controls):
            require((control["cell"], control["outer_step"], control["backend"]) == (cell, self.outer, "gpu"), "Live controller order")
            candidate = c["provider"]["candidates"][p["candidate_indices"][cell]]
            result.append(dict(cell=cell, candidate_id=candidate["id"], outer_step=self.outer,
                native_targets=list(map(f32, control["native_targets"])),
                prepared_time_s=control["native_observation"]["time_s"],
                prepared_qpos=control["native_observation"]["qpos"],
                prepared_qvel=control["native_observation"]["qvel"],
                safe_no_actuation=control["output"]["actuation"]["safe_no_actuation"], samples=[]))
        for index, row in enumerate(samples):
            sub, cell = divmod(index, p["nworld"])
            step = self.outer * 5 + sub + 1
            require((row["step"], row["cell"], row["backend"]) == (step, cell, "gpu"), "Live native order")
            check_capture(row, cfg, caps)
            for key, size in [("qpos", 15), ("before_qpos", 15), ("qvel", 14), ("before_qvel", 14), ("ctrl", 8)]:
                require(finite_vector(row[key], size), "Live native vector")
            prior = self.prior[cell]
            expected_pos = prior["qpos"] if prior else list(map(f32, self.spec["initial_qpos"]))
            expected_vel = prior["qvel"] if prior else [0., f32(p["initial_native_lateral_velocity_m_s"])] + [0.] * 12
            require(row["before_qpos"] == expected_pos and row["before_qvel"] == expected_vel, "Live state continuity")
            compact = result[cell]
            require(row["ctrl"] == compact["native_targets"], "Live held solver input")
            if sub == 0:
                require(row["before_qpos"] == compact["prepared_qpos"] and row["before_qvel"] == compact["prepared_qvel"], "Live prepared state join")
            eps = 2**-23
            require(abs(row["time_s"] - step * c["timestep_s"]) <= 4 * eps * step * step * c["timestep_s"], "Live native clock")
            require(abs(sum(x*x for x in row["qpos"][3:7]) - 1.) <= 128 * eps, "Live quaternion")
            require(row["on_force_cap"] == [f <= lo or f >= hi for f, (lo, hi) in zip(row["actuator_force_nm"], caps, strict=True)], "Live force-cap labels")
            if cell == 0:
                slots, batch_count = [], row["batch_contacts"]
            require(row["batch_contacts"] == batch_count, "Live contact counter join")
            for contact in row["contacts"]:
                pair = contact["geom"]
                require(type(contact["world"]) is int and contact["world"] == cell
                    and type(contact["native_index"]) is int and 0 <= contact["native_index"] < batch_count
                    and len(pair) == 2 and 0 in pair and pair[0] != pair[1]
                    and all(type(g) is int and 0 <= g < 10 for g in pair)
                    and finite_vector(contact["position_m"], 3) and finite_vector(contact["frame"], 9)
                    and math.isfinite(contact["distance_m"]), "Live contact identity or data")
                slots.append(contact["native_index"])
            if cell == p["nworld"] - 1:
                require(sorted(slots) == list(range(batch_count)), "Live contact population")
            compact["samples"].append(dict(time_s=row["time_s"], height_m=row["qpos"][2],
                tilt_rad=math.acos(max(-1., min(1., 1 - 2 * (row["qpos"][4]**2 + row["qpos"][5]**2)))),
                torso_contact=any(1 in contact["geom"] for contact in row["contacts"]),
                ground_contact=bool(row["contacts"]), nonzero_force=any(f != 0. for f in row["actuator_force_nm"]),
                force_cap_count=sum(row["on_force_cap"])))
            compact.update(completed_qpos=row["qpos"], completed_qvel=row["qvel"])
            self.prior[cell] = row
        self.outer += 1
        return result


def summarize(rows, c, plan, spec):
    """Rebuild finite outcomes from compact records; do not infer missing forces."""
    metrics = [dict(minimum_height_m=math.inf, maximum_tilt_rad=0., torso_contact_steps=0,
        ground_contact_steps=0, nonzero_force_steps=0, safe_no_actuation_steps=0,
        forward_displacement_m=0.) for _ in range(plan["nworld"])]
    prior = [None] * plan["nworld"]
    first_failure = [None] * plan["nworld"]
    count = 0
    for index, row in enumerate(rows):
        outer, cell = divmod(index, plan["nworld"])
        candidate = c["provider"]["candidates"][plan["candidate_indices"][cell]]
        require(outer < plan["outer_steps"] and (row["cell"], row["outer_step"], row["candidate_id"]) ==
                (cell, outer, candidate["id"]), "Compact population or identity")
        require(type(row["safe_no_actuation"]) is bool and len(row["samples"]) == 5, "Compact safety/sample denominator")
        for key, size in [("prepared_qpos", 15), ("prepared_qvel", 14), ("completed_qpos", 15),
                          ("completed_qvel", 14), ("native_targets", 8)]:
            require(finite_vector(row[key], size), "Compact vector")
        last = prior[cell]
        require(row["prepared_qpos"] == (last["completed_qpos"] if last else list(map(f32, spec["initial_qpos"])))
            and row["prepared_qvel"] == (last["completed_qvel"] if last else
                [0., f32(plan["initial_native_lateral_velocity_m_s"])] + [0.] * 12), "Compact boundary continuity")
        eps = 2**-23
        require(math.isfinite(row["prepared_time_s"]) and abs(row["prepared_time_s"] - outer*5*c["timestep_s"])
                <= 4*eps*max(1, outer*5)**2*c["timestep_s"], "Compact prepared clock")
        m = metrics[cell]
        m["safe_no_actuation_steps"] += int(row["safe_no_actuation"])
        for sub, sample in enumerate(row["samples"]):
            step = outer*5 + sub + 1
            require(all(type(sample[k]) in (int, float) and math.isfinite(sample[k]) for k in ("time_s", "height_m", "tilt_rad"))
                and 0 <= sample["tilt_rad"] <= math.pi and abs(sample["time_s"] - step*c["timestep_s"]) <= 4*eps*step*step*c["timestep_s"]
                and all(type(sample[k]) is bool for k in ("torso_contact", "ground_contact", "nonzero_force"))
                and type(sample["force_cap_count"]) is int and 0 <= sample["force_cap_count"] <= 8, "Compact native sample")
            m["minimum_height_m"] = min(m["minimum_height_m"], sample["height_m"])
            m["maximum_tilt_rad"] = max(m["maximum_tilt_rad"], sample["tilt_rad"])
            for key in ("torso_contact", "ground_contact", "nonzero_force"):
                m[key + "_steps"] += int(sample[key])
            if first_failure[cell] is None and any(code not in ("no_ground_contact", "no_actuator_force") for code in failure_codes(m, c)):
                first_failure[cell] = step
        require(row["samples"][-1]["height_m"] == row["completed_qpos"][2], "Compact endpoint height")
        m["forward_displacement_m"] = row["completed_qpos"][0] - spec["initial_qpos"][0]
        prior[cell] = row
        count += 1
    require(count == plan["nworld"] * plan["outer_steps"], "Incomplete compact population")
    episodes = []
    duration = plan["outer_steps"] * 5 * c["timestep_s"]
    for cell, m in enumerate(metrics):
        failures = failure_codes(m, c)
        end = prior[cell]["completed_qpos"]
        error = math.hypot((end[0] - spec["initial_qpos"][0])/duration - .2,
                           (end[1] - spec["initial_qpos"][1])/duration)
        episodes.append(dict(candidate_index=plan["candidate_indices"][cell],
            candidate_id=c["provider"]["candidates"][plan["candidate_indices"][cell]]["id"],
            cell=cell, condition_id=plan["condition_id"], start_id=plan["start_id"], seed=plan["seed"],
            eligible=not failures, failure_codes=failures, first_failure_native_step=first_failure[cell],
            metrics=m, velocity_error_m_s=error if not failures else None,
            capture_scope="reduced_discovery_only", qualification_requires_fresh_full_capture=True))
    return episodes


def select(trials, c):
    expected = plans(c, "population")
    require(len(trials) == len(expected) and all(t["plan"] == p and len(t["episodes"]) == p["nworld"]
            for t, p in zip(trials, expected, strict=True)), "Selection complete frozen population")
    all_episodes = [e for t in trials for e in t["episodes"]]
    conditions = []
    for condition in c["challenge"]["conditions"]:
        summaries = []
        for i, candidate in enumerate(c["provider"]["candidates"]):
            episodes = [e for e in all_episodes if e["candidate_index"] == i and e["condition_id"] == condition]
            require(len(episodes) == 2 and {e["start_id"] for e in episodes} == {s["id"] for s in c["challenge"]["starts"]}
                and all(e["candidate_id"] == candidate["id"] and type(e["eligible"]) is bool
                    and (not e["eligible"] or (type(e["velocity_error_m_s"]) in (int, float)
                        and math.isfinite(e["velocity_error_m_s"]) and e["velocity_error_m_s"] >= 0)) for e in episodes),
                "Selection candidate/start identity")
            eligible = all(e["eligible"] for e in episodes)
            summaries.append(dict(candidate_index=i, candidate_id=candidate["id"], eligible=eligible,
                failure_codes=[e["failure_codes"] for e in episodes],
                mean_velocity_error_m_s=sum(e["velocity_error_m_s"] for e in episodes)/2 if eligible else None))
        baseline = summaries[0]
        ranking = sorted((r for r in summaries[1:] if r["eligible"] and
            (not baseline["eligible"] or r["mean_velocity_error_m_s"] < baseline["mean_velocity_error_m_s"])),
            key=lambda r: (r["mean_velocity_error_m_s"], r["candidate_index"]))
        shortlist = []
        for row in ranking:
            genome = c["provider"]["candidates"][row["candidate_index"]]["ordered_coefficients"]
            if all(sum(abs(x-y) for x, y in zip(genome, c["provider"]["candidates"][i]["ordered_coefficients"], strict=True))/8 >=
                   c["selection"]["minimum_mean_absolute_coefficient_distance"] for i in shortlist):
                shortlist.append(row["candidate_index"])
            if len(shortlist) == c["selection"]["shortlist_per_condition"]:
                break
        conditions.append(dict(condition_id=condition, candidates=summaries,
            ranked_candidate_indices=[r["candidate_index"] for r in ranking], shortlist_candidate_indices=shortlist))
    return dict(conditions=conditions, selection_scope="exposed_two_second_development_only",
        calibration_worlds=0, evaluation_worlds=0, trained_provider=False,
        next_gate="fresh_full_capture_shortlist_reruns_under_a_new_prospective_contract",
        **{key: False for key in FLAGS})
