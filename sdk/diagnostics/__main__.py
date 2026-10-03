"""Command-line descriptor diagnostic."""

from __future__ import annotations

import argparse
import json

from python import LocomotionCore, reference_quadruped

from .descriptor_diagnostics import diagnose_descriptor


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Diagnose a bounded quadruped descriptor without constructing a "
            "physics world."
        )
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--reference", action="store_true")
    source.add_argument("--descriptor")
    parser.add_argument("--library", default=None)
    arguments = parser.parse_args()
    if arguments.reference:
        descriptor = reference_quadruped("diagnostic_reference")
    else:
        with open(arguments.descriptor, encoding="utf-8") as handle:
            descriptor = json.load(handle)
    receipt = diagnose_descriptor(
        LocomotionCore(arguments.library),
        descriptor,
    )
    print(json.dumps(receipt, allow_nan=False, sort_keys=True))
    return 0 if receipt["accepted"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
