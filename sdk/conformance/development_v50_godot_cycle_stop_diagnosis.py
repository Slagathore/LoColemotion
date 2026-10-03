"""Describe V50's consumed Godot cycles and support losses without new physics.

The original evaluator uses distal body origins. This diagnosis additionally
uses measured capsule endpoints, with the following command's synchronized
precommand sample supplying the preceding command's postcommand geometry.
Neither geometry nor controller intent changes native contact classification.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = "0049bae93b254abd98b2c726eb444544"
LIMBS = ("front_left", "front_right", "rear_left", "rear_right")
DIGESTS = {
    "worker_report.json": "f9e1eab7b9067dedb4d9d325465d9ec1222a75ad7546fa4245bbd77177c9d629",
    "passive_entry_replay/stdout.txt": "7435cf83cebcbeec83ec4d1db139de147a792e37e60448fea24c05d2e833b814",
}


def require(value, code):
    if not value:
        raise ValueError("V50_GODOT_DIAGNOSIS_" + code)


def read_source():
    root = ROOT.parent / "SporeSpore_Evidence" / ("development-recovery-smoke-" + ATTEMPT)
    child = root / "children/kick_passive_recovery_resume"
    data = {name: (child / name).read_bytes() for name in DIGESTS}
    for name, raw in data.items():
        require(hashlib.sha256(raw).hexdigest() == DIGESTS[name], "SOURCE_DIGEST")
    prefix = "DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY "
    receipts = [json.loads(line[len(prefix):]) for line in data["passive_entry_replay/stdout.txt"].decode().splitlines() if line.startswith(prefix)]
    require(len(receipts) == 1, "READER_POPULATION")
    return json.loads(data["worker_report.json"]), receipts[0]


def analyze(report, reader):
    controls = report["development_walking_entry"]["rows"]
    retained = report["development_cycle_stop"]
    posts, memory = retained["rows"], retained["final_memory"]
    replay = reader["walking_control_replay"]
    require(report["ok"] is True and report["solver_step_count"] == 2015, "REPORT")
    require(reader["ok"] is True and reader["input_raw_sha256"] == "sha256:" + DIGESTS["worker_report.json"], "READER")
    require(len(controls) == len(posts) == replay["replayed_walking_steps"] == 1157, "POPULATION")
    require(memory == replay["cycle_stop_final_memory"] and memory["cycle_end_command"] == 1037
            and memory["stopping_commands"] == 120 and memory["consecutive_settled_commands"] == 120, "CYCLE_MEMORY")
    require(set(memory["completed"]) == set(LIMBS) and replay["final_30_stop_commands_settled"] is True, "CYCLE_AND_STOP")
    require(report["stop_reason"] == "diagnostic_cycle_aligned_stop_complete" and report["coverage_complete"] is False, "ORIGINAL_CUTOFF")
    transfer = [r["native_output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"] for r in controls]
    pose = [r["native_output"]["actuation"]["receipt"]["recovery_support_plane"]["anchored_body_pose"] for r in controls]
    forward = transfer[0]["measurement"]["anatomical_forward_horizontal_world_unit"]
    # The frozen controller initializes its world anchors at nominal floor + radius.
    floor = controls[0]["request"]["floor_reference"]["height_world_m"]
    radius = pose[0]["next_memory"]["ordered_feet"][0]["anchor_world_m"]["y"] - floor
    for command, (row, post) in enumerate(zip(controls, posts), 1):
        require(row["session_local_step"] == post["session_local_step"] == row["request"]["state"]["semantic_step"] == command, "CLOCK")
        require(row["commanded_global_step"] == 858 + command and row["measured_global_step"] == 857 + command, "GLOBAL_CLOCK")
        require(row["full_step_receipt_sha256"] == post["full_step_receipt_sha256"], "STEP_BINDING")
        require(row["development_cycle_stopping"] is (command > 1037), "STOP_BOUNDARY")
        receipt, source = post["advance_receipt"], post["post_native_source"]
        require(source["observation"]["semantic_step"] == source["precommand_trace"]["global_semantic_step"] == 858 + command, "POST_CLOCK")
        contacts = source["observation"]["state"]["ordered_contact_observations"]
        for limb, contact in zip(LIMBS, contacts):
            require(contact["contact_site_id"] == limb + "_foot" and type(contact["presence"]) is bool and type(contact["bears_support"]) is bool, "KNOWN_CONTACT")
            require(receipt["postcommand_bearing"][limb] is (contact["presence"] and contact["bears_support"]), "CONTACT_LINK")
        require(receipt["next_memory"]["last_command"] == command, "RECEIPT_CLOCK")
    require(posts[-1]["advance_receipt"]["next_memory"] == memory, "FINAL_MEMORY")

    def endpoint(command, index):
        require(1 <= command < len(controls), "POST_GEOMETRY_CLOCK")
        return transfer[command]["measurement"]["ordered_measured_capsule_endpoints_world_m"][index]

    def advance(start, finish, index):
        a, b = endpoint(start, index), endpoint(finish, index)
        return sum((b[k] - a[k]) * forward[k] for k in "xyz")

    cycles, events = [], []
    for index, limb in enumerate(LIMBS):
        release, start, finish = (memory[k][limb] for k in ("released", "absent", "completed"))
        require(release <= start < finish <= 1037 and not posts[start - 1]["advance_receipt"]["postcommand_bearing"][limb]
                and posts[finish - 1]["advance_receipt"]["postcommand_bearing"][limb], "PLANNED_CYCLE_CONTACT")
        cycles.append(dict(limb=limb, release=release, first_absent=start, first_supported_stance=finish,
                           endpoint_forward_m=advance(start, finish, index)))
        start = None
        for command, post in enumerate(posts, 1):
            bearing = post["advance_receipt"]["postcommand_bearing"][limb]
            if not bearing and start is None:
                start = command
            elif bearing and start is not None:
                planned = transfer[start - 1]["planned_swing_limb_id"] == limb
                events.append(dict(limb=limb, first_absent=start, first_bearing=command,
                    absent_samples=command-start, planned_swing_limb_at_onset=planned,
                    endpoint_forward_m=advance(start, command, index),
                    maximum_nominal_gap_m=max(endpoint(n, index)["y"]-floor-radius for n in range(start, command)),
                    velocity_clipped_motor_samples=sum(m["velocity_saturated"] for r in controls[start-1:command]
                        for m in r["ordered_motor_applications"] if m["limb_id"] == limb)))
                start = None
        require(start is None, "OPEN_CONTACT_LOSS")
    required = [e for e in events if not e["planned_swing_limb_at_onset"]]
    measurements = [t["measurement"] for t in transfer]
    original = next(w["evaluation"] for w in report["retained_arm"]["walking_sessions"] if w["evaluation_segment_id"] == "walking_resume")
    require(original["false_walking_receipts"] == ["every_limb_forward_relocation"]
            and original["walking_gate_receipts"]["terminal_four_contact_recovery"] is True, "ORIGINAL_EVALUATOR")
    settled = all(p["advance_receipt"]["postcommand_settled"] is True for p in posts[-30:])
    require(settled and all(all(p["advance_receipt"]["postcommand_bearing"].values()) for p in posts[-30:]), "SETTLED_STOP")
    return dict(schema_version="sporespore_v50_godot_retained_cycle_stop_diagnosis_v1",
        ledger_scope=dict(subsystem="recovery", engine_scope="godot_jolt", authority_mode="post_exposure_retained_data_diagnosis", question_class="development"),
        source_digests=DIGESTS, command_count=len(controls), cycle_end_command=1037, stopping_commands=120,
        cycles=cycles, all_contact_loss_episodes=events, contact_loss_episode_count=len(events),
        required_support_onset_episode_count=len(required), required_support_maximum_absent_samples=max(e["absent_samples"] for e in required),
        required_support_minimum_endpoint_forward_m=min(e["endpoint_forward_m"] for e in required),
        required_support_maximum_nominal_gap_m=max(e["maximum_nominal_gap_m"] for e in required),
        first_72_required_support_loss_onsets=[e for e in required if e["first_absent"] <= 72],
        first_72_speed_clipped_motor_commands=sum(c["velocity_saturated"] for r in controls[:72] for c in r["ordered_motor_applications"]),
        first_72_minimum_precommand_forward_com_speed_m_s=min(m["forward_com_speed_m_s"] for m in measurements[:72]),
        first_72_maximum_precommand_horizontal_com_speed_m_s=max(m["horizontal_com_speed_m_s"] for m in measurements[:72]),
        final_30_postcommand_maxima={key:max(p["advance_receipt"][key] for p in posts[-30:]) for key in
            ("postcommand_horizontal_com_speed_m_s", "postcommand_torso_angular_speed_rad_s", "postcommand_torso_tilt_rad")},
        final_30_postcommand_all_four_support=True, final_30_commands_settled=True,
        original_walking_evaluation=original, historical_fixed_tail_coverage_complete=False,
        prospective_development_cycle_stop_complete=True, geometry_is_contact_authority=False,
        original_observation_regraded=False, new_world_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
