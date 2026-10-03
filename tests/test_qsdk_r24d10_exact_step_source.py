#!/usr/bin/env python3
"""Static zero-world source audit for the R24D10 exact-step implementation."""

from __future__ import annotations

import hashlib
import json
import pathlib
import subprocess
import sys
from typing import Callable


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
DECLARATION_AUDIT = REPO_ROOT / (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_preregistration.py"
)
EVALUATOR = REPO_ROOT / (
    "sdk/recovery/"
    "r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "characterization_evaluator.py"
)
RIG = REPO_ROOT / (
    "scripts/lab/rigs/"
    "r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd"
)
WORKER = REPO_ROOT / (
    "tests/"
    "test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd"
)


class SourceAuditError(ValueError):
    """Stable source-conformance rejection."""


def fail(code: str) -> None:
    raise SourceAuditError(code)


def read_source(path: pathlib.Path) -> str:
    if not path.is_file():
        fail(f"missing:{path.relative_to(REPO_ROOT).as_posix()}")
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def require_markers(text: str, markers: list[str], family: str) -> None:
    for marker in markers:
        if marker not in text:
            fail(f"{family}_marker:{marker}")


def require_order(text: str, markers: list[str], family: str) -> None:
    offsets = [text.find(marker) for marker in markers]
    if any(offset < 0 for offset in offsets) or offsets != sorted(offsets):
        fail(f"{family}_order:{'|'.join(markers)}")


def validate_rig(text: str) -> None:
    require_markers(
        text,
        [
            "class_name R24D10GodotJoltExactStepNumericalTelemetryRig",
            'const FIXTURE_ID := "QSDK.R24D10.godot_jolt_exact_step_numerical_telemetry.v1"',
            "const CELL_SPECS := R24D9Rig.CELL_SPECS",
            "static func describe() -> Dictionary:",
            'description["fixture_id"] = FIXTURE_ID',
            "static func build() -> Dictionary:",
            "return R24D9Rig.build()",
            "static func activate(cell: Dictionary) -> int:",
            "return R24D9Rig.activate(cell)",
            "static func canonical_rate_rad_s(cell: Dictionary) -> float:",
        ],
        "rig",
    )
    if "RigidBody3D.new()" in text or "HingeJoint3D.new()" in text:
        fail("rig_reimplemented_fixture")


def validate_worker(text: str) -> None:
    require_markers(
        text,
        [
            'extends "res://tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"',
            (
                '"pre_sample_physics_frame_count": 0,\n'
                '\t\t\t"terminal_physics_server_deactivation_count": ('
            ),
            '"space_step_sequence_initial_value": 0,',
            '"first_retained_space_step_sequence": first_token,',
            '"last_retained_space_step_sequence": last_token,',
            '"physics_step_count": derived_step_count,',
            '"extra_unretained_post_activation_step_count": 0,',
            '"first_pre_rate_capture_before_physics_server_enable": true,',
            '"physics_server_disabled_before_step_twenty_one": true,',
            "func _on_r24d10_exact_step_physics_frame() -> void:",
            'if cell_id == "limit_positive":',
            "token_values.sort()",
            "var derived_step_count := last_token",
            "QSDK_R24D10_WORKER_ZERO_WORLD",
            "QSDK_R24D10_PHYSICAL_RAW_REPORT",
            "QSDK_R24D10_GODOT_SUPERVISOR_TERMINATION_READY",
        ],
        "worker",
    )
    if "await physics_frame" in text:
        fail("worker_pre_sample_await_present")
    require_order(
        text,
        [
            "PhysicsServer3D.set_active(false)\n\tvar rig := R24D10Rig.build()",
            "initial_velocity_write_count += R24D10Rig.activate(cell)",
            "first_pre_rate_by_id[cell_id] = R24D10Rig.canonical_rate_rad_s(cell)",
            "physics_frame.connect(_on_r24d10_exact_step_physics_frame)",
        ],
        "worker_initial_state_before_schedule",
    )
    callback_start = text.find("func _on_r24d10_exact_step_physics_frame() -> void:")
    callback_end = text.find("func _r24d10_abort_schedule", callback_start)
    if callback_start < 0 or callback_end < 0:
        fail("worker_callback_bounds")
    callback = text[callback_start:callback_end]
    require_order(
        callback,
        [
            "if not _r24d10_schedule_started:",
            "PhysicsServer3D.set_active(true)",
            'token = int(telemetry.get("read_space_step_sequence", -1))',
            "if token == R24D10Rig.MAXIMUM_PHYSICS_STEP_COUNT:",
            (
                "if token == R24D10Rig.MAXIMUM_PHYSICS_STEP_COUNT:\n"
                "\t\tPhysicsServer3D.set_active(false)"
            ),
            "physics_frame.disconnect(_on_r24d10_exact_step_physics_frame)",
            "_r24d10_finalize_physical_report()",
        ],
        "worker_callback_schedule",
    )
    if callback.count("PhysicsServer3D.set_active(true)") != 1:
        fail("worker_server_enable_count")


