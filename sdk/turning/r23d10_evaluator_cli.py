"""Zero-world evaluator CLI seam for QSDK-R23D10.

This is intentionally not the production physical evaluator.  It executes the
two exact producer commands and marker prefixes frozen at stage zero, ensuring
that a future supervisor consumes the same wire protocol the evaluator emits.
"""

from __future__ import annotations

import argparse
import json
from typing import Sequence


STAGE_A_MARKER = "QSDK_R23D10_STAGE_A_EVALUATION "
COMPLETE_MARKER = "QSDK_R23D10_COMPLETE_EVALUATION "
GENERIC_MARKER = "QSDK_R23D10_EVALUATION "


def _receipt(command: str) -> dict[str, object]:
    return {
        "schema_version": "sporespore_qsdk_r23d10_evaluator_cli_canary_v1",
        "command": command,
        "zero_world_canary": True,
        "production_evaluator_implemented": False,
        "physical_execution_authorized": False,
        "process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("evaluate-stage-a", "evaluate-complete"):
        command = commands.add_parser(name)
        command.add_argument("--zero-world-canary", action="store_true")
    args = parser.parse_args(argv)
    if not args.zero_world_canary:
        parser.error("only --zero-world-canary is implemented at stage one")
    marker = STAGE_A_MARKER if args.command == "evaluate-stage-a" else COMPLETE_MARKER
    print(marker + json.dumps(_receipt(args.command), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
