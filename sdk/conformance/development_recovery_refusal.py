"""Reopen a retained native startup refusal without retrying a physical world.

The two C ABI calls below reproduce exposed controller inputs. This is a
diagnosis of an invalid development route, never a replacement route result.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sdk/python"))
from sporespore_locomotion import LocomotionCore


def require(value, code):
    if not value:
        raise ValueError("RECOVERY_REFUSAL_" + code)


def digest(raw):
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def integers(value):
    """Normalize integral JSON numbers in a new C ABI request, never the source."""
    if isinstance(value, dict):
        return {k: integers(v) for k, v in value.items()}
    if isinstance(value, list):
        return [integers(v) for v in value]
    return int(value) if type(value) is float and value.is_integer() else value


class RecordedCore(LocomotionCore):
    def _decode(self, status, output):
        self.raw_response = bytes(output)
        return LocomotionCore._decode(status, output)


def startup_reach_bounds(request, compiled):
    """Prove reach impossibility over every permitted next-command body shift.

    This is restricted to the exposed second startup command, before any foot
    has been released. It does not simulate a controller or a future stance.
    """
    memory = request["memory"]
    pose = memory["anchored_body_pose"]
    require(request["state"]["semantic_step"] == 2 and memory["last_semantic_step"] == 1,
            "STARTUP_ONLY")
    transfer = memory["measured_support_transfer"]
    require(transfer["hip_bias_rad"] == 0 and transfer["prepared_limb_id"] is None
            and transfer["ready_dwell_commands"] == 0, "UNRELEASED_START")
    require(all(f["swing_epoch"] is None for f in pose["ordered_feet"]), "NO_SWING")
    geometry = compiled["geometry"]
    length = geometry["upper_length_m"] + geometry["lower_length_m"]
    dt = request["state"]["sample_time_s"] - pose["last_sample_time_s"]
    require(abs(dt - 1/120) < 1e-9, "CLOCK")
    u = (request["state"]["sample_time_s"] - pose["start_time_s"]) / (72/120)
    require(0 < u < 1, "STARTUP_BLEND")
    origin, forward = pose["origin_world_m"], pose["forward_world_unit"]
    floor = request["floor_reference"]["height_world_m"]
    height = origin["y"] + u*u*(3-2*u) * (floor + geometry["foot_radius_m"] + .33 - origin["y"])
    maximum_shift = length * .6 * dt
    result = []
    for index, foot in enumerate(pose["ordered_feet"]):
        anchor = foot["anchor_world_m"]
        require(anchor["y"] == floor + geometry["foot_radius_m"], "FLOOR_ANCHOR")
        x = sum((anchor[k]-origin[k])*forward[k] for k in "xyz")
        x -= geometry["front_hip_x_m" if index < 2 else "rear_hip_x_m"]
        down = height-anchor["y"]
        smallest_x = max(0, abs(x)-maximum_shift)
        shortest = math.hypot(smallest_x, down)
        result.append(dict(limb_id=foot["limb_id"], sagittal_offset_m=x, downward_distance_m=down,
            maximum_next_body_shift_m=maximum_shift, available_leg_length_m=length,
            minimum_required_reach_m=shortest, minimum_reach_excess_m=shortest-length,
            impossible_for_every_permitted_body_shift=shortest > length,
            maximum_geometric_body_height_m=anchor["y"]+math.sqrt(max(0, length*length-smallest_x*smallest_x))))
    return result


def reproduce(report, descriptor, core):
    failure = report["detail"]["portable_step_receipt"]["development_native_step_failure"]
    require(failure["classification"] == "verified_zero_actuation_controller_refusal"
            and failure["verified_zero_actuation_refusal"] is True, "CLASSIFICATION")
    require(failure["adapter_clock_advanced"] is False and failure["adapter_memory_advanced"] is False
            and failure["motor_application_permitted"] is False, "REFUSAL_SIDE_EFFECT")
    for key in ("request", "response"):
        raw = failure[key]["utf8_text"].encode("utf-8")
        require(len(raw) == failure[key]["utf8_byte_length"] and digest(raw) == failure[key]["raw_sha256"], "RAW_"+key)
    request = json.loads(failure["request"]["utf8_text"])
    policy = failure["expected_policy_id"]
    compiled = core.compile_bounded_quadruped(descriptor)
    require(core.canonicalize_json(compiled["morphology"]["morphology_spec"])["sha256"]
            == failure["compiled_morphology_spec_sha256"], "COMPILED_DESCRIPTOR")
    calls = []
    rows = report["development_walking_entry"]["rows"]
    require(len(rows) == 1 and rows[0]["session_local_step"] == 1, "FIRST_COMMAND_POPULATION")
    for q, expected in [(rows[0]["request"], rows[0]["raw_native_response_sha256"]),
                        (request, failure["response"]["raw_sha256"])]:
        copied = integers(dict(copy.deepcopy(q), descriptor=descriptor))
        output = core.balanced_wave_policy_step_with_measured_body(policy, copied)
        require(digest(core.raw_response) == expected, "NATIVE_RESPONSE_CHANGED")
        calls.append(dict(semantic_step=q["state"]["semantic_step"], raw_response_sha256=expected,
                          safe_no_actuation=output["actuation"]["safe_no_actuation"]))
    require(calls[0]["safe_no_actuation"] is False and calls[1]["safe_no_actuation"] is True, "NORMAL_THEN_REFUSAL")
    commands = output["actuation"]["ordered_commands"]
    require(len(commands) == 8 and all(c["target_velocity_rad_s"] == 0 for c in commands), "ZERO_COMMANDS")
    require(output["next_memory"] == integers(request["memory"]), "MEMORY_CHANGED")
    return dict(native_calls=calls, startup_reach_bounds=startup_reach_bounds(request, compiled),
        reported_controller_error=failure["reported_native_controller_error"], zero_motor_commands=len(commands),
        original_observation_regraded=False, new_world_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def reopen(root):
    root = Path(root).resolve()
    require(root.parent == ROOT.parent / "SporeSpore_Evidence", "EVIDENCE_ROOT")
    declaration = json.loads((root / "declaration.json").read_bytes())
    result = json.loads((root / "supervisor_result.json").read_bytes())
    require(result["ok"] is False and result["physical_attempt_started"] is True
            and result["source_snapshot"] == declaration["source_snapshot"], "SUPERVISOR")
    require(len(result["children"]) == 1 and result["children"][0]["exit_code"] == 1, "CONSUMED_POPULATION")
    child = root / "children" / result["children"][0]["role"]
    envelope = json.loads((child / "child_envelope.json").read_bytes())
    for item in envelope["retained_artifact_bindings"].values():
        path = Path(item["path"])
        require(path.parent == child and path.stat().st_size == item["byte_length"]
                and digest(path.read_bytes()) == item["raw_sha256"], "RETAINED_BYTES")
    report = json.loads((child / "worker_report.json").read_bytes())
    lines = [line.split(" ", 1)[1] for line in (child / "worker.stdout.txt").read_text(encoding="utf-8").splitlines()
             if line.startswith("SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ")]
    require(len(lines) == 1 and json.loads(lines[0]) == report == envelope["report"], "RAW_REPORT")
    source = declaration["source_snapshot"]["head"]
    def frozen(resource):
        path = resource.removeprefix("res://")
        return subprocess.check_output(["git", "show", source+":"+path], cwd=ROOT)
    profile_raw = frozen(declaration["candidate_profile"]["resource"])
    require(digest(profile_raw) == declaration["candidate_profile"]["raw_sha256"], "PROFILE")
    profile = json.loads(profile_raw)
    binding_raw = frozen(profile["runtime_binding"])
    require(digest(binding_raw) == profile["runtime_binding_sha256"], "RUNTIME_BINDING")
    binding = json.loads(binding_raw)
    dll = Path(binding["runtime"]["path"])
    require(digest(dll.read_bytes()) == profile["runtime_sha256"] == binding["runtime"]["raw_sha256"], "DLL")
    return declaration, result, report, RecordedCore(dll)
