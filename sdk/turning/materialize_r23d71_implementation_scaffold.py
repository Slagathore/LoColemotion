#!/usr/bin/env python3
"""Materialize the prospective R23D71 zero-world implementation scaffold.

The compact success-terminal producer/projector proof commit is the exact
source parent. This tool carries forward the accepted R23D70 campaign
machinery to the fresh R23D71 identity, then applies only the declared
success-terminal contract/count changes. It writes source and gate files; it
does not load a physics library, construct a model, or open a world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "4693b4271d93c97dc98b5288231423866550861a"


class MaterializationError(RuntimeError):
    """The exact R23D71 implementation scaffold could not be composed."""


def _source(relative: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{relative}"],
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise MaterializationError(
            f"R23D71_SCAFFOLD_SOURCE_UNREADABLE:{relative}:"
            + process.stderr.decode(errors="replace")
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            "R23D71_SCAFFOLD_ANCHOR_COUNT_INVALID:"
            f"{observed}:{count}:{old[:120]!r}"
        )
    return text.replace(old, new)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(
            f"R23D71_SCAFFOLD_SECTION_START_INVALID:{start!r}"
        )
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(
            f"R23D71_SCAFFOLD_SECTION_END_INVALID:{end!r}"
        )
    return text[start_index:end_index]


def _replace_section(text: str, start: str, end: str, replacement: str) -> str:
    return text.replace(_section(text, start, end), replacement, 1)


def _identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-",
            "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-",
        ),
        (
            "r23d70_trace_retention_receipt_contract_repaired_",
            "r23d71_success_terminal_projection_repaired_",
        ),
        (
            "trace_retention_receipt_contract_repaired_three_engine_turning_validation",
            "success_terminal_projection_repaired_three_engine_turning_validation",
        ),
        ("R23D70", "R23D71"),
        ("r23d70", "r23d71"),
        ("23_189", "23_191"),
        ("23189", "23191"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _common(relative: str) -> str:
    return _identity(_source(relative))


def _implementation() -> str:
    text = _common("sdk/turning/materialize_r23d70_implementation.py")
    text = text.replace(
        "sdk/turning/r23d69_complete_production_row_conformance_repaired_"
        "three_engine_turning_preregistration_v1.json",
        "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_"
        "three_engine_turning_preregistration_v1.json",
    )
    text = text.replace(
        "sdk/turning/materialize_r23d71_production_route_sources.py",
        "sdk/turning/materialize_r23d71_success_terminal_sources.py",
    )
    text = text.replace(
        "tests/test_qsdk_r23d71_receipt_contract_ghost.ps1",
        "tests/test_qsdk_r23d71_success_terminal_projection_ghost.ps1",
    )
    text = text.replace(
        "tests/test_qsdk_r23d71_receipt_contract_ghost.py",
        "tests/test_qsdk_r23d71_success_terminal_projection_ghost.py",
    )
    text = text.replace(
        "tests/test_sdk_qsdk_r23d71_receipt_contract_ghost.gd",
        "tests/test_sdk_qsdk_r23d71_success_terminal_projection_ghost.gd",
    )
    text = _replace_exact(
        text,
        '    "sdk/turning/materialize_r23d71_implementation.py",\n',
        '    "sdk/turning/materialize_r23d71_implementation.py",\n'
        '    "sdk/turning/materialize_r23d71_implementation_scaffold.py",\n'
        '    "sdk/turning/materialize_r23d71_declaration.py",\n',
    )
    zero_world_counts = '''            "success_terminal_native_producer_count": 3,
            "success_terminal_shared_projector_count": 1,
            "success_terminal_complete_contract_surface_count": 4,
            "success_terminal_positive_projection_decision_count": 3,
            "success_terminal_negative_root_count_mutation_count": 5,
            "success_terminal_negative_projection_decision_count": 15,
'''
    text = _replace_section(
        text,
        '            "receipt_contract_producer_projection_count": 1,\n',
        '            "compact_ghost_model_construction_count": 0,\n',
        zero_world_counts,
    )
    text = _replace_exact(
        text,
        '            "compact_receipt_contract_ghost_passed": True,\n',
        '            "compact_success_terminal_projection_ghost_passed": True,\n',
    )
    text = _replace_exact(
        text,
        '            "receipt_contract_conforms_for_complete_declared_surface_population": True,\n',
        '            "success_terminal_projection_conforms_for_complete_declared_producer_population": True,\n',
    )
    return text


def _zero_world_runner() -> str:
    text = _common("sdk/run_qsdk_r23d70_zero_world.ps1")
    text = text.replace(
        "materialize_r23d71_production_route_sources.py",
        "materialize_r23d71_success_terminal_sources.py",
    )
    text = text.replace(
        "tests\\test_qsdk_r23d71_receipt_contract_ghost.ps1",
        "tests\\test_qsdk_r23d71_success_terminal_projection_ghost.ps1",
    )
    text = text.replace(
        "R23D71 production route sources check",
        "R23D71 success-terminal sources check",
    )
    text = text.replace(
        "[turning/3e] PASS R23D71 receipt-contract ghost",
        "[turning/3e] PASS R23D71 success-terminal ghost",
    )
    receipt_counts = '''    compact_success_terminal_projection_ghost_passed = $true
    success_terminal_native_producer_count = 3
    success_terminal_shared_projector_count = 1
    success_terminal_complete_contract_surface_count = 4
    success_terminal_positive_projection_decision_count = 3
    success_terminal_negative_root_count_mutation_count = 5
    success_terminal_negative_projection_decision_count = 15
'''
    text = _replace_section(
        text,
        "    compact_receipt_contract_ghost_passed = $true\n",
        "    compact_ghost_model_construction_count = 0\n",
        receipt_counts,
    )
    text = text.replace(
        "# The compact complete-production-row ghosts run before the full-volume evaluator.\n"
        "# They prove both repaired code seams execute without claiming behavior.\n",
        "# The compact native success-terminal ghost runs before the full-volume evaluator.\n"
        "# It proves all three producer seams and the unchanged projector without behavior.\n",
    )
    text = text.replace(
        '"receipt_contract=4/4 negatives=12/12 workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
        '"success_terminal=4/4 negatives=15/15 workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
    )
    return text


def _zero_world_audit() -> str:
    text = _common("tests/test_qsdk_r23d70_zero_world.ps1")
    receipt_counts = '''    [bool]$receipt.compact_success_terminal_projection_ghost_passed -and
    [int]$receipt.success_terminal_native_producer_count -eq 3 -and
    [int]$receipt.success_terminal_shared_projector_count -eq 1 -and
    [int]$receipt.success_terminal_complete_contract_surface_count -eq 4 -and
    [int]$receipt.success_terminal_positive_projection_decision_count -eq 3 -and
    [int]$receipt.success_terminal_negative_root_count_mutation_count -eq 5 -and
    [int]$receipt.success_terminal_negative_projection_decision_count -eq 15 -and
'''
    text = _replace_section(
        text,
        "    [bool]$receipt.compact_receipt_contract_ghost_passed -and\n",
        "    [int]$receipt.compact_ghost_model_construction_count -eq 0 -and\n",
        receipt_counts,
    )
    text = text.replace(
        '"receipt_contract=4/4 negatives=12/12 workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
        '"success_terminal=4/4 negatives=15/15 workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
    )
    return text


def _campaign_roles() -> str:
    text = _common("tests/test_qsdk_r23d70_campaign_roles.ps1")
    text = _replace_exact(
        text,
        "            [int]$supervisor.terminal_transport_control_count -eq 3 -and\n",
        "            [int]$supervisor.terminal_transport_control_count -eq 6 -and\n"
        "            [int]$supervisor.success_terminal_transport_control_count -eq 3 -and\n"
        "            [int]$supervisor.failure_terminal_transport_control_count -eq 3 -and\n",
    )
    text = _replace_exact(
        text,
        "            terminal_transport_control_count =\n"
        "                [int]$supervisor.terminal_transport_control_count\n",
        "            terminal_transport_control_count =\n"
        "                [int]$supervisor.terminal_transport_control_count\n"
        "            success_terminal_transport_control_count =\n"
        "                [int]$supervisor.success_terminal_transport_control_count\n"
        "            failure_terminal_transport_control_count =\n"
        "                [int]$supervisor.failure_terminal_transport_control_count\n",
    )
    return text


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/turning/materialize_r23d71_implementation.py", _implementation),
    (ROOT / "sdk/run_qsdk_r23d71_zero_world.ps1", _zero_world_runner),
    (ROOT / "tests/test_qsdk_r23d71_zero_world.ps1", _zero_world_audit),
    (
        ROOT / "tests/test_qsdk_r23d71_evaluator.ps1",
        lambda: _common("tests/test_qsdk_r23d70_evaluator.ps1"),
    ),
    (ROOT / "tests/test_qsdk_r23d71_campaign_roles.ps1", _campaign_roles),
    (
        ROOT / "sdk/turning/materialize_r23d71_campaign_attestation_manifest.py",
        lambda: _common(
            "sdk/turning/materialize_r23d70_campaign_attestation_manifest.py"
        ),
    ),
)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    for path, compose in OUTPUTS:
        raw = compose().encode("utf-8")
        relative = path.relative_to(ROOT).as_posix()
        if arguments.command == "write":
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        elif not path.is_file() or path.read_bytes() != raw:
            raise MaterializationError(f"R23D71_SCAFFOLD_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D71 implementation scaffold {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
