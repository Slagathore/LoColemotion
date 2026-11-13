"""Compact discovery capture with full live validation and explicit replay limits.

Keep solver inputs, prepared states, every native state/force/capacity sample,
and contact identities. Detailed body observations and contact geometry stay in
full canaries. Compact discovery always needs fresh full-capture confirmation.
"""
import copy
import hashlib
import json
from pathlib import Path
import math

from creature_batch import require
from gpu_quadruped_model import f32
from gpu_quadruped_probe import check_capture
from audit_gpu_batch_execution import same_bits
import creature_righting as righting

SCHEMA = "locolemotion_creature_compact_capture_v1"
POLICY = dict(schema_version=SCHEMA, native_reads_changed=False, file_buffering_changed=False,
              substeps_discarded=False, qualification_requires_fresh_full_capture=True)
SAMPLE_FIELDS = ("time_s", "qpos", "qvel", "actuator_force_nm", "joint_force_nm",
                 "batch_contacts", "nefc", "overflow", "warnings")
ROOT_FIELDS = {"schema_version", "cell", "outer_step", "binding", "prepared_time_s",
               "prepared_qpos", "prepared_qvel", "native_targets", "safe_no_actuation", "samples"}


def options(c):
    mode = c.get("capture_mode", "full")
    policy = c.get("compact_capture")
    require(mode in ("full", "compact_v1"), "Creature capture mode")
    if policy is None:
        require(mode == "full", "Compact capture requires declared policy")
    else:
        require(policy == POLICY and c.get("mode") in ("route_ghost", "development_discovery")
                and "confirmation_spec" not in c and not c.get("readback", {}).get("reference_check", False),
                "Compact discovery scope or policy")
    return dict(active=policy is not None, full=mode == "full")


def streams(c, shared):
    opt = options(c)
    return ((["controller", "trace", "timing"] if opt["full"] else ["timing"])
            + (["readback"] if shared else []) + (["compact"] if opt["active"] else []))


def project(controls, samples):
    """Serialize only after the unchanged full live validators accept the block."""
    n = len(controls)
    require(n > 0 and len(samples) == 5 and all(len(block) == n for block in samples),
            "Compact projection denominator")
    rows = []
    for cell, control in enumerate(controls):
        native = control["native_observation"]
        row = dict(schema_version=SCHEMA, cell=cell, outer_step=control["outer_step"],
            binding=control["binding"], prepared_time_s=native["time_s"],
            prepared_qpos=native["qpos"], prepared_qvel=native["qvel"],
            native_targets=[f32(v) for v in control["native_targets"]],
            safe_no_actuation=control["resolution"]["safe_no_actuation"], samples=[])
        for block in samples:
            sample = block[cell]
            row["samples"].append(dict({k:sample[k] for k in SAMPLE_FIELDS},
                contacts=[dict(native_index=h["native_index"], geom=h["geom"]) for h in sample["contacts"]]))
        rows.append(row)
    return copy.deepcopy(rows)


def verify_projection(rows, controls, samples):
    """Check raw fields independently of the compact producer in every full canary."""
    require(len(rows) == len(controls) and len(samples) == 5, "Full/compact population")
    for i, (row, control) in enumerate(zip(rows, controls, strict=True)):
        native = control["native_observation"]
        require(row["cell"] == control["cell"] == i and row["outer_step"] == control["outer_step"]
            and same_bits(row["binding"], control["binding"])
            and same_bits(row["native_targets"], [f32(v) for v in control["native_targets"]])
            and same_bits(row["prepared_time_s"], native["time_s"])
            and same_bits(row["prepared_qpos"], native["qpos"])
            and same_bits(row["prepared_qvel"], native["qvel"])
            and row["safe_no_actuation"] is control["resolution"]["safe_no_actuation"]
            and len(row["samples"]) == 5, "Full/compact prepared observation or solver input")
        for sub, actual in enumerate(row["samples"]):
            raw = samples[sub][i]
            require(raw["cell"] == i and raw["step"] == 5*row["outer_step"]+sub+1
                and same_bits(raw["ctrl"], row["native_targets"])
                and all(same_bits(actual[k], raw[k]) for k in SAMPLE_FIELDS),
                "Full/compact native sample")
            require(all(h["world"] == i for h in raw["contacts"])
                and same_bits(actual["contacts"], [dict(native_index=h["native_index"], geom=h["geom"])
                                                   for h in raw["contacts"]]), "Full/compact contact identity")


