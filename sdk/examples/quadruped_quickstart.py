"""Standalone compile, step, record, verify, and replay example."""

# ruff: noqa: E402

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

SDK_ROOT = Path(__file__).resolve().parents[1]
if str(SDK_ROOT) not in sys.path:
    sys.path.insert(0, str(SDK_ROOT))

from examples.reference_quadruped import run_reference_frames
from python import (
    ABI_GENERATION,
    SDK_VERSION,
    LocomotionCore,
    SELECTED_BALANCED_WAVE_CANDIDATE_ID,
    SELECTED_BALANCED_WAVE_POLICY_ID,
)
from record_replay import replay_recording, verify_recording, write_recording


def run_quickstart(
    *,
    library: str | None = None,
    recording_path: str | Path | None = None,
) -> dict[str, Any]:
    """Run the public SDK example and return a machine-readable receipt."""

    core = LocomotionCore(library)
    descriptor, frames = run_reference_frames(core)
    temporary: tempfile.TemporaryDirectory[str] | None = None
    if recording_path is None:
        temporary = tempfile.TemporaryDirectory(prefix="sporespore-sdk-quickstart-")
        target = Path(temporary.name) / "reference-recording.jsonl"
    else:
        target = Path(recording_path).resolve()
    try:
        write_receipt = write_recording(
            target,
            core,
            recording_id="standalone_quadruped_quickstart_v1",
            descriptor=descriptor,
            frames=frames,
        )
        verification = verify_recording(target, core)
        verification.pop("_frames", None)
        replay = replay_recording(target, core)
        command_count = sum(
            len(frame["response"]["actuation"]["ordered_commands"]) for frame in frames
        )
        all_outputs_pure = all(
            frame["response"]["actuation"]["world_build_count"] == 0
            and frame["response"]["actuation"]["physical_acceptance_authority"] is False
            for frame in frames
        )
        return {
            "schema_version": ("sporespore_quadruped_quickstart_receipt_v1"),
            "sdk_version": SDK_VERSION,
            "abi_generation": ABI_GENERATION,
            "candidate_id": SELECTED_BALANCED_WAVE_CANDIDATE_ID,
            "policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
            "morphology_id": descriptor["morphology_id"],
            "frame_count": len(frames),
            "ordered_actuator_command_count": command_count,
            "recording_sha256": write_receipt["recording_sha256"],
            "recording_retained": recording_path is not None,
            "recording_integrity_verified": verification["integrity_verified"],
            "deterministic_policy_replay_exact": replay["deterministic_replay_exact"],
            "all_outputs_pure": all_outputs_pure,
            "physics_trajectory_recorded_or_replayed": False,
            "walking_acceptance": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
    finally:
        if temporary is not None:
            temporary.cleanup()


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Run the standalone quadruped SDK quickstart without a physics "
            "engine. This demonstrates API determinism, not walking."
        )
    )
    parser.add_argument("--library", default=None)
    parser.add_argument(
        "--recording",
        default=None,
        help="optional new JSONL path; existing files are never overwritten",
    )
    arguments = parser.parse_args()
    receipt = run_quickstart(
        library=arguments.library,
        recording_path=arguments.recording,
    )
    print(json.dumps(receipt, allow_nan=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
