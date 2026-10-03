#!/usr/bin/env python3
"""Exact-step evaluator for the QSDK-R24D10 development successor.

R24D10 validates the scheduling facts omitted by R24D9, then delegates the
unchanged numerical/report surface to the immutable content-addressed R24D9
kernel. The adapter never treats an R24D9 result as evidence and never weakens
the R24D10 execution-validity checks.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import pathlib
import sys
from typing import Any, Callable


HERE = pathlib.Path(__file__).resolve().parent
R24D9_EVALUATOR_PATH = HERE / (
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_"
    "characterization_evaluator.py"
)
R24D9_EVALUATOR_RAW_SHA256 = (
    "sha256:a5a1e988734877564ae9288fb33c8ac30a99be86edccb4409400031c1b579554"
)
RAW_SCHEMA = (
    "sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "raw_report_v1"
)
EVALUATION_SCHEMA = (
    "sporespore_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "evaluation_v1"
)
GATE_ID = "QSDK-R24D10"
FIXTURE_ID = "QSDK.R24D10.godot_jolt_exact_step_numerical_telemetry.v1"
EXPECTED_SOURCE = "0123456789abcdef0123456789abcdef01234567"
EXPECTED_NONCE = "0123456789abcdef0123456789abcdef"
EXPECTED_TOKEN_POPULATION = list(range(1, 21))
EXPECTED_INITIAL_PROJECTION_BY_CELL = {
    "drive_positive": 0.0,
    "drive_negative": 0.0,
    "brake_positive": 0.4000000059604645,
    "brake_negative": -0.4000000059604645,
    "disabled_positive": 0.4000000059604645,
    "disabled_negative": -0.4000000059604645,
    "limit_positive": 0.0,
    "limit_negative": 0.0,
    "sleep_stale": 0.0,
}
AUTHORIZATION = {
    "closure_id": "QSDK-R24D9-PH1-CLOSURE",
    "closure_path": (
        "sdk/recovery/"
        "r24d9_godot_jolt_one_hinge_numerical_telemetry_"
        "physical_failure_closure_v1.json"
    ),
    "closure_raw_sha256": (
        "sha256:ef054432bf3aa15673a49c9765a3221ffd337c2becb9ba96f1951c81f87b4fde"
    ),
    "closure_publication_commit": "fa4001578e244deff25cce4dd32d7a0c9e5d3418",
    "authorization_kind": "distinct_corrective_development_declaration_only",
    "r24d9_result_reused_or_reinterpreted": False,
}
EXECUTION_INTEGER_FIELDS = {
    "world_attempt_count": 1,
    "world_build_count": 1,
    "physics_step_count": 20,
    "retained_sample_count": 68,
    "direct_force_write_count": 0,
    "direct_torque_write_count": 0,
    "direct_impulse_write_count": 0,
    "post_activation_transform_write_count": 0,
    "pre_activation_initial_angular_velocity_write_count": 4,
    "declared_sleep_input_write_count": 1,
    "schedule_start_physics_frame_boundary_count": 1,
    "pre_sample_physics_frame_count": 0,
    "terminal_physics_server_deactivation_count": 1,
    "outcome_dependent_early_stop_count": 0,
    "space_step_sequence_initial_value": 0,
    "first_retained_space_step_sequence": 1,
    "last_retained_space_step_sequence": 20,
    "observed_retained_awake_space_step_token_count": 20,
    "extra_unretained_post_activation_step_count": 0,
}
EXECUTION_BOOLEAN_FIELDS = {
    "first_pre_rate_capture_before_physics_server_enable": True,
    "physics_server_disabled_before_step_twenty_one": True,
}
PHYSICS_STEP_COUNT_SOURCE = (
    "max_retained_awake_read_space_step_sequence_minus_"
    "zero_initialized_space_step_sequence"
)
NEW_NEGATIVE_CONTROLS = [
    "pre_sample_frame_count_one_rejected",
    "first_retained_token_two_rejected",
    "last_retained_token_twenty_one_rejected",
    "retained_token_gap_rejected",
    "retained_token_duplicate_rejected",
    "worker_literal_step_count_disagreement_rejected",
    "observed_token_count_disagreement_rejected",
    "first_braking_pre_rate_consumed_to_zero_rejected",
    "first_disabled_pre_rate_sign_shift_rejected",
    "limit_cell_token_population_disagreement_rejected",
    "schedule_start_boundary_count_mutation_rejected",
    "extra_unretained_post_activation_step_claim_rejected",
]


class EvaluationError(ValueError):
    """A stable fail-closed R24D10 report rejection."""


def fail(code: str) -> None:
    raise EvaluationError(code)


def raw_sha256(path: pathlib.Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_r24d9_kernel() -> Any:
    if not R24D9_EVALUATOR_PATH.is_file():
        fail("r24d9_kernel_missing")
    if raw_sha256(R24D9_EVALUATOR_PATH) != R24D9_EVALUATOR_RAW_SHA256:
        fail("r24d9_kernel_identity")
    spec = importlib.util.spec_from_file_location(
        "sporespore_qsdk_r24d9_evaluator_kernel",
        R24D9_EVALUATOR_PATH,
    )
    if spec is None or spec.loader is None:
        fail("r24d9_kernel_import_spec")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


R24D9 = load_r24d9_kernel()
RUNTIME_PROVENANCE = copy.deepcopy(R24D9.RUNTIME_PROVENANCE)
RUNTIME_PROVENANCE.pop("r24d9_independent_cold_build_required")
RUNTIME_PROVENANCE["r24d10_independent_cold_build_required"] = True


def strict_loads(text: str) -> dict[str, Any]:
    try:
        return R24D9.strict_loads(text)
    except R24D9.EvaluationError as exc:
        raise EvaluationError(str(exc)) from exc


def object_value(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(code)
    return value


def list_value(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        fail(code)
    return value


def integer(value: Any, code: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        fail(code)
    return value


def boolean(value: Any, code: str) -> bool:
    if not isinstance(value, bool):
        fail(code)
    return value


def finite(value: Any, code: str) -> float:
    try:
        return R24D9._finite(value, code)
    except R24D9.EvaluationError as exc:
        raise EvaluationError(str(exc)) from exc


def exact_keys(value: dict[str, Any], expected: set[str], code: str) -> None:
    if set(value) != expected:
        fail(code)


def exact_mapping(value: Any, expected: dict[str, Any], code: str) -> None:
    observed = object_value(value, f"{code}_not_object")
    exact_keys(observed, set(expected), f"{code}_field_set")
    if observed != expected:
        fail(code)


def validate_identity(value: Any, length: int, code: str) -> str:
    try:
        return R24D9._valid_identity(value, length, code)
    except R24D9.EvaluationError as exc:
        raise EvaluationError(str(exc)) from exc


def validate_execution(value: Any) -> dict[str, Any]:
    execution = object_value(value, "execution_not_object")
    expected_keys = (
        set(EXECUTION_INTEGER_FIELDS)
        | set(EXECUTION_BOOLEAN_FIELDS)
        | {"physics_step_count_source"}
    )
    exact_keys(execution, expected_keys, "execution_field_set")
    for key, expected in EXECUTION_INTEGER_FIELDS.items():
        if integer(execution.get(key), f"execution_{key}_type") != expected:
            fail(f"execution_{key}")
    for key, expected in EXECUTION_BOOLEAN_FIELDS.items():
        if boolean(execution.get(key), f"execution_{key}_type") is not expected:
            fail(f"execution_{key}")
    if execution.get("physics_step_count_source") != PHYSICS_STEP_COUNT_SOURCE:
        fail("execution_physics_step_count_source")
    return execution


def validate_exact_step_samples(cells_value: Any, execution: dict[str, Any]) -> None:
    cells = list_value(cells_value, "cells_not_array")
    if len(cells) != 9:
        fail("cell_count")
    observed_ids: list[str] = []
    global_awake_read_tokens: set[int] = set()
    for cell_value in cells:
        cell = object_value(cell_value, "cell_not_object")
        cell_id = cell.get("cell_id")
        if not isinstance(cell_id, str) or cell_id not in EXPECTED_INITIAL_PROJECTION_BY_CELL:
            fail("cell_identity")
        observed_ids.append(cell_id)
        samples = list_value(cell.get("samples"), f"cell_{cell_id}_samples")
        if not samples:
            fail(f"cell_{cell_id}_samples_empty")
        first_sample = object_value(samples[0], f"cell_{cell_id}_sample_1")
        first_pre = finite(
            first_sample.get("pre_canonical_relative_rate_rad_s"),
            f"cell_{cell_id}_first_pre_rate_type",
        )
        if first_pre != EXPECTED_INITIAL_PROJECTION_BY_CELL[cell_id]:
            fail(f"cell_{cell_id}_first_pre_rate_not_declared_initial_projection")
        expected_tokens = list(range(1, len(samples) + 1))
        observed_reads: list[int] = []
        observed_captures: list[int] = []
        observed_sequences: list[int] = []
        for sample_index, sample_value in enumerate(samples, start=1):
            sample = object_value(
                sample_value,
                f"cell_{cell_id}_sample_{sample_index}_not_object",
            )
            telemetry = object_value(
                sample.get("telemetry"),
                f"cell_{cell_id}_sample_{sample_index}_telemetry",
            )
            read = integer(
                telemetry.get("read_space_step_sequence"),
                f"cell_{cell_id}_sample_{sample_index}_read_type",
            )
            capture = integer(
                telemetry.get("capture_space_step_sequence"),
                f"cell_{cell_id}_sample_{sample_index}_capture_type",
            )
            sequence = integer(
                telemetry.get("telemetry_sequence"),
                f"cell_{cell_id}_sample_{sample_index}_sequence_type",
            )
            current = boolean(
                telemetry.get("snapshot_is_current_space_step"),
                f"cell_{cell_id}_sample_{sample_index}_current_type",
            )
            observed_reads.append(read)
            observed_captures.append(capture)
            observed_sequences.append(sequence)
            if current:
                global_awake_read_tokens.add(read)
        if cell_id == "sleep_stale":
            if observed_reads != [1, 2, 3, 4]:
                fail("sleep_stale_read_tokens")
            if observed_captures != [1, 1, 1, 1]:
                fail("sleep_stale_capture_tokens")
            if observed_sequences != [1, 1, 1, 1]:
                fail("sleep_stale_telemetry_tokens")
        else:
            if observed_reads != expected_tokens:
                fail(f"cell_{cell_id}_read_token_population")
            if observed_captures != expected_tokens:
                fail(f"cell_{cell_id}_capture_token_population")
            if observed_sequences != expected_tokens:
                fail(f"cell_{cell_id}_telemetry_token_population")
    if observed_ids != list(R24D9.CELL_IDS):
        fail("cell_identity_or_order")
    observed_population = sorted(global_awake_read_tokens)
    if observed_population != EXPECTED_TOKEN_POPULATION:
        fail("global_retained_awake_read_token_population")
    derived_first = observed_population[0]
    derived_last = observed_population[-1]
    derived_count = derived_last - int(execution["space_step_sequence_initial_value"])
    if derived_first != int(execution["first_retained_space_step_sequence"]):
        fail("execution_first_token_not_derived")
    if derived_last != int(execution["last_retained_space_step_sequence"]):
        fail("execution_last_token_not_derived")
    if len(observed_population) != int(
        execution["observed_retained_awake_space_step_token_count"]
    ):
        fail("execution_token_count_not_derived")
    if derived_count != int(execution["physics_step_count"]):
        fail("execution_physics_step_count_not_token_derived")


def translate_for_r24d9_kernel(report: dict[str, Any]) -> dict[str, Any]:
    translated = copy.deepcopy(report)
    translated["schema_version"] = R24D9.RAW_SCHEMA
    translated["gate_id"] = R24D9.GATE_ID
    translated["authorization"] = copy.deepcopy(R24D9.AUTHORIZATION)
    translated["runtime_provenance"] = copy.deepcopy(R24D9.RUNTIME_PROVENANCE)
    translated["fixture"]["fixture_id"] = R24D9.FIXTURE_ID
    execution = translated["execution"]
    translated["execution"] = {
        "world_attempt_count": execution["world_attempt_count"],
        "world_build_count": execution["world_build_count"],
        "physics_step_count": execution["physics_step_count"],
        "retained_sample_count": execution["retained_sample_count"],
        "direct_force_write_count": execution["direct_force_write_count"],
        "direct_torque_write_count": execution["direct_torque_write_count"],
        "direct_impulse_write_count": execution["direct_impulse_write_count"],
        "post_activation_transform_write_count": execution[
            "post_activation_transform_write_count"
        ],
        "pre_activation_initial_angular_velocity_write_count": execution[
            "pre_activation_initial_angular_velocity_write_count"
        ],
        "declared_sleep_input_write_count": execution[
            "declared_sleep_input_write_count"
        ],
        "pre_sample_physics_frame_count": 1,
        "terminal_physics_server_deactivation_count": execution[
            "terminal_physics_server_deactivation_count"
        ],
        "outcome_dependent_early_stop_count": execution[
            "outcome_dependent_early_stop_count"
        ],
    }
    return translated


def validate_report(
    report: dict[str, Any],
    expected_source_commit: str,
    expected_nonce: str,
    expected_evidence_kind: str,
) -> None:
    exact_keys(
        report,
        {
            "schema_version",
            "gate_id",
            "question_class",
            "evidence_kind",
            "source_commit",
            "execution_nonce",
            "authorization",
            "runtime_provenance",
            "engine",
            "fixture",
            "refusals",
            "recomputation_contract",
            "cells",
            "execution",
            "evidence_provenance",
            "claims",
        },
        "top_level_field_set",
    )
    if report.get("schema_version") != RAW_SCHEMA:
        fail("schema_version")
    if report.get("gate_id") != GATE_ID:
        fail("gate_id")
    if report.get("question_class") != "development":
        fail("question_class")
    if expected_evidence_kind not in {"synthetic_zero_world", "native_physical"}:
        fail("expected_evidence_kind")
    if report.get("evidence_kind") != expected_evidence_kind:
        fail("evidence_kind")
    validate_identity(report.get("source_commit"), 40, "source_commit_format")
    validate_identity(report.get("execution_nonce"), 32, "execution_nonce_format")
    if report.get("source_commit") != expected_source_commit:
        fail("source_commit")
    if report.get("execution_nonce") != expected_nonce:
        fail("execution_nonce")
    exact_mapping(report.get("authorization"), AUTHORIZATION, "authorization")
    exact_mapping(
        report.get("runtime_provenance"),
        RUNTIME_PROVENANCE,
        "runtime_provenance",
    )
    fixture = object_value(report.get("fixture"), "fixture_not_object")
    if fixture.get("fixture_id") != FIXTURE_ID:
        fail("fixture_id")
    execution = validate_execution(report.get("execution"))
    validate_exact_step_samples(report.get("cells"), execution)


def evaluate_report(
    report: dict[str, Any],
    expected_source_commit: str,
    expected_nonce: str,
    expected_evidence_kind: str,
) -> dict[str, Any]:
    validate_report(
        report,
        expected_source_commit,
        expected_nonce,
        expected_evidence_kind,
    )
    translated = translate_for_r24d9_kernel(report)
    try:
        kernel_evaluation = R24D9.evaluate_report(
            translated,
            expected_source_commit,
            expected_nonce,
            expected_evidence_kind,
        )
    except R24D9.EvaluationError as exc:
        raise EvaluationError(f"r24d9_numerical_kernel:{exc}") from exc
    canonical = json.dumps(
        report,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    physical = expected_evidence_kind == "native_physical"
    kernel_evaluation["schema_version"] = EVALUATION_SCHEMA
    kernel_evaluation["gate_id"] = GATE_ID
    kernel_evaluation["result"] = (
        "complete_valid_finite_descriptive_native_exact_step_numerical_characterization"
        if physical
        else "synthetic_exact_step_shape_conforms_zero_world_only"
    )
    kernel_evaluation["raw_report_canonical_sha256"] = (
        "sha256:" + hashlib.sha256(canonical).hexdigest()
    )
    kernel_evaluation["exact_step_execution"] = {
        "space_step_sequence_initial_value": 0,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 20,
        "observed_retained_awake_space_step_token_count": 20,
        "token_derived_physics_step_count": 20,
        "pre_sample_physics_frame_count": 0,
        "extra_unretained_post_activation_step_count": 0,
        "all_declared_initial_real_t_projections_preserved": True,
    }
    kernel_evaluation["numerical_kernel_provenance"] = {
        "path": R24D9_EVALUATOR_PATH.name,
        "raw_sha256": R24D9_EVALUATOR_RAW_SHA256,
        "r24d9_result_reused_or_reinterpreted": False,
        "kernel_invoked_only_after_r24d10_exact_step_validation": True,
    }
    return kernel_evaluation


def synthetic_report(
    source_commit: str = EXPECTED_SOURCE,
    nonce: str = EXPECTED_NONCE,
) -> dict[str, Any]:
    report = R24D9.synthetic_report(source_commit, nonce)
    report["schema_version"] = RAW_SCHEMA
    report["gate_id"] = GATE_ID
    report["authorization"] = copy.deepcopy(AUTHORIZATION)
    report["runtime_provenance"] = copy.deepcopy(RUNTIME_PROVENANCE)
    report["fixture"]["fixture_id"] = FIXTURE_ID
    for cell in report["cells"]:
        cell_id = str(cell["cell_id"])
        cell["samples"][0]["pre_canonical_relative_rate_rad_s"] = (
            EXPECTED_INITIAL_PROJECTION_BY_CELL[cell_id]
        )
    report["execution"] = {
        **copy.deepcopy(EXECUTION_INTEGER_FIELDS),
        **copy.deepcopy(EXECUTION_BOOLEAN_FIELDS),
        "physics_step_count_source": PHYSICS_STEP_COUNT_SOURCE,
    }
    return report


def set_path(value: dict[str, Any], path: tuple[Any, ...], replacement: Any) -> None:
    cursor: Any = value
    for key in path[:-1]:
        cursor = cursor[key]
    cursor[path[-1]] = replacement


def mutation(
    path: tuple[Any, ...],
    replacement: Any,
) -> Callable[[dict[str, Any]], None]:
    return lambda value: set_path(value, path, replacement)


def cell_index(cell_id: str) -> int:
    return list(R24D9.CELL_IDS).index(cell_id)


def self_test() -> dict[str, Any]:
    inherited = R24D9.self_test()
    if (
        inherited.get("declared_negative_control_count") != 46
        or inherited.get("rejected_negative_control_count") != 46
        or inherited.get("accepted_descriptive_outcome_mutation_count") != 3
    ):
        fail("inherited_r24d9_self_test")
    baseline = synthetic_report()
    evaluation = evaluate_report(
        copy.deepcopy(baseline),
        EXPECTED_SOURCE,
        EXPECTED_NONCE,
        "synthetic_zero_world",
    )
    if not evaluation.get("ok") or not evaluation.get("execution_valid"):
        fail("baseline_evaluation")

    limit_positive = cell_index("limit_positive")
    limit_negative = cell_index("limit_negative")
    brake_positive = cell_index("brake_positive")
    disabled_negative = cell_index("disabled_negative")
    controls: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        (NEW_NEGATIVE_CONTROLS[0], mutation(("execution", "pre_sample_physics_frame_count"), 1)),
        (NEW_NEGATIVE_CONTROLS[1], mutation(("cells", limit_positive, "samples", 0, "telemetry", "read_space_step_sequence"), 2)),
        (NEW_NEGATIVE_CONTROLS[2], mutation(("cells", limit_positive, "samples", 19, "telemetry", "read_space_step_sequence"), 21)),
        (NEW_NEGATIVE_CONTROLS[3], mutation(("cells", limit_positive, "samples", 9, "telemetry", "read_space_step_sequence"), 11)),
        (NEW_NEGATIVE_CONTROLS[4], mutation(("cells", limit_positive, "samples", 9, "telemetry", "read_space_step_sequence"), 9)),
        (NEW_NEGATIVE_CONTROLS[5], mutation(("execution", "physics_step_count"), 19)),
        (NEW_NEGATIVE_CONTROLS[6], mutation(("execution", "observed_retained_awake_space_step_token_count"), 19)),
        (NEW_NEGATIVE_CONTROLS[7], mutation(("cells", brake_positive, "samples", 0, "pre_canonical_relative_rate_rad_s"), 0.0)),
        (NEW_NEGATIVE_CONTROLS[8], mutation(("cells", disabled_negative, "samples", 0, "pre_canonical_relative_rate_rad_s"), 0.4000000059604645)),
        (NEW_NEGATIVE_CONTROLS[9], mutation(("cells", limit_negative, "samples", 19, "telemetry", "capture_space_step_sequence"), 19)),
        (NEW_NEGATIVE_CONTROLS[10], mutation(("execution", "schedule_start_physics_frame_boundary_count"), 0)),
        (NEW_NEGATIVE_CONTROLS[11], mutation(("execution", "extra_unretained_post_activation_step_count"), 1)),
    ]
    rejected: list[str] = []
    for name, apply in controls:
        candidate = copy.deepcopy(baseline)
        apply(candidate)
        try:
            evaluate_report(
                candidate,
                EXPECTED_SOURCE,
                EXPECTED_NONCE,
                "synthetic_zero_world",
            )
        except EvaluationError:
            rejected.append(name)
            continue
        fail(f"negative_control_accepted:{name}")

    adverse_mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        (
            "opposite_signed_impulse",
            mutation(
                (
                    "cells",
                    limit_positive,
                    "samples",
                    0,
                    "telemetry",
                    "signed_motor_impulse_nms",
                ),
                -0.25,
            ),
        ),
        (
            "large_finite_work_residual",
            mutation(
                (
                    "cells",
                    brake_positive,
                    "samples",
                    0,
                    "telemetry",
                    "net_motor_work_j",
                ),
                123.0,
            ),
        ),
        (
            "finite_hard_cap_exceedance",
            mutation(
                (
                    "cells",
                    limit_negative,
                    "samples",
                    0,
                    "telemetry",
                    "signed_motor_impulse_nms",
                ),
                10.0,
            ),
        ),
    ]
    accepted: list[str] = []
    for name, apply in adverse_mutations:
        candidate = copy.deepcopy(baseline)
        apply(candidate)
        evaluate_report(
            candidate,
            EXPECTED_SOURCE,
            EXPECTED_NONCE,
            "synthetic_zero_world",
        )
        accepted.append(name)

    return {
        "ok": True,
        "schema_version": EVALUATION_SCHEMA,
        "gate_id": GATE_ID,
        "question_class": "development",
        "synthetic_cell_count": 9,
        "synthetic_sample_count": 68,
        "inherited_r24d9_negative_control_count": 46,
        "inherited_r24d9_rejected_negative_control_count": 46,
        "new_exact_step_negative_control_count": len(NEW_NEGATIVE_CONTROLS),
        "rejected_new_exact_step_negative_control_count": len(rejected),
        "rejected_new_exact_step_negative_controls": rejected,
        "accepted_descriptive_outcome_mutation_count": len(accepted),
        "accepted_descriptive_outcome_mutations": accepted,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 20,
        "token_derived_physics_step_count": 20,
        "pre_sample_physics_frame_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "native_numerical_telemetry_characterized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def write_json(path: pathlib.Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--emit-zero-world-template", type=pathlib.Path)
    parser.add_argument("--input", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--expected-source-commit", default=EXPECTED_SOURCE)
    parser.add_argument("--expected-nonce", default=EXPECTED_NONCE)
    parser.add_argument(
        "--expected-evidence-kind",
        choices=("synthetic_zero_world", "native_physical"),
        default="synthetic_zero_world",
    )
    args = parser.parse_args()
    try:
        if args.self_test:
            receipt = self_test()
            print(
                "QSDK_R24D10_EVALUATOR_SELF_TEST "
                + json.dumps(receipt, separators=(",", ":"))
            )
            return 0
        if args.emit_zero_world_template is not None:
            validate_identity(args.expected_source_commit, 40, "source_commit_format")
            validate_identity(args.expected_nonce, 32, "execution_nonce_format")
            report = synthetic_report(
                args.expected_source_commit,
                args.expected_nonce,
            )
            evaluate_report(
                copy.deepcopy(report),
                args.expected_source_commit,
                args.expected_nonce,
                "synthetic_zero_world",
            )
            write_json(args.emit_zero_world_template, report)
            print(
                "QSDK_R24D10_ZERO_WORLD_TEMPLATE "
                + json.dumps(
                    {
                        "ok": True,
                        "path": str(args.emit_zero_world_template),
                        "cell_count": 9,
                        "retained_sample_count": 68,
                        "first_retained_space_step_sequence": 1,
                        "last_retained_space_step_sequence": 20,
                        "token_derived_physics_step_count": 20,
                        "pre_sample_physics_frame_count": 0,
                        "world_attempt_count": 0,
                        "world_build_count": 0,
                        "solver_step_count": 0,
                        "physical_acceptance_authority": False,
                        "release_authority": False,
                    },
                    separators=(",", ":"),
                )
            )
            return 0
        if args.input is None or args.output is None:
            parser.error(
                "--input and --output are required unless a utility mode is selected"
            )
        report = strict_loads(args.input.read_text(encoding="utf-8"))
        evaluation = evaluate_report(
            report,
            args.expected_source_commit,
            args.expected_nonce,
            args.expected_evidence_kind,
        )
        write_json(args.output, evaluation)
        print(
            "QSDK_R24D10_EVALUATION_PASS "
            + json.dumps(evaluation, separators=(",", ":"))
        )
        return 0
    except EvaluationError as exc:
        print(
            "QSDK_R24D10_EVALUATION_FAILURE "
            + json.dumps(
                {
                    "ok": False,
                    "failure_code": str(exc),
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                separators=(",", ":"),
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