def validate_evaluator(text: str) -> None:
    require_markers(
        text,
        [
            'GATE_ID = "QSDK-R24D10"',
            'FIXTURE_ID = "QSDK.R24D10.godot_jolt_exact_step_numerical_telemetry.v1"',
            '"sha256:a5a1e988734877564ae9288fb33c8ac30a99be86edccb4409400031c1b579554"',
            "EXPECTED_TOKEN_POPULATION = list(range(1, 21))",
            "def validate_exact_step_samples(cells_value: Any, execution: dict[str, Any]) -> None:",
            "if observed_population != EXPECTED_TOKEN_POPULATION:",
            "if derived_count != int(execution[\"physics_step_count\"]):",
            "translate_for_r24d9_kernel(report)",
            '"kernel_invoked_only_after_r24d10_exact_step_validation": True,',
            '"pre_sample_physics_frame_count": 0,',
            '"extra_unretained_post_activation_step_count": 0,',
            "NEW_NEGATIVE_CONTROLS = [",
        ],
        "evaluator",
    )
    require_order(
        text,
        [
            "validate_report(\n        report,",
            "translated = translate_for_r24d9_kernel(report)",
            "kernel_evaluation = R24D9.evaluate_report(",
        ],
        "evaluator_exact_step_before_kernel",
    )


def run_cli(path: pathlib.Path, arguments: list[str], marker: str) -> dict[str, object]:
    completed = subprocess.run(
        [sys.executable, str(path), *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        fail(f"cli_failed:{path.name}:{completed.stdout}:{completed.stderr}")
    lines = [line for line in completed.stdout.splitlines() if line.startswith(marker)]
    if len(lines) != 1:
        fail(f"cli_marker:{path.name}:{marker}")
    value = json.loads(lines[0][len(marker) :])
    if not isinstance(value, dict) or value.get("ok") is not True:
        fail(f"cli_receipt:{path.name}")
    return value


def mutation_controls(
    family: str,
    text: str,
    validator: Callable[[str], None],
    markers: list[str],
) -> int:
    rejected = 0
    for marker in markers:
        if text.count(marker) != 1:
            fail(f"mutation_source_marker:{family}:{marker}")
        mutated = text.replace(marker, f"R24D10_MUTATED_{hashlib.sha256(marker.encode()).hexdigest()}", 1)
        try:
            validator(mutated)
        except SourceAuditError:
            rejected += 1
            continue
        fail(f"source_mutation_accepted:{family}:{marker}")
    return rejected


def main() -> int:
    try:
        # The declaration audit emits compact key=value text; execute it and
        # verify the exact zero-world terminal marker separately.
        declaration = subprocess.run(
            [sys.executable, str(DECLARATION_AUDIT)],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if (
            declaration.returncode != 0
            or "QSDK_R24D10_DECLARATION_AUDIT_PASS " not in declaration.stdout
            or "worlds=0 builds=0 solver_steps=0" not in declaration.stdout
        ):
            fail("declaration_audit")
        evaluator_receipt = run_cli(
            EVALUATOR,
            ["--self-test"],
            "QSDK_R24D10_EVALUATOR_SELF_TEST ",
        )
        if (
            evaluator_receipt.get("inherited_r24d9_rejected_negative_control_count") != 46
            or evaluator_receipt.get("rejected_new_exact_step_negative_control_count") != 12
            or evaluator_receipt.get("accepted_descriptive_outcome_mutation_count") != 3
            or evaluator_receipt.get("solver_step_count") != 0
        ):
            fail("evaluator_self_test_counts")

        rig_text = read_source(RIG)
        worker_text = read_source(WORKER)
        evaluator_text = read_source(EVALUATOR)
        validate_rig(rig_text)
        validate_worker(worker_text)
        validate_evaluator(evaluator_text)
        rejected = 0
        rejected += mutation_controls(
            "rig",
            rig_text,
            validate_rig,
            [
                "const CELL_SPECS := R24D9Rig.CELL_SPECS",
                "return R24D9Rig.build()",
                "return R24D9Rig.activate(cell)",
            ],
        )
        rejected += mutation_controls(
            "worker",
            worker_text,
            validate_worker,
            [
                "PhysicsServer3D.set_active(false)\n\tvar rig := R24D10Rig.build()",
                "first_pre_rate_by_id[cell_id] = R24D10Rig.canonical_rate_rad_s(cell)",
                "PhysicsServer3D.set_active(true)",
                'token = int(telemetry.get("read_space_step_sequence", -1))',
                "PhysicsServer3D.set_active(false)\n\t\t_r24d10_terminal_deactivation_count += 1",
                "var derived_step_count := last_token",
                (
                    '"pre_sample_physics_frame_count": 0,\n'
                    '\t\t\t"terminal_physics_server_deactivation_count": ('
                ),
            ],
        )
        rejected += mutation_controls(
            "evaluator",
            evaluator_text,
            validate_evaluator,
            [
                "if observed_population != EXPECTED_TOKEN_POPULATION:",
                "if derived_count != int(execution[\"physics_step_count\"]):",
                "translated = translate_for_r24d9_kernel(report)",
                '"kernel_invoked_only_after_r24d10_exact_step_validation": True,',
            ],
        )
        print(
            "QSDK_R24D10_EXACT_STEP_SOURCE_AUDIT_PASS "
            f"source_mutations={rejected} inherited_controls=46 "
            "new_exact_step_controls=12 adverse_outcomes=3 "
            "worlds=0 builds=0 solver_steps=0 physical_authority=false"
        )
        return 0
    except (SourceAuditError, OSError, json.JSONDecodeError) as exc:
        print(f"QSDK_R24D10_EXACT_STEP_SOURCE_AUDIT_FAILURE {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
