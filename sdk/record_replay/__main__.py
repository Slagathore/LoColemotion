"""Command-line verifier and deterministic replayer."""

from __future__ import annotations

import argparse
import json

from python import LocomotionCore

from .canonical_recording import replay_recording, verify_recording


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Verify or deterministically replay a canonical SporeSpore SDK "
            "recording. This does not replay or certify physics."
        )
    )
    parser.add_argument("operation", choices=("verify", "replay"))
    parser.add_argument("recording")
    parser.add_argument("--library", default=None)
    arguments = parser.parse_args()
    core = LocomotionCore(arguments.library)
    if arguments.operation == "verify":
        receipt = verify_recording(arguments.recording, core)
    else:
        receipt = replay_recording(arguments.recording, core)
    receipt.pop("_frames", None)
    print(json.dumps(receipt, allow_nan=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