def vector(value, n):
    return type(value) is list and len(value) == n and all(type(v) in (int, float) and math.isfinite(v) for v in value)


class Reader:
    """Reconstruct outcomes from retained samples without claiming controller replay."""
    def __init__(self, c, creatures, positions, velocities):
        self.c, self.creatures = c, creatures
        self.n = len(creatures)
        self.positions, self.velocities = positions.tolist(), velocities.tolist()
        self.previous = [None]*self.n
        self.outer = 0
        self.sequence = any(p["mode"] == righting.sequence.MODE for p in c.get("righting_spec", {}).get("profiles", []))
        self.metrics = [dict(minimum_height_m=math.inf, maximum_tilt_rad=0., torso_contact_steps=0,
            safe_no_actuation_steps=0, ground_contact_steps=0, nonzero_force_steps=0,
            forward_displacement_m=0., lateral_displacement_m=0.) for _ in creatures]
        if "righting_spec" in c:
            for m in self.metrics:
                m.update(righting.initial_metrics())
                if self.sequence: m.update(righting.sequence.initial_work())

    def consume(self, rows):
        require(type(rows) is list and len(rows) == self.n and self.outer < self.c["outer_steps"],
                "Compact block denominator")
        for i, row in enumerate(rows):
            creature, previous = self.creatures[i], self.previous[i]
            expected = dict(creature["binding"], cell_id=self.c["cells"][i]["cell_id"],
                            candidate_id=self.c["cells"][i]["profile"]["id"])
            require(type(row) is dict and set(row) == ROOT_FIELDS and row["schema_version"] == SCHEMA
                and type(row["cell"]) is int and row["cell"] == i
                and type(row["outer_step"]) is int and row["outer_step"] == self.outer
                and row["binding"] == expected and type(row["safe_no_actuation"]) is bool,
                "Compact identity, fields or order")
            require(vector(row["prepared_qpos"],15) and vector(row["prepared_qvel"],14)
                and vector(row["native_targets"],8) and type(row["prepared_time_s"]) in (int,float)
                and math.isfinite(row["prepared_time_s"]), "Compact prepared vectors or clock")
            require(row["prepared_qpos"] == (previous["qpos"] if previous else self.positions[i])
                and row["prepared_qvel"] == (previous["qvel"] if previous else self.velocities[i])
                and row["prepared_time_s"] == (previous["time_s"] if previous else 0.),
                "Compact state or clock continuity")
            motors=creature["compiled"]["morphology"]["morphology_spec"]["actuators"]
            require(all(v == f32(v) and abs(v) <= f32(m["maximum_target_speed_rad_s"])
                        for v,m in zip(row["native_targets"],motors,strict=True)), "Compact bounded native input")
            require(type(row["samples"]) is list and len(row["samples"]) == 5, "Compact native denominator")
            self.metrics[i]["safe_no_actuation_steps"] += int(row["safe_no_actuation"])
        for sub in range(5):
            samples=[row["samples"][sub] for row in rows]
            require(all(type(s) is dict and set(s) == set(SAMPLE_FIELDS)|{"contacts"} for s in samples),
                    "Compact native fields")
            for i,s in enumerate(samples):
                require(vector(s["qpos"],15) and vector(s["qvel"],14)
                    and vector(s["actuator_force_nm"],8) and vector(s["joint_force_nm"],8)
                    and type(s["time_s"]) in (int,float) and math.isfinite(s["time_s"])
                    and type(s["contacts"]) is list and type(s["warnings"]) is list,
                    "Compact finite native sample")
                caps=[[f32(v) for v in pair] for pair in self.creatures[i]["spec"]["force_ranges"]]
                check_capture(dict(s,backend="gpu"),self.c,caps)
                step=self.outer*5+sub+1
                require(abs(sum(v*v for v in s["qpos"][3:7])-1.) <= 128*2**-23
                    and abs(s["time_s"]-step*self.c["timestep_s"]) <= 4*2**-23*step*step*self.c["timestep_s"],
                    "Compact quaternion or native clock")
                for h in s["contacts"]:
                    require(type(h) is dict and set(h)=={"native_index","geom"}
                        and type(h["native_index"]) is int and type(h["geom"]) is list and len(h["geom"])==2
                        and all(type(v) is int and 0<=v<10 for v in h["geom"])
                        and 0 in h["geom"] and h["geom"][0]!=h["geom"][1], "Compact contact identity")
            require(len({s["batch_contacts"] for s in samples}) == 1
                and sorted(h["native_index"] for s in samples for h in s["contacts"]) == list(range(samples[0]["batch_contacts"])),
                "Compact global contact population")
            for i,s in enumerate(samples):
                m=self.metrics[i];creature=self.creatures[i]
                m["minimum_height_m"]=min(m["minimum_height_m"],s["qpos"][2])
                m["maximum_tilt_rad"]=max(m["maximum_tilt_rad"],math.acos(max(-1.,min(1.,1-2*(s["qpos"][4]**2+s["qpos"][5]**2)))))
                m["torso_contact_steps"]+=int(any(1 in h["geom"] for h in s["contacts"]))
                m["ground_contact_steps"]+=int(bool(s["contacts"]))
                m["nonzero_force_steps"]+=int(any(v!=0. for v in s["actuator_force_nm"]))
                m["forward_displacement_m"]=s["qpos"][0]-creature["spec"]["initial_qpos"][0]
                m["lateral_displacement_m"]=s["qpos"][1]-creature["spec"]["initial_qpos"][1]
                if "righting_spec" in self.c:
                    righting.measure(m,s,creature)
                    if self.sequence:
                        before=self.previous[i]["qpos"] if self.previous[i] else self.positions[i]
                        righting.sequence.measure_work(m,dict(s,before_qpos=before))
                self.previous[i]=s
        self.outer+=1

    def finish(self):
        require(self.outer == self.c["outer_steps"], "Incomplete compact capture")
        return copy.deepcopy(self.metrics)


