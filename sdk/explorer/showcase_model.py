"""Pure Explorer construction and command boundary. No physics is created here."""
from __future__ import annotations

import ctypes
import hashlib
import json
import math
from pathlib import Path

PROTOCOL = "sporespore_live_explorer_protocol_v1"
SCOPE = dict(subsystem="explorer", engine_scope="3e", authority_mode="development", question_class="development")
FIELDS = {
    "torso_length_scale": (.90, 1.10), "torso_width_scale": (.90, 1.10),
    "upper_length_fraction": (.48, .55), "hip_span_scale": (.90, 1.10),
    "foot_radius_scale": (.90, 1.10), "front_limb_mass_scale": (.90, 1.10),
}
S169 = dict(schema_version="sporespore_bounded_quadruped_descriptor_v1",
    morphology_id="qsdk_r05_generated_s169", torso_length_scale=1.0041015625,
    torso_width_scale=1.0031893004115227, upper_length_fraction=.5219571428571428,
    hip_span_scale=.9856413994169096, foot_radius_scale=.9987180691209617,
    front_limb_mass_scale=.975022758306782)
ENGINES = ("rapier_parry", "mujoco", "godot_jolt")


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def generated(seed: int) -> dict:
    if type(seed) is not int or not 0 <= seed <= 2147483647:
        raise ValueError("Seed must be an integer from 0 to 2147483647")
    if seed == 169:
        return dict(S169)
    result = dict(S169, morphology_id=f"explorer_seed_{seed}")
    for field, (lo, hi) in FIELDS.items():
        # Stable across Python versions and machines; no global random state.
        unit = int.from_bytes(hashlib.sha256(f"explorer-v1:{seed}:{field}".encode()).digest()[:4], "big") / 4294967295
        result[field] = lo + (hi-lo)*unit
    return result


def validate_descriptor(value: dict) -> dict:
    if type(value) is not dict or set(value) != set(S169):
        raise ValueError("Descriptor fields do not match the bounded quadruped schema")
    if value["schema_version"] != S169["schema_version"]:
        raise ValueError("Unknown descriptor schema")
    if not isinstance(value["morphology_id"], str) or not 1 <= len(value["morphology_id"]) <= 96:
        raise ValueError("Morphology identifier must contain 1–96 characters")
    for key, (lo, hi) in FIELDS.items():
        n = value[key]
        if type(n) not in (int, float) or not math.isfinite(n) or not lo <= n <= hi:
            raise ValueError(f"{key} must be finite and between {lo} and {hi}")
    return value


def runnable(descriptor: dict, engine: str, phase: int) -> None:
    validate_descriptor(descriptor)
    if engine not in ENGINES:
        raise ValueError("Unknown native engine")
    if descriptor != S169:
        raise ValueError("This native worker supports exact S169 only. Your edited creature is a construction preview; restore S169 to run physics.")
    if type(phase) is not int or not 0 <= phase <= 359:
        raise ValueError("Prefix phase must be an integer from 0 to 359")
    if engine != "godot_jolt" and phase != 0:
        raise ValueError("Rapier and MuJoCo use their fixed commissioned startup. Phase editing belongs to the Godot recovery route.")


def impulse(session: str, frame: int, magnitude: float, direction: str, command_id: str) -> dict:
    if type(frame) is not int or frame < 1:
        raise ValueError("A kick requires a live native frame")
    if type(magnitude) not in (int, float) or not math.isfinite(magnitude) or not .01 <= magnitude <= 8:
        raise ValueError("Impulse magnitude must be between 0.01 and 8 N·s")
    vectors = {"right": (0, 0, 1), "left": (0, 0, -1), "forward": (1, 0, 0), "back": (-1, 0, 0)}
    if direction not in vectors:
        raise ValueError("Unknown impulse direction")
    return dict(schema_version=PROTOCOL, message_type="apply_impulse", session_id=session,
        command_id=command_id, target_body_id="torso", apply_at_frame=frame + 60,
        impulse_n_s=dict(zip(("x", "y", "z"), (v*magnitude for v in vectors[direction]))))


class Compiler:
    """Use the actual bounded compiler through its public C ABI, with no world."""
    def __init__(self, path: Path):
        self.path = path.resolve()
        self.library = ctypes.CDLL(str(self.path))
        self.call = self.library.ss_compile_bounded_quadruped_json
        self.call.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
        self.call.restype = ctypes.c_int

    def compile(self, value: dict) -> dict:
        validate_descriptor(value)
        raw = json.dumps(value, allow_nan=False).encode()
        size = ctypes.c_size_t()
        if self.call(raw, len(raw), None, 0, ctypes.byref(size)) != 2 or not 0 < size.value < 4000000:
            raise ValueError("Native compiler size query failed")
        buf = ctypes.create_string_buffer(size.value)
        status = self.call(raw, len(raw), buf, len(buf), ctypes.byref(size))
        reply = json.loads(buf.raw[:size.value])
        if status != 0 or not reply.get("ok"):
            raise ValueError(f"Native construction refused: {reply}")
        return reply["value"]


class StreamIdentity:
    """Validate the actual native message sequence before any UI publication."""
    def __init__(self, session, engine, source, validate):
        self.session, self.engine, self.source, self.validate = session, engine, source, validate
        self.hello = False
        self.last_frame = 0
        self.completed = False

    def accept(self, message):
        if self.completed or not isinstance(message,dict): raise ValueError("Message after completion or malformed object")
        if message.get("schema_version")!=PROTOCOL or message.get("session_id")!=self.session or message.get("engine_id")!=self.engine:
            raise ValueError("Crossed native protocol identity")
        kind=message.get("message_type")
        if kind=="hello":
            if self.hello or message.get("native_physics") is not True or message.get("replay") is not False: raise ValueError("Invalid native hello")
            if not self.validate and message.get("source_commit")!=self.source: raise ValueError("Source identity mismatch")
            self.hello=True
        elif not self.hello: raise ValueError("Native message before hello")
        elif kind=="frame":
            n=message.get("frame_index")
            limit=2401 if self.engine=="godot_jolt" else 12000
            if self.validate or type(n) is not int or not self.last_frame<n<=limit or message.get("native_physics") is not True or message.get("replay") is not False:
                raise ValueError("Invalid native frame progression")
            if not isinstance(message.get("ordered_bodies"),list) or not message["ordered_bodies"]: raise ValueError("Missing native body observations")
            self.last_frame=n
        elif kind=="ready_to_start" and self.validate: raise ValueError("Preflight attempted physical start")
        elif kind=="completed":
            if type(message.get("ok")) is not bool: raise ValueError("Completion outcome missing")
            if self.validate and (message.get("summary",{}).get("world_build_count")!=0 or self.last_frame): raise ValueError("Preflight created a world")
            if not self.validate and message.get("ok") and not self.last_frame: raise ValueError("Physical completion without native frames")
            self.completed=True
        elif kind not in ("scene","ready_to_start","started","command_scheduled","error"):
            raise ValueError("Unknown native message")
        return kind
