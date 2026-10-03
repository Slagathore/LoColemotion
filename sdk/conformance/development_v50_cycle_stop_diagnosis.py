"""Audit the consumed V50 cycle/stop and every contact loss; no native world."""
import hashlib, json
from pathlib import Path
from development_v47_support_progress_diagnosis import endpoint, dot, minus, LIMBS
ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = "bd3a5a83e888432d8b3b50c9a1f46af4"
DIGESTS = {
    "trajectory.jsonl": "9142886a52f0d01c71df776a2e625cb55b4501e13ecab513688812623b828bb4",
    "input.json": "856653941b21b87dbf25616e823f1b078d728983b6aa5b0f31ae1c9befa9077a",
    "reader.json": "85a06f5c63ebbc6795be15d582fcde0f8ad6a65920cb0a8d05a63f59a85adb2b",
}
def require(value, code):
    if not value: raise ValueError("V50_CYCLE_STOP_" + code)
def read_source():
    root = ROOT.parent / "SporeSpore_Evidence" / ("development-v50-mujoco-closed-loop-" + ATTEMPT)
    data = {name: (root / name).read_bytes() for name in DIGESTS}
    for name, raw in data.items():
        require(hashlib.sha256(raw).hexdigest() == DIGESTS[name], "SOURCE_DIGEST")
    return [json.loads(line) for line in data["trajectory.jsonl"].splitlines()], json.loads(data["input.json"]), json.loads(data["reader.json"])
def analyze(rows, value, reader):
    require(len(rows) == 1129 and reader["cycle_end_command"] == 1009 and reader["stopping_commands"] == 120, "POPULATION")
    forward = value["task_frame"]["forward_axis_world_unit"]
    lower = .35 * (1 - value["descriptor"]["upper_length_fraction"])
    cycles, events, measurements = [], [], []
    for command, row in enumerate(rows, 1):
        require(command == row["command"] == row["request"]["state"]["semantic_step"], "CLOCK")
        require(row["stopping"] == (command > 1009), "STOP_BOUNDARY")
        require(all(type(v) is bool for v in row["physics"]["last_substep_bearing"].values()), "CONTACT_KNOWN")
        measurements.append(row["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]["measurement"])
    require(set(reader["cycle_progress"]["completed"]) == set(LIMBS), "CYCLE_POPULATION")
    for limb in LIMBS:
        end = reader["cycle_progress"]["completed"][limb]
        start = reader["cycle_progress"]["absent"][limb]
        release = reader["cycle_progress"]["released"][limb]
        require(release <= start < end <= 1009 and not rows[start - 1]["physics"]["last_substep_bearing"][limb] and rows[end - 1]["physics"]["last_substep_bearing"][limb], "CYCLE_CONTACT")
        cycles.append(dict(limb=limb, release=release, first_absent=start, first_supported_stance=end, endpoint_forward_m=dot(minus(endpoint(rows[end - 1], limb, lower), endpoint(rows[start - 1], limb, lower)), forward)))
        start = None
        for index, row in enumerate(rows):
            if not row["physics"]["last_substep_bearing"][limb] and start is None:
                start = index
            elif row["physics"]["last_substep_bearing"][limb] and start is not None:
                transfer = rows[start]["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]
                # This label describes controller intent at onset, not a new success threshold.
                events.append(dict(limb=limb, first_absent=start + 1, first_bearing=index + 1, absent_samples=index - start,
                    planned_swing_limb_at_onset=transfer["planned_swing_limb_id"] == limb,
                    endpoint_forward_m=dot(minus(endpoint(row, limb, lower), endpoint(rows[start], limb, lower)), forward),
                    maximum_nominal_gap_m=max(r["physics"]["post"]["nominal_capsule_bottom_m"][limb] for r in rows[start:index])))
                start = None
        require(start is None, "OPEN_CONTACT_LOSS")
    required = [e for e in events if not e["planned_swing_limb_at_onset"]]
    supported = all(all(r["physics"]["last_substep_bearing"].values()) for r in rows[-30:])
    require(supported and reader["final_30_commands_settled"] and not reader["controller_refused"], "STOP_READER")
    return dict(schema_version="sporespore_v50_retained_cycle_stop_diagnosis_v1",
        ledger_scope=dict(subsystem="recovery", engine_scope="mujoco", authority_mode="post_exposure_retained_data_diagnosis", question_class="development"),
        source_digests=DIGESTS, command_count=len(rows), cycles=cycles,
        first_72_required_support_onsets=[e for e in required if e["first_absent"]<=72],
        first_72_speed_clipped_motor_commands=sum(c["velocity_saturated"] for r in rows[:72] for c in r["output"]["actuation"]["ordered_commands"]),
        first_72_minimum_precommand_forward_com_speed_m_s=min(m["forward_com_speed_m_s"] for m in measurements[:72]),
        first_72_maximum_precommand_horizontal_com_speed_m_s=max(m["horizontal_com_speed_m_s"] for m in measurements[:72]),
        all_contact_loss_episodes=events, contact_loss_episode_count=len(events), required_support_onset_episode_count=len(required),
        required_support_maximum_absent_samples=max(e["absent_samples"] for e in required),
        required_support_minimum_endpoint_forward_m=min(e["endpoint_forward_m"] for e in required),
        required_support_maximum_nominal_gap_m=max(e["maximum_nominal_gap_m"] for e in required),
        maximum_precommand_tilt_rad=max(m["torso_tilt_rad"] for m in measurements),
        final_30_precommand_maxima={k:max(m[k] for m in measurements[-30:]) for k in ("torso_tilt_rad", "horizontal_com_speed_m_s", "torso_angular_speed_rad_s")},
        final_30_postcommand_all_four_support=supported, original_reader_settled=True,
        geometry_is_contact_authority=False, original_observation_regraded=False, new_world_count=0, new_solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