def report(rows, full):
    return dict(profile=SCHEMA, full_capture=full, compact_controller_rows_verified=rows,
        compact_native_samples_reconstructed=rows*5, within_run_projection_verified=full,
        controller_replay_verified=full, detailed_native_capture_verified=full,
        qualification_requires_fresh_full_capture=True, training_data_authority=False,
        physical_acceptance_authority=False, release_authority=False, equivalence_authority=False)


def canary_receipt(path, c, source_commit, bindings, evidence_root):
    """A compact native launch requires a completed matched full projection run."""
    path=Path(path).resolve(strict=True)
    require(path.is_relative_to(Path(evidence_root).resolve()) and path.name=="receipt.json",
            "Full canary evidence boundary")
    full=json.loads(path.read_bytes())
    audit_path=path.parent/"independent-audit.json"
    audit=json.loads(audit_path.read_bytes())
    def science(value):
        return {k:v for k,v in value.items() if k not in ("campaign_id","capture_mode","purpose","capture_comparison")}
    n=len(c["cells"])*c["outer_steps"]
    require(c["capture_mode"]=="compact_v1" and full["contract"]["capture_mode"]=="full"
        and options(full["contract"])["active"] and science(full["contract"])==science(c)
        and full["source_commit"]==source_commit and full["source_status"]==[]
        and full["synthetic"] is False and full["ok"] is True and full["source_runtime_unchanged"] is True
        and full["bindings"]["runtime"]==bindings["runtime"] and full["bindings"]["gpu"]==bindings["gpu"],
        "Full canary source, runtime, matched contract or completion")
    require(full["audit"]==audit and audit["ok"] is True and audit["synthetic"] is False
        and audit["reader_world_build_count"]==0 and audit["gpu_worlds"]==len(c["cells"])
        and audit["controller_rows_replayed"]==n and audit["native_rows_verified"]==5*n
        and audit["capture"]==report(n,True), "Full canary projection and replay required")
    digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    bound=next((v for v in full["artifacts"] if v["path"]=="independent-audit.json"),None)
    require(bound is not None and bound["sha256"]==digest(audit_path)
        and bound["bytes"]==audit_path.stat().st_size, "Full canary audit binding")
    return dict(receipt_path=str(path),receipt_sha256=digest(path),audit_sha256=digest(audit_path),
        full_controller_rows_replayed=n,full_native_rows_verified=5*n,within_run_projection_verified=True)
