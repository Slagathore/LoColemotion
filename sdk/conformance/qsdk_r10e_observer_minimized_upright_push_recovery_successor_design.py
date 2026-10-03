#!/usr/bin/env python3
"""Audit the QSDK-R10E retained diagnosis and successor design at zero worlds."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json"
)
EXPECTED_DESIGN_BYTES = 40_110
EXPECTED_DESIGN_SHA256 = (
    "sha256:791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a"
)
PASS_MARKER = "QSDK_R10E_OBSERVER_MINIMIZED_SUCCESSOR_DESIGN_PASS "
TERMINAL_MARKER = "QSDK_R10D_PHYSICAL_CELL "
EXPECTED_LIMBS = ("front_left", "front_right", "rear_left", "rear_right")
EXPECTED_WALKING_RECEIPTS = {
    "bounded_anchor_error",
    "bounded_hinge_axis_error",
    "bounded_joint_only_lateral_stride_steering",
    "bounded_lateral_drift",
    "bounded_tilt",
    "bounded_torso_height",
    "bounded_yaw_drift",
    "contact_gated_evidence_horizon_completed",
    "contact_gating_completed_without_timeout",
    "every_contact_observer_executed",
    "every_limb_completed_evidence_gait_horizon",
    "every_limb_forward_relocation",
    "every_limb_two_contact_cycles",
    "evidence_four_contact_stance",
    "explicit_sdk_controller_session_shutdown",
    "fixture_spec_compiled_before_world_creation",
    "initial_four_contact_stance",
    "initial_perturbation_within_declared_envelope",
    "minimum_evidence_forward_translation",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation",
    "no_torso_force_or_impulse_or_velocity_or_transform_command",
    "no_world_reset",
    "one_continuous_world",
    "pinned_jolt_solver_settings",
    "terminal_four_contact_recovery",
    "zero_torso_contact",
}
EXPECTED_TOP_LEVEL = {
    "schema_version",
    "status",
    "gate_id",
    "parent_gate_id",
    "design_id",
    "authored_parent_commit",
    "authored_local_date",
    "ledger_scope",
    "question_declaration",
    "diagnostic_question",
    "release_milestone_context",
    "bound_authorities",
    "consumed_predecessor_results",
    "retained_execution_diagnosis",
    "receipt_representation_diagnosis",
    "walking_diagnosis",
    "selected_morphology",
    "selected_successor_scope",
    "prospective_population",
    "trace_capture_contract",
    "scalar_receipt_contract",
    "preserved_behavior_contract",
    "decision_contract",
    "required_zero_world_controls",
    "forward_authority_sequence",
    "immutability_and_limits",
    "claim_boundary",
    "decision",
}
EXPECTED_ROLES = {
    "consumed_r10d_l1_development_closure",
    "consumed_r10d_l1_held_out_closure",
    "r10c_supported_start_phase_robust_design",
    "r10b_l3_exported_scalar_precedent_design",
    "qualified_exported_scalar_validation_helper",
    "r05e_exact_finite_morphology_closure",
    "r05e_exact_finite_descriptor_source",
    "r10d_world_evaluator_source",
    "r10d_live_walker_source",
    "r10d_task_frame_adapter_source",
    "selected_portable_policy",
    "sdk1_milestone_mapping_at_authored_parent",
    "r05e_retained_population_report",
    "r10d_development_retained_report",
    "r10d_held_out_retained_report",
    "r10d_completed_rejected_push_stdout",
}
EXPECTED_SELECTED_DESCRIPTOR = {
    "schema_version": "sporespore_physical_quadruped_proportion_spec_v1",
    "morphology_id": "qsdk_r05e_axis_star_foot_radius_low_s225",
    "torso_length_scale": 1.0,
    "torso_width_scale": 1.0,
    "upper_length_fraction": 0.5142857142857142,
    "hip_span_scale": 1.0,
    "foot_radius_scale": 0.99375,
    "front_limb_mass_scale": 1.0,
}
EXPECTED_R05E_SELECTED_RESULTS = {
    40101: {
        "sdk_step_count": 2704,
        "maximum_anchor_error_m": 0.01810907945036888,
        "maximum_tilt_rad": 0.1315586293070459,
        "minimum_torso_height_m": 0.42648059129714966,
        "evidence_task_frame_forward_displacement_m": 0.8115779161453247,
        "final_task_frame_forward_displacement_m": 0.9178757667541504,
        "final_task_frame_lateral_displacement_m": -0.008066480979323387,
    },
    40102: {
        "sdk_step_count": 2646,
        "maximum_anchor_error_m": 0.018479883670806885,
        "maximum_tilt_rad": 0.09621984435697023,
        "minimum_torso_height_m": 0.42865705490112305,
        "evidence_task_frame_forward_displacement_m": 0.9030119776725769,
        "final_task_frame_forward_displacement_m": 1.078850507736206,
        "final_task_frame_lateral_displacement_m": -0.06916341185569763,
    },
    40103: {
        "sdk_step_count": 2671,
        "maximum_anchor_error_m": 0.018456831574440002,
        "maximum_tilt_rad": 0.13237489516184037,
        "minimum_torso_height_m": 0.4284130036830902,
        "evidence_task_frame_forward_displacement_m": 0.8933971524238586,
        "final_task_frame_forward_displacement_m": 1.0859901905059814,
        "final_task_frame_lateral_displacement_m": 0.01014569029211998,
    },
}
EXPECTED_R10D_PUSH_DIAGNOSTICS = {
    "push_s40001": {
        "axis": [-0.005160260364324656, 0.0, 0.9999866857678519],
        "impulse": [-0.0012900651199743152, 0.0, 0.24999667704105377],
        "scalar_delta": 5.599165350698564e-9,
        "vector3_delta": 0.0,
        "evaluation_code": "",
    },
    "push_s40101": {
        "axis": [-0.004478213781743604, 0.0, 0.9999899727503897],
        "impulse": [-0.001119553460739553, 0.0, 0.24999749660491943],
        "scalar_delta": 3.4173562753875953e-9,
        "vector3_delta": 0.0,
        "evaluation_code": "",
    },
    "push_s40102": {
        "axis": [-0.0016781060799263795, 0.0, 0.999998591979001],
        "impulse": [-0.00041952653555199504, 0.0, 0.24999965727329254],
        "scalar_delta": 9.278555359999563e-9,
        "vector3_expected": [-0.0004195265064481646, 0.0, 0.24999964237213135],
        "vector3_delta": 1.4901189615557087e-8,
        "evaluation_code": "QSDK_R10D_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
    },
}


class AuditFailure(RuntimeError):
    """Raised when a bound byte, diagnosis, or claim boundary drifts."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git_blob_oid(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()  # noqa: S324 - Git identity


def git(args: tuple[str, ...], *, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=not binary,
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(args)}")
    if binary:
        require(isinstance(completed.stdout, bytes), "GIT_BINARY_TYPE")
        return completed.stdout
    require(isinstance(completed.stdout, str), "GIT_TEXT_TYPE")
    return completed.stdout.strip()


def read_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}_JSON_INVALID:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def exact_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(
            exact_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            exact_equal(left, right) for left, right in zip(actual, expected)
        )
    return bool(actual == expected)


def dotted(value: Any, path: str) -> Any:
    current = value
    for part in path.split("."):
        require(isinstance(current, dict) and part in current, f"DOTTED_MISSING:{path}")
        current = current[part]
    return current


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", float(value)))[0]


def vector3_multiply(values: list[float], scalar: float) -> list[float]:
    scalar32 = f32(scalar)
    return [f32(f32(component) * scalar32) for component in values]


def vector3_length(values: list[float]) -> float:
    squared = [f32(f32(value) * f32(value)) for value in values]
    summed = f32(f32(squared[0] + squared[1]) + squared[2])
    return f32(math.sqrt(summed))


def vector3_distance(left: list[float], right: list[float]) -> float:
    delta = [f32(f32(a) - f32(b)) for a, b in zip(left, right)]
    return vector3_length(delta)


def scalar_distance(left: list[float], right: list[float]) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def canonical_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return sha256_bytes(raw)


def load_bound_authorities(
    design: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], dict[str, bytes]]:
    entries = design.get("bound_authorities")
    require(isinstance(entries, list), "BOUND_AUTHORITIES_NOT_LIST")
    require(len(entries) == len(EXPECTED_ROLES), "BOUND_AUTHORITY_COUNT")
    roles: dict[str, dict[str, Any]] = {}
    raw_by_role: dict[str, bytes] = {}
    for entry in entries:
        require(isinstance(entry, dict), "BOUND_AUTHORITY_ENTRY_TYPE")
        role = entry.get("role")
        require(isinstance(role, str) and role not in roles, "BOUND_AUTHORITY_ROLE")
        require(role in EXPECTED_ROLES, f"BOUND_AUTHORITY_UNEXPECTED:{role}")
        path_value = entry.get("path")
        require(isinstance(path_value, str), f"BOUND_PATH:{role}")
        if entry.get("path_kind") == "absolute_durable_evidence":
            path = Path(path_value)
            require(path.is_absolute() and path.is_file(), f"BOUND_ABSOLUTE_MISSING:{role}")
            raw = path.read_bytes()
        else:
            require("path_kind" not in entry, f"BOUND_PATH_KIND:{role}")
            source_commit = entry.get("source_commit")
            require(isinstance(source_commit, str), f"BOUND_SOURCE_COMMIT:{role}")
            raw = git(("show", f"{source_commit}:{path_value}"), binary=True)
            require(
                git_blob_oid(raw) == entry.get("git_blob_oid"),
                f"BOUND_BLOB:{role}",
            )
        require(len(raw) == entry.get("byte_length"), f"BOUND_BYTES:{role}")
        require(sha256_bytes(raw) == entry.get("raw_sha256"), f"BOUND_SHA:{role}")
        roles[role] = entry
        raw_by_role[role] = raw
        expected = entry.get("expected")
        if expected is not None:
            loaded = read_json(raw, f"BOUND_{role}")
            require(isinstance(expected, dict), f"BOUND_EXPECTED_TYPE:{role}")
            for path, expected_value in expected.items():
                require(
                    exact_equal(dotted(loaded, path), expected_value),
                    f"BOUND_EXPECTED:{role}:{path}",
                )
    require(set(roles) == EXPECTED_ROLES, "BOUND_ROLE_SET")
    return roles, raw_by_role


def retained_tree_inventory(root: Path) -> dict[str, Any]:
    require(root.is_dir(), f"EVIDENCE_ROOT_MISSING:{root}")
    entries: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
        require(not path.is_symlink(), f"EVIDENCE_SYMLINK:{path}")
        if path.is_file():
            raw = path.read_bytes()
            entries.append(
                {
                    "path": path.relative_to(root).as_posix(),
                    "byte_length": len(raw),
                    "raw_sha256": sha256_bytes(raw),
                }
            )
    paths = [entry["path"] for entry in entries]
    return {
        "schema_version": "sporespore_qsdk_r10d_retained_evidence_tree_v1",
        "root": str(root),
        "file_count": len(entries),
        "total_byte_length": sum(entry["byte_length"] for entry in entries),
        "path_set_sha256": sha256_bytes("\n".join(paths).encode("utf-8")),
        "manifest_sha256": canonical_sha256(entries),
        "files": entries,
    }


def validate_retained_tree(closure: dict[str, Any], label: str) -> dict[str, Any]:
    expected = dotted(closure, "evidence.retained_evidence_tree")
    require(isinstance(expected, dict), f"{label}_TREE_TYPE")
    actual = retained_tree_inventory(Path(expected["root"]))
    require(exact_equal(actual, expected), f"{label}_TREE_DRIFT")
    return actual


def load_completed_cell(path: Path, *, stdout_marker: bool = False) -> dict[str, Any]:
    if stdout_marker:
        lines = path.read_text(encoding="utf-8").splitlines()
        require(len(lines) == 30, "REJECTED_STDOUT_LINE_COUNT")
        terminal = lines[-1]
        require(terminal.startswith(TERMINAL_MARKER), "REJECTED_TERMINAL_MARKER")
        require(len(terminal) == 6_813_227, "REJECTED_TERMINAL_LENGTH")
        return read_json(
            terminal[len(TERMINAL_MARKER) :].encode("utf-8"),
            "REJECTED_TERMINAL_CELL",
        )
    return read_json(path.read_bytes(), f"CELL_{path.parent.name}")


def trace_rows(cell: dict[str, Any], label: str) -> list[dict[str, Any]]:
    trace = cell.get("sdk_physical_trace")
    require(isinstance(trace, dict), f"{label}_TRACE_TYPE")
    rows = trace.get("rows")
    require(isinstance(rows, list), f"{label}_ROWS_TYPE")
    require(trace.get("row_count") == len(rows), f"{label}_ROW_COUNT")
    require(all(isinstance(row, dict) for row in rows), f"{label}_ROW_OBJECT")
    return rows


def marker_row(cell: dict[str, Any], label: str) -> dict[str, Any]:
    matches = [row for row in trace_rows(cell, label) if row.get("semantic_step") == 900]
    require(len(matches) == 1, f"{label}_MARKER_ROW_COUNT")
    return matches[0]


def current_application_predicates(
    cell: dict[str, Any], marker: dict[str, Any]
) -> dict[str, bool]:
    summary = cell.get("runtime_summary_projection")
    require(isinstance(summary, dict), "APPLICATION_SUMMARY_TYPE")
    receipt = summary.get("external_push_receipt")
    require(isinstance(receipt, dict), "APPLICATION_RECEIPT_TYPE")
    impulse_task = receipt.get("impulse_task_n_s")
    impulse_world = receipt.get("impulse_world_n_s")
    observed_delta = receipt.get("observed_next_tick_velocity_delta_world_m_s")
    axis = marker.get("task_frame_lateral_axis_world_unit")
    for values, label in (
        (impulse_task, "TASK"),
        (impulse_world, "WORLD"),
        (observed_delta, "DELTA"),
        (axis, "AXIS"),
    ):
        require(
            isinstance(values, list)
            and len(values) == 3
            and all(type(item) in (int, float) and math.isfinite(item) for item in values),
            f"APPLICATION_{label}_SHAPE",
        )
    expected_world = vector3_multiply(axis, 0.25)
    effect_magnitude = receipt.get("observed_next_tick_velocity_delta_magnitude_m_s")
    require(type(effect_magnitude) is float, "APPLICATION_EFFECT_TYPE")
    return {
        "summary_count": summary.get("external_push_application_count") == 1,
        "profile": receipt.get("profile_id") == "lateral_impulse_v1",
        "target": receipt.get("target_body_id") == "torso",
        "method": receipt.get("application_method")
        == "RigidBody3D.apply_central_impulse",
        "semantic_step": receipt.get("step_from_sdk_start") == 900,
        "receipt_count": receipt.get("application_count") == 1,
        "not_controller_command": receipt.get("controller_command") is False,
        "effect_sampled": receipt.get("effect_sampled") is True,
        "task_impulse": vector3_distance(impulse_task, [0.0, 0.0, 0.25])
        <= f32(0.00001),
        "world_impulse_finite": all(math.isfinite(item) for item in impulse_world),
        "marker_axis_finite": all(math.isfinite(item) for item in axis),
        "world_impulse_link": vector3_distance(impulse_world, expected_world) <= 1e-12,
        "observed_delta_finite": all(math.isfinite(item) for item in observed_delta),
        "effect_magnitude_finite": math.isfinite(effect_magnitude),
        "effect_magnitude_link": abs(
            vector3_length(observed_delta) - effect_magnitude
        )
        <= 1e-9,
    }


def validate_push_diagnostics(
    design: dict[str, Any],
    development_closure: dict[str, Any],
    held_closure: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], int]:
    dev_root = Path(dotted(development_closure, "evidence.retained_evidence_tree.root"))
    held_root = Path(dotted(held_closure, "evidence.retained_evidence_tree.root"))
    cells = {
        "push_s40001": load_completed_cell(dev_root / "push_s40001/cell.json"),
        "push_s40101": load_completed_cell(held_root / "push_s40101/cell.json"),
        "push_s40102": load_completed_cell(
            held_root / "push_s40102/stdout.log", stdout_marker=True
        ),
    }
    design_rows = dotted(design, "receipt_representation_diagnosis.diagnostic_cells")
    require(isinstance(design_rows, list), "DESIGN_DIAGNOSTIC_ROWS_TYPE")
    design_by_cell = {row.get("cell_id"): row for row in design_rows}
    require(set(design_by_cell) == set(cells), "DESIGN_DIAGNOSTIC_CELL_SET")
    predicate_total = 0
    for cell_id, cell in cells.items():
        expected = EXPECTED_R10D_PUSH_DIAGNOSTICS[cell_id]
        require(cell.get("cell_id") == cell_id, f"PUSH_CELL_ID:{cell_id}")
        row = marker_row(cell, cell_id)
        axis = row.get("task_frame_lateral_axis_world_unit")
        receipt = dotted(cell, "runtime_summary_projection.external_push_receipt")
        impulse = receipt.get("impulse_world_n_s")
        require(exact_equal(axis, expected["axis"]), f"PUSH_AXIS:{cell_id}")
        require(exact_equal(impulse, expected["impulse"]), f"PUSH_IMPULSE:{cell_id}")
        scalar_expected = [component * 0.25 for component in axis]
        scalar_delta = scalar_distance(impulse, scalar_expected)
        require(
            math.isclose(scalar_delta, expected["scalar_delta"], rel_tol=0.0, abs_tol=1e-22),
            f"PUSH_SCALAR_DELTA:{cell_id}",
        )
        vector_expected = vector3_multiply(axis, 0.25)
        vector_delta = vector3_distance(impulse, vector_expected)
        require(
            math.isclose(vector_delta, expected["vector3_delta"], rel_tol=0.0, abs_tol=1e-22),
            f"PUSH_VECTOR_DELTA:{cell_id}",
        )
        if "vector3_expected" in expected:
            require(
                exact_equal(vector_expected, expected["vector3_expected"]),
                f"PUSH_VECTOR_EXPECTED:{cell_id}",
            )
        evaluation = cell.get("evaluation")
        require(isinstance(evaluation, dict), f"PUSH_EVALUATION_TYPE:{cell_id}")
        require(
            evaluation.get("failure_code") == expected["evaluation_code"],
            f"PUSH_EVALUATION_CODE:{cell_id}",
        )
        predicates = current_application_predicates(cell, row)
        require(len(predicates) == 15, f"PUSH_PREDICATE_COUNT:{cell_id}")
        false_names = {name for name, passed in predicates.items() if not passed}
        if cell_id == "push_s40102":
            require(
                false_names == {"world_impulse_link"},
                "REJECTED_SINGLE_PREDICATE_IDENTITY",
            )
            require(cell.get("evidence_valid") is False, "REJECTED_EVIDENCE_VALID")
            require(cell.get("outcome_complete") is False, "REJECTED_OUTCOME_COMPLETE")
            require(cell.get("world_build_count") == 1, "REJECTED_WORLD_COUNT")
            require(
                dotted(cell, "runtime_summary_projection.executed_ticks") == 2979,
                "REJECTED_EXECUTED_TICKS",
            )
            require(
                dotted(cell, "sdk_physical_trace.row_count") == 2739,
                "REJECTED_TRACE_COUNT",
            )
        else:
            require(not false_names, f"ADMITTED_APPLICATION_PREDICATE:{cell_id}")
        recorded = design_by_cell[cell_id]
        require(
            exact_equal(recorded["marker_task_lateral_axis_world_unit"], axis),
            f"DESIGN_AXIS:{cell_id}",
        )
        require(
            exact_equal(recorded["receipt_impulse_world_n_s"], impulse),
            f"DESIGN_IMPULSE:{cell_id}",
        )
        require(
            math.isclose(
                recorded["exported_scalar_difference_magnitude_n_s"],
                scalar_delta,
                rel_tol=0.0,
                abs_tol=1e-22,
            ),
            f"DESIGN_SCALAR_DELTA:{cell_id}",
        )
        require(
            math.isclose(
                recorded["current_vector3_rematerialized_difference_magnitude_n_s"],
                vector_delta,
                rel_tol=0.0,
                abs_tol=1e-22,
            ),
            f"DESIGN_VECTOR_DELTA:{cell_id}",
        )
        require(
            recorded["current_predicate_passed"] is (not false_names),
            f"DESIGN_PREDICATE_OUTCOME:{cell_id}",
        )
        predicate_total += len(predicates)
    return cells, predicate_total


def comparable_prefix(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    prefix: list[dict[str, Any]] = []
    for row in rows:
        step = row.get("semantic_step")
        if type(step) is int and 0 <= step < 900:
            normalized = copy.deepcopy(row)
            normalized.pop("cell_id", None)
            prefix.append(normalized)
    return prefix


def validate_pre_marker_identity(
    design: dict[str, Any],
    development_closure: dict[str, Any],
    held_closure: dict[str, Any],
    rejected_cell: dict[str, Any],
) -> int:
    dev_root = Path(dotted(development_closure, "evidence.retained_evidence_tree.root"))
    held_root = Path(dotted(held_closure, "evidence.retained_evidence_tree.root"))
    pairs = {
        40001: (
            load_completed_cell(dev_root / "baseline_s40001/cell.json"),
            load_completed_cell(dev_root / "push_s40001/cell.json"),
        ),
        40101: (
            load_completed_cell(held_root / "baseline_s40101/cell.json"),
            load_completed_cell(held_root / "push_s40101/cell.json"),
        ),
        40102: (
            load_completed_cell(held_root / "baseline_s40102/cell.json"),
            rejected_cell,
        ),
    }
    recorded = dotted(
        design,
        "walking_diagnosis.same_seed_pre_push_prefix.different_row_count_by_pair",
    )
    compared_rows = 0
    for seed, (baseline, push) in pairs.items():
        left = comparable_prefix(trace_rows(baseline, f"baseline_{seed}"))
        right = comparable_prefix(trace_rows(push, f"push_{seed}"))
        require(len(left) == 900 and len(right) == 900, f"PREFIX_COUNT:{seed}")
        differences = sum(a != b for a, b in zip(left, right))
        require(differences == 0, f"PREFIX_DIFFERENCE:{seed}")
        require(recorded.get(str(seed)) == differences, f"PREFIX_RECORDED:{seed}")
        compared_rows += len(left)
    return compared_rows


def validate_r10d_walking_failures(
    design: dict[str, Any],
    development_closure: dict[str, Any],
    held_closure: dict[str, Any],
) -> int:
    paths: list[Path] = []
    for closure in (development_closure, held_closure):
        for entry in dotted(closure, "evidence.cells"):
            path = Path(entry["path"])
            require(path.is_file(), f"ADMITTED_CELL_MISSING:{path}")
            require(sha256_bytes(path.read_bytes()) == entry["raw_sha256"], "ADMITTED_CELL_SHA")
            paths.append(path)
    require(len(paths) == 5, "ADMITTED_CELL_COUNT")
    expected_ids = set(dotted(design, "walking_diagnosis.admitted_r10d_cells"))
    observed_ids: set[str] = set()
    receipt_count = 0
    for path in paths:
        cell = load_completed_cell(path)
        cell_id = cell.get("cell_id")
        require(isinstance(cell_id, str), "ADMITTED_CELL_ID_TYPE")
        observed_ids.add(cell_id)
        require(cell.get("behavior_passed") is False, f"ADMITTED_BEHAVIOR:{cell_id}")
        require(cell.get("evidence_valid") is True, f"ADMITTED_EVIDENCE:{cell_id}")
        require(cell.get("outcome_complete") is True, f"ADMITTED_OUTCOME:{cell_id}")
        receipts = dotted(cell, "evaluation.walking_gate_receipts")
        require(isinstance(receipts, dict), f"ADMITTED_RECEIPT_TYPE:{cell_id}")
        require(set(receipts) == EXPECTED_WALKING_RECEIPTS, f"ADMITTED_RECEIPT_KEYS:{cell_id}")
        false_receipts = {key for key, value in receipts.items() if value is False}
        require(false_receipts == {"bounded_anchor_error"}, f"ADMITTED_FALSE_SET:{cell_id}")
        require(all(type(value) is bool for value in receipts.values()), "ADMITTED_RECEIPT_BOOL")
        receipt_count += len(receipts)
    require(observed_ids == expected_ids, "ADMITTED_CELL_SET")
    require(
        dotted(design, "walking_diagnosis.ordinary_walking_pass_count") == 0,
        "DESIGN_WALKING_PASS_COUNT",
    )
    require(
        dotted(design, "walking_diagnosis.only_false_walking_receipt_in_every_admitted_cell")
        == "bounded_anchor_error",
        "DESIGN_WALKING_FALSE_IDENTITY",
    )
    return receipt_count


def validate_r05e_population(
    design: dict[str, Any], report: dict[str, Any]
) -> tuple[int, int, list[dict[str, Any]]]:
    require(
        report.get("campaign_id") == "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION",
        "R05E_CAMPAIGN",
    )
    require(report.get("observed_world_count") == 36, "R05E_WORLD_COUNT")
    require(report.get("walking_pass_count") == 36, "R05E_WALKING_COUNT")
    require(report.get("failure_count") == 0, "R05E_FAILURE_COUNT")
    require(report.get("external_push_recovery") is False, "R05E_PUSH_SCOPE")
    results = report.get("results")
    require(isinstance(results, list) and len(results) == 36, "R05E_RESULTS")
    grouped: dict[int, list[dict[str, Any]]] = {}
    receipt_count = 0
    for result in results:
        require(isinstance(result, dict), "R05E_RESULT_TYPE")
        index = result.get("generator_index")
        seed = result.get("campaign_seed")
        require(type(index) is int and type(seed) is int, "R05E_INDEX_SEED_TYPE")
        require(seed in (40101, 40102, 40103), f"R05E_SEED:{seed}")
        require(result.get("walking_observed") is True, f"R05E_WALKING:{index}:{seed}")
        require(result.get("harness_passed") is True, f"R05E_HARNESS:{index}:{seed}")
        receipt = result.get("receipt")
        require(isinstance(receipt, dict), f"R05E_RECEIPT:{index}:{seed}")
        walking = receipt.get("walking_gate_receipts")
        require(isinstance(walking, dict), f"R05E_WALKING_RECEIPTS:{index}:{seed}")
        require(set(walking) == EXPECTED_WALKING_RECEIPTS, f"R05E_RECEIPT_KEYS:{index}:{seed}")
        require(all(value is True for value in walking.values()), f"R05E_FALSE_RECEIPT:{index}:{seed}")
        receipt_count += len(walking)
        grouped.setdefault(index, []).append(result)
    require(set(grouped) == set(range(217, 229)), "R05E_GENERATOR_SET")
    require(all(len(group) == 3 for group in grouped.values()), "R05E_GROUP_COUNTS")

    ranking: list[dict[str, Any]] = []
    for index, group in grouped.items():
        worst = max(float(item["receipt"]["maximum_anchor_error_m"]) for item in group)
        ranking.append(
            {
                "generator_index": index,
                "morphology_id": group[0]["morphology_id"],
                "worst_maximum_anchor_error_m": worst,
            }
        )
    ranking.sort(key=lambda row: (row["worst_maximum_anchor_error_m"], row["generator_index"]))
    require(ranking[0]["generator_index"] == 217, "R05E_OVERALL_BEST")
    unopened_ranking = [row for row in ranking if row["generator_index"] != 217]
    require(unopened_ranking[0]["generator_index"] == 225, "R05E_UNOPENED_BEST")
    require(
        ranking[0]["worst_maximum_anchor_error_m"] == 0.018256276845932007,
        "R05E_217_WORST",
    )
    require(
        unopened_ranking[0]["worst_maximum_anchor_error_m"] == 0.018479883670806885,
        "R05E_225_WORST",
    )

    selected = grouped[225]
    selected_by_seed = {item["campaign_seed"]: item for item in selected}
    require(set(selected_by_seed) == set(EXPECTED_R05E_SELECTED_RESULTS), "R05E_225_SEEDS")
    for seed, expected in EXPECTED_R05E_SELECTED_RESULTS.items():
        result = selected_by_seed[seed]
        receipt = result["receipt"]
        require(
            result.get("morphology_id") == "qsdk_r05e_axis_star_foot_radius_low_s225",
            f"R05E_225_MORPHOLOGY:{seed}",
        )
        require(
            receipt.get("generator_receipt_sha256")
            == "sha256:11c04da70cf613bc5b40a38568de3e45e3658a3f1cf46bfa35cac23ab2713686",
            f"R05E_225_GENERATOR_SHA:{seed}",
        )
        require(
            receipt.get("proportion_spec_sha256")
            == "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd",
            f"R05E_225_PROPORTION_SHA:{seed}",
        )
        for field, expected_value in expected.items():
            require(receipt.get(field) == expected_value, f"R05E_225_METRIC:{seed}:{field}")

    recorded_support = dotted(design, "selected_morphology.prior_exact_walking_support")
    require(isinstance(recorded_support, list) and len(recorded_support) == 3, "DESIGN_SUPPORT_ROWS")
    for row in recorded_support:
        seed = row.get("campaign_seed")
        require(seed in EXPECTED_R05E_SELECTED_RESULTS, "DESIGN_SUPPORT_SEED")
        for field, expected_value in EXPECTED_R05E_SELECTED_RESULTS[seed].items():
            require(row.get(field) == expected_value, f"DESIGN_SUPPORT_METRIC:{seed}:{field}")
        require(row.get("walking_receipt_count") == 27, "DESIGN_SUPPORT_RECEIPT_COUNT")
        require(row.get("false_walking_receipt_count") == 0, "DESIGN_SUPPORT_FALSE_COUNT")
        require(row.get("walking_passed") is True, "DESIGN_SUPPORT_PASS")
    return len(results), receipt_count, ranking


def validate_source_diagnosis(
    design: dict[str, Any], raw_by_role: dict[str, bytes]
) -> int:
    evaluator = raw_by_role["r10d_world_evaluator_source"].decode("utf-8")
    walker = raw_by_role["r10d_live_walker_source"].decode("utf-8")
    adapter = raw_by_role["r10d_task_frame_adapter_source"].decode("utf-8")
    required_evaluator_fragments = (
        "var expected_impulse_world := marker_lateral_axis * 0.25",
        "or (impulse_world - expected_impulse_world).length() > VECTOR_TOLERANCE",
        'return _failure("QSDK_R10D_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH")',
    )
    required_walker_fragments = (
        "var sdk_physical_trace_pending_row: Dictionary = {}",
        "_compose_sdk_physical_trace_row(",
        "(trace_row_result[\"row\"] as Dictionary).duplicate(true)",
        "complete_sdk_recovery_trace_observation(",
        "(completed_recovery_row[\"row\"] as Dictionary).duplicate(true)",
        "sdk_physical_trace_rows.append(sdk_physical_trace_pending_row)",
        "QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1",
    )
    required_adapter_fragments = (
        "_initial_lateral_axis_world = _initial_lateral_axis_world.normalized()",
        "_unit_vector_dictionary_binary64(_initial_lateral_axis_world)",
    )
    for fragment in required_evaluator_fragments:
        require(fragment in evaluator, f"EVALUATOR_FRAGMENT:{fragment}")
    for fragment in required_walker_fragments:
        require(fragment in walker, f"WALKER_FRAGMENT:{fragment}")
    for fragment in required_adapter_fragments:
        require(fragment in adapter, f"ADAPTER_FRAGMENT:{fragment}")

    changed_raw = git(
        (
            "diff",
            "--name-only",
            "2c47d8b05e3f46f1c752bc544937c0b69826069e",
            "e6db6c23b5bff1b48fc6204fc9db82ffbb252344",
            "--",
            "scripts/lab/gait",
        )
    )
    require(isinstance(changed_raw, str), "SOURCE_DIFF_TYPE")
    changed = {line.replace("\\", "/") for line in changed_raw.splitlines() if line}
    require(
        changed
        == {
            "scripts/lab/gait/physical_wave_gait_quadruped.gd",
            "scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd",
            "scripts/lab/gait/qsdk_r10d_supported_start_phase_robust_push_recovery.gd",
        },
        "SOURCE_DIFF_SET",
    )
    observation = dotted(design, "walking_diagnosis.source_change_observation")
    require(observation.get("core_live_walker_file_changed") is True, "DESIGN_WALKER_CHANGED")
    require(observation.get("adapter_file_changed") is False, "DESIGN_ADAPTER_UNCHANGED")
    require(
        observation.get("walker_change_added_recovery_trace_infrastructure") is True,
        "DESIGN_TRACE_CHANGE",
    )
    require(
        dotted(design, "walking_diagnosis.causal_classification")
        == "measurement_observer_timing_or_allocation_is_a_strong_engineering_hypothesis_not_an_established_single_cause",
        "DESIGN_CAUSAL_LIMIT",
    )
    return len(required_evaluator_fragments) + len(required_walker_fragments) + len(
        required_adapter_fragments
    )


def validate_design_contract(design: dict[str, Any]) -> None:
    require(set(design) == EXPECTED_TOP_LEVEL, "DESIGN_TOP_LEVEL")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1",
        "DESIGN_SCHEMA",
    )
    require(
        design.get("status")
        == "prospective_zero_world_successor_design_complete_physics_blocked",
        "DESIGN_STATUS",
    )
    require(design.get("gate_id") == "QSDK-R10E", "DESIGN_GATE")
    require(design.get("parent_gate_id") == "QSDK-R10", "DESIGN_PARENT_GATE")
    require(
        design.get("authored_parent_commit")
        == "55ef1e2c8e50cba0941714c55781d45fb4d04eda",
        "DESIGN_PARENT_COMMIT",
    )
    require(
        exact_equal(
            design.get("ledger_scope"),
            {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "retained_evidence_diagnosis_and_prospective_successor_design",
                "question_class": "development",
            },
        ),
        "DESIGN_LEDGER_SCOPE",
    )
    question = design.get("question_declaration")
    require(isinstance(question, dict), "DESIGN_QUESTION_TYPE")
    for field in (
        "physical_question_declared",
        "finite_decision_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
        "physical_work_authorized",
    ):
        require(question.get(field) is False, f"DESIGN_QUESTION_FALSE:{field}")
    require(question.get("maximum_world_attempt_count_before_complete_new_authority_graph") == 0, "DESIGN_PREGRAPH_ATTEMPTS")
    require(question.get("maximum_world_build_count_before_complete_new_authority_graph") == 0, "DESIGN_PREGRAPH_WORLDS")

    release = design.get("release_milestone_context")
    require(isinstance(release, dict), "DESIGN_RELEASE_TYPE")
    require(release.get("sdk1_milestone_id") == "SDK1-M07", "DESIGN_MILESTONE")
    require(release.get("source_gate_id") == "QSDK-R10", "DESIGN_MILESTONE_GATE")
    require(release.get("score_before_design") == "14/20", "DESIGN_SDK_SCORE")
    require(release.get("full_program_score_before_design") == "14/25", "DESIGN_FULL_SCORE")
    require(release.get("this_design_advances_m07") is False, "DESIGN_NO_M07_ADVANCE")

    consumed = design.get("consumed_predecessor_results")
    require(isinstance(consumed, dict), "DESIGN_CONSUMED_TYPE")
    require(
        dotted(consumed, "development_route.classification")
        == "valid_complete_behavior_finite_negative",
        "DESIGN_DEV_CLASSIFICATION",
    )
    require(dotted(consumed, "development_route.declared_world_count") == 2, "DESIGN_DEV_WORLDS")
    require(dotted(consumed, "development_route.confirmed_valid_world_count") == 2, "DESIGN_DEV_VALID_WORLDS")
    require(dotted(consumed, "development_route.ordinary_walking_pass_count") == 0, "DESIGN_DEV_WALKING")
    require(dotted(consumed, "development_route.same_identity_rerun_permitted") is False, "DESIGN_DEV_RERUN")
    require(
        dotted(consumed, "held_out_route.classification")
        == "invalid_or_incomplete_no_behavioral_conclusion",
        "DESIGN_HELD_CLASSIFICATION",
    )
    require(dotted(consumed, "held_out_route.attempted_cell_count") == 4, "DESIGN_HELD_ATTEMPTS")
    require(dotted(consumed, "held_out_route.confirmed_valid_world_count") == 3, "DESIGN_HELD_VALID")
    require(dotted(consumed, "held_out_route.behavior_passed") is None, "DESIGN_HELD_BEHAVIOR")
    require(dotted(consumed, "held_out_route.same_identity_rerun_permitted") is False, "DESIGN_HELD_RERUN")
    require(consumed.get("historical_result_reclassification_permitted") is False, "DESIGN_NO_RECLASSIFY")
    require(consumed.get("historical_threshold_change_permitted") is False, "DESIGN_NO_RETHRESHOLD")
    require(consumed.get("historical_cell_replacement_permitted") is False, "DESIGN_NO_REPLACE")

    execution = design.get("retained_execution_diagnosis")
    require(isinstance(execution, dict), "DESIGN_EXECUTION_TYPE")
    require(execution.get("completed_rejected_cell_id") == "push_s40102", "DESIGN_REJECTED_CELL")
    require(execution.get("terminal_marker_present_and_json_complete") is True, "DESIGN_COMPLETE_MARKER")
    require(execution.get("terminal_marker_character_count") == 6_813_227, "DESIGN_MARKER_LENGTH")
    require(execution.get("reported_executed_ticks") == 2979, "DESIGN_EXECUTED_TICKS")
    require(execution.get("reported_sdk_trace_row_count") == 2739, "DESIGN_TRACE_ROWS")
    require(execution.get("reported_world_build_count") == 1, "DESIGN_REJECTED_WORLD")
    require(execution.get("process_timed_out_claimed") is False, "DESIGN_TIMEOUT_CLAIM")
    require(execution.get("worker_completed_claimed") is True, "DESIGN_WORKER_COMPLETE")
    require(
        execution.get("terminal_evaluator_failure_code")
        == "QSDK_R10D_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH",
        "DESIGN_TERMINAL_FAILURE",
    )
    require(execution.get("held_out_closure_must_remain_invalid_or_incomplete") is True, "DESIGN_HELD_PRESERVE")

    receipt = design.get("receipt_representation_diagnosis")
    require(isinstance(receipt, dict), "DESIGN_RECEIPT_TYPE")
    require(receipt.get("current_vector_tolerance") == 1e-12, "DESIGN_CURRENT_VECTOR_TOLERANCE")
    require(receipt.get("predicate_count_in_application_receipt") == 15, "DESIGN_PREDICATE_COUNT")
    require(receipt.get("other_predicate_pass_count_for_push_s40102") == 14, "DESIGN_OTHER_PREDICATES")
    require(
        receipt.get("only_rejecting_predicate")
        == "world_impulse_matches_rematerialized_binary64_renormalized_marker_axis",
        "DESIGN_REJECTING_PREDICATE",
    )
    require(receipt.get("behavior_reclassification_authority") is False, "DESIGN_RECEIPT_NO_AUTHORITY")

    walking = design.get("walking_diagnosis")
    require(isinstance(walking, dict), "DESIGN_WALKING_TYPE")
    require(walking.get("admitted_r10d_cell_count") == 5, "DESIGN_ADMITTED_COUNT")
    require(walking.get("ordinary_walking_pass_count") == 0, "DESIGN_R10D_WALKING_COUNT")
    require(walking.get("walking_receipt_count_per_cell") == 27, "DESIGN_WALKING_RECEIPT_COUNT")
    require(walking.get("push_caused_anchor_failure_claimed") is False, "DESIGN_NO_PUSH_CAUSE")
    require(walking.get("controller_failure_claimed") is False, "DESIGN_NO_CONTROLLER_CAUSE")
    require(walking.get("solver_defect_claimed") is False, "DESIGN_NO_SOLVER_CAUSE")

    selection = design.get("selected_morphology")
    require(isinstance(selection, dict), "DESIGN_SELECTION_TYPE")
    require(selection.get("selection_authority") == "outcome_exposed_development_design_only", "DESIGN_SELECTION_AUTHORITY")
    require(selection.get("selection_uses_r05e_walking_outcomes") is True, "DESIGN_SELECTION_DISCLOSURE")
    require(selection.get("selection_uses_any_generator_225_push_or_recovery_outcome") is False, "DESIGN_SELECTION_NO_PUSH")
    require(selection.get("selection_is_claimed_unbiased_for_the_new_walking_component") is False, "DESIGN_SELECTION_NO_UNBIASED")
    require(selection.get("selection_is_claimed_optimal_for_recovery") is False, "DESIGN_SELECTION_NO_OPTIMAL")
    require(selection.get("selected_generator_index") == 225, "DESIGN_SELECTED_GENERATOR")
    require(selection.get("selected_morphology_id") == EXPECTED_SELECTED_DESCRIPTOR["morphology_id"], "DESIGN_SELECTED_MORPHOLOGY")
    require(exact_equal(selection.get("exact_proportion_spec"), EXPECTED_SELECTED_DESCRIPTOR), "DESIGN_DESCRIPTOR")
    require(selection.get("generator_217_historical_best_overall_preserved") is True, "DESIGN_217_BEST")
    require(selection.get("selected_generator_is_best_unopened_by_declared_rule") is True, "DESIGN_225_BEST_UNOPENED")

    scope = design.get("selected_successor_scope")
    require(isinstance(scope, dict), "DESIGN_SCOPE_TYPE")
    for field in (
        "controller_change_selected",
        "recovery_controller_added",
        "force_estimator_added",
        "force_aware_recovery_added",
        "active_mode_switch_added",
        "ordinary_walking_gate_change_selected",
        "material_change_selected",
        "solver_change_selected",
        "host_mapping_change_selected",
        "push_magnitude_or_direction_change_selected",
        "challenge_timing_or_window_change_selected",
    ):
        require(scope.get(field) is False, f"DESIGN_SCOPE_FALSE:{field}")
    require(scope.get("measurement_trace_capture_implementation_forward_versioned") is True, "DESIGN_TRACE_VERSION")
    require(scope.get("push_receipt_schema_and_validator_forward_versioned") is True, "DESIGN_RECEIPT_VERSION")
    require(scope.get("supported_exact_morphology_changed_from_r10d") is True, "DESIGN_MORPHOLOGY_CHANGE")

    population = design.get("prospective_population")
    require(isinstance(population, dict), "DESIGN_POPULATION_TYPE")
    require(dotted(population, "development_route_ghost.campaign_seed") == 40002, "DESIGN_DEV_SEED")
    require(dotted(population, "development_route_ghost.generator_index") == 225, "DESIGN_DEV_GENERATOR")
    require(dotted(population, "development_route_ghost.world_count") == 2, "DESIGN_DEV_POPULATION")
    require(dotted(population, "held_out_finite_decision.campaign_seeds") == [40101, 40102, 40103], "DESIGN_HELD_SEEDS")
    require(dotted(population, "held_out_finite_decision.generator_index") == 225, "DESIGN_HELD_GENERATOR")
    require(dotted(population, "held_out_finite_decision.world_count") == 6, "DESIGN_HELD_POPULATION")
    require(dotted(population, "held_out_finite_decision.r10_push_or_recovery_outcome_known") is False, "DESIGN_HELD_UNOPENED")
    require(population.get("maximum_total_future_physical_world_count") == 8, "DESIGN_MAX_FUTURE_WORLDS")
    require(population.get("r10e_outcomes_currently_unobserved") is True, "DESIGN_R10E_UNOBSERVED")

    trace = design.get("trace_capture_contract")
    require(isinstance(trace, dict), "DESIGN_TRACE_TYPE")
    require(trace.get("trace_required_for_every_executed_sdk_step") is True, "DESIGN_TRACE_COMPLETE")
    require(trace.get("trace_field_semantics_identical_to_r10d") is True, "DESIGN_TRACE_SEMANTICS")
    require(dotted(trace, "live_solver_interval.per_step_rich_nested_row_dictionary_materialization_permitted") is False, "DESIGN_NO_LIVE_ROWS")
    require(dotted(trace, "live_solver_interval.per_step_deep_duplicate_of_trace_row_permitted") is False, "DESIGN_NO_LIVE_DUPLICATE")
    require(dotted(trace, "live_solver_interval.per_step_json_encoding_or_hashing_permitted") is False, "DESIGN_NO_LIVE_JSON")
    require(dotted(trace, "live_solver_interval.per_step_quaternion_projection_receipt_materialization_permitted") is False, "DESIGN_NO_LIVE_PROJECTION")
    require(dotted(trace, "live_solver_interval.raw_primitive_capture_only") is True, "DESIGN_RAW_CAPTURE")
    require(dotted(trace, "live_solver_interval.capture_buffer_preallocation_required") is True, "DESIGN_PREALLOCATE")
    require(dotted(trace, "live_solver_interval.controller_input_or_output_may_change") is False, "DESIGN_TRACE_NO_CONTROLLER")
    require(dotted(trace, "live_solver_interval.physics_state_may_change") is False, "DESIGN_TRACE_NO_PHYSICS")
    require(dotted(trace, "after_final_solver_step.allow_additional_solver_step_during_materialization") is False, "DESIGN_NO_EXTRA_SOLVER")
    require(dotted(trace, "after_final_solver_step.allow_downsampling") is False, "DESIGN_NO_DOWNSAMPLING")
    require(dotted(trace, "after_final_solver_step.allow_missing_measurement") is False, "DESIGN_NO_MISSING_MEASUREMENT")

    scalar = design.get("scalar_receipt_contract")
    require(isinstance(scalar, dict), "DESIGN_SCALAR_TYPE")
    require(scalar.get("validate_exported_scalars_without_vector3_rematerialization") is True, "DESIGN_SCALAR_NO_VECTOR3")
    require(dotted(scalar, "raw_host_axis_to_world_impulse_link.binary64_transport_comparison_formula") == "32 * 2^-52 * max(1.0, abs(actual), abs(recomputed_expected))", "DESIGN_BINARY64_FORMULA")
    require(dotted(scalar, "raw_host_axis_to_world_impulse_link.binary64_transport_comparison_is_behavior_threshold") is False, "DESIGN_BINARY64_NOT_THRESHOLD")
    require(dotted(scalar, "host_real_unit_axis_validation.unit_norm_allowance") == 1.9073486328125e-6, "DESIGN_AXIS_ALLOWANCE")
    require(dotted(scalar, "host_real_unit_axis_validation.observed_r10d_outcome_used_to_select_allowance") is False, "DESIGN_AXIS_ALLOWANCE_PROVENANCE")
    require(dotted(scalar, "world_impulse_magnitude_validation.expected_magnitude_n_s") == 0.25, "DESIGN_WORLD_IMPULSE")
    require(dotted(scalar, "world_impulse_magnitude_validation.absolute_allowance_n_s") == 4.76837158203125e-7, "DESIGN_IMPULSE_ALLOWANCE")
    require(dotted(scalar, "world_impulse_magnitude_validation.observed_r10d_outcome_used_to_select_allowance") is False, "DESIGN_IMPULSE_ALLOWANCE_PROVENANCE")
    require(dotted(scalar, "world_impulse_magnitude_validation.challenge_magnitude_changed") is False, "DESIGN_NO_MAGNITUDE_CHANGE")
    require(scalar.get("native_effect_floor_m_s") == 0.0001, "DESIGN_EFFECT_FLOOR")
    require(scalar.get("native_effect_floor_changed") is False, "DESIGN_EFFECT_UNCHANGED")

    behavior = design.get("preserved_behavior_contract")
    require(isinstance(behavior, dict), "DESIGN_BEHAVIOR_TYPE")
    require(behavior.get("impulse_task_n_s") == [0.0, 0.0, 0.25], "DESIGN_TASK_IMPULSE")
    require(behavior.get("application_semantic_step_from_sdk_start") == 900, "DESIGN_MARKER_STEP")
    require(behavior.get("pre_push_window_half_open") == [180, 900], "DESIGN_PRE_WINDOW")
    require(behavior.get("matched_baseline_post_marker_window_half_open") == [901, 1621], "DESIGN_POST_WINDOW")
    require(behavior.get("last_recovery_candidate_step") == 1260, "DESIGN_RECOVERY_DEADLINE")
    require(behavior.get("window_duration_steps") == 720, "DESIGN_WINDOW_DURATION")
    require(behavior.get("minimum_task_frame_forward_advance_m") == 0.02, "DESIGN_FORWARD_FLOOR")
    require(behavior.get("ordinary_walking_receipt_count") == 27, "DESIGN_ORDINARY_RECEIPTS")
    require(behavior.get("bounded_anchor_error_receipt_removed_or_relaxed") is False, "DESIGN_ANCHOR_UNCHANGED")
    require(behavior.get("native_effect_floor_m_s") == 0.0001, "DESIGN_BEHAVIOR_EFFECT_FLOOR")
    require(behavior.get("forced_fall_required") is False, "DESIGN_NO_FORCED_FALL")

    decision_contract = design.get("decision_contract")
    require(isinstance(decision_contract, dict), "DESIGN_DECISION_CONTRACT_TYPE")
    require(decision_contract.get("development_behavioral_success_required") is False, "DESIGN_DEV_ROUTE_SEMANTICS")
    require(decision_contract.get("pooling_across_seeds_permitted") is False, "DESIGN_NO_POOLING")
    require(decision_contract.get("same_identity_rerun_permitted") is False, "DESIGN_NO_RERUN")
    require(decision_contract.get("post_result_threshold_or_interpretation_change_permitted") is False, "DESIGN_NO_POST_CHANGE")

    counters = design.get("required_zero_world_controls")
    require(isinstance(counters, dict), "DESIGN_CONTROLS_TYPE")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(counters.get(field) == 0, f"DESIGN_COUNTER:{field}")
    require(counters.get("physical_acceptance_authority") is False, "DESIGN_NO_PHYSICAL_AUTHORITY")
    require(counters.get("release_authority") is False, "DESIGN_NO_RELEASE_AUTHORITY")

    sequence = design.get("forward_authority_sequence")
    require(isinstance(sequence, dict), "DESIGN_SEQUENCE_TYPE")
    require(sequence.get("maximum_development_route_ghost_campaign_attempt_count") == 1, "DESIGN_ROUTE_ATTEMPTS")
    require(sequence.get("maximum_development_route_ghost_world_count") == 2, "DESIGN_ROUTE_WORLDS")
    require(sequence.get("held_out_cells_remain_sealed") is True, "DESIGN_HELD_SEALED")
    require(sequence.get("physical_execution_blocked_until_sequence_complete") is True, "DESIGN_PHYSICS_BLOCKED")

    limits = design.get("immutability_and_limits")
    require(isinstance(limits, dict), "DESIGN_LIMITS_TYPE")
    for field in (
        "r05e_rerun_count",
        "r10b_rerun_count",
        "r10d_rerun_count",
        "new_physical_process_launch_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(limits.get(field) == 0, f"DESIGN_LIMIT:{field}")
    require(limits.get("r10e_push_or_recovery_outcome_exposed") is False, "DESIGN_R10E_NOT_EXPOSED")
    require(limits.get("controller_or_behavior_threshold_mutation") is False, "DESIGN_NO_BEHAVIOR_MUTATION")
    require(limits.get("historical_result_reinterpretation") is False, "DESIGN_NO_HISTORY_REINTERPRETATION")
    require(limits.get("outcome_derived_threshold_correction") is False, "DESIGN_NO_OUTCOME_THRESHOLD")

    claims = design.get("claim_boundary")
    require(isinstance(claims, dict), "DESIGN_CLAIMS_TYPE")
    for field in (
        "r10e_bounded_upright_push_recovery",
        "external_push_recovery",
        "physical_balance_recovery",
        "fall_recovery",
        "prone_to_standing",
        "self_righting",
        "force_aware_recovery",
        "arbitrary_push_direction_or_magnitude",
        "push_recovery_across_r05e_axis_star_morphologies",
        "push_recovery_in_rapier_or_mujoco",
        "cross_engine_effect_equivalence",
        "population_success_rate",
        "sdk1_m07_advanced",
        "q_sdk_r10_advanced",
        "release_authorized",
        "physical_acceptance_authority",
    ):
        require(claims.get(field) is False, f"DESIGN_CLAIM_FALSE:{field}")
    require(claims.get("design_complete") is True, "DESIGN_COMPLETE")
    require(claims.get("retained_diagnosis_complete") is True, "DESIGN_DIAGNOSIS_COMPLETE")
    require(claims.get("r10d_development_finite_negative_preserved") is True, "DESIGN_DEV_PRESERVED")
    require(claims.get("r10d_held_out_invalid_or_incomplete_preserved") is True, "DESIGN_HELD_PRESERVED")
    require(claims.get("r10d_walking_single_cause_claimed") is False, "DESIGN_NO_SINGLE_CAUSE")

    decision = design.get("decision")
    require(isinstance(decision, dict), "DESIGN_DECISION_TYPE")
    require(decision.get("q_sdk_r10e_zero_world_implementation_authorized") is True, "DESIGN_IMPLEMENTATION_AUTHORIZED")
    require(decision.get("q_sdk_r10e_physical_execution_authorized") is False, "DESIGN_PHYSICAL_NOT_AUTHORIZED")
    require(decision.get("sdk1_m07_satisfied") is False, "DESIGN_M07_FALSE")
    require(decision.get("scores_unchanged") is True, "DESIGN_SCORES_UNCHANGED")


def set_dotted(target: dict[str, Any], path: str, value: Any) -> None:
    parts = path.split(".")
    current: Any = target
    for part in parts[:-1]:
        require(isinstance(current, dict) and part in current, f"MUTATION_PATH:{path}")
        current = current[part]
    require(isinstance(current, dict) and parts[-1] in current, f"MUTATION_LEAF:{path}")
    current[parts[-1]] = value


def validate_mutation_refusals(design: dict[str, Any]) -> int:
    mutations = (
        ("status", "physical_positive"),
        ("gate_id", "QSDK-R10"),
        ("parent_gate_id", "QSDK-R10E"),
        ("authored_parent_commit", "0" * 40),
        ("ledger_scope.subsystem", "walking"),
        ("ledger_scope.engine_scope", "three_engine"),
        ("ledger_scope.authority_mode", "physical"),
        ("ledger_scope.question_class", "finite decision"),
        ("question_declaration.physical_work_authorized", True),
        ("question_declaration.maximum_world_attempt_count_before_complete_new_authority_graph", 1),
        ("release_milestone_context.score_before_design", "15/20"),
        ("release_milestone_context.this_design_advances_m07", True),
        ("consumed_predecessor_results.development_route.classification", "positive"),
        ("consumed_predecessor_results.development_route.same_identity_rerun_permitted", True),
        ("consumed_predecessor_results.held_out_route.classification", "finite_negative"),
        ("consumed_predecessor_results.held_out_route.behavior_passed", False),
        ("consumed_predecessor_results.historical_result_reclassification_permitted", True),
        ("retained_execution_diagnosis.terminal_marker_present_and_json_complete", False),
        ("retained_execution_diagnosis.reported_world_build_count", 0),
        ("retained_execution_diagnosis.process_timed_out_claimed", True),
        ("retained_execution_diagnosis.held_out_closure_must_remain_invalid_or_incomplete", False),
        ("receipt_representation_diagnosis.current_vector_tolerance", 1e-6),
        ("receipt_representation_diagnosis.predicate_count_in_application_receipt", 14),
        ("receipt_representation_diagnosis.behavior_reclassification_authority", True),
        ("walking_diagnosis.ordinary_walking_pass_count", 5),
        ("walking_diagnosis.push_caused_anchor_failure_claimed", True),
        ("walking_diagnosis.controller_failure_claimed", True),
        ("walking_diagnosis.solver_defect_claimed", True),
        ("selected_morphology.selection_uses_any_generator_225_push_or_recovery_outcome", True),
        ("selected_morphology.selection_is_claimed_unbiased_for_the_new_walking_component", True),
        ("selected_morphology.selection_is_claimed_optimal_for_recovery", True),
        ("selected_morphology.selected_generator_index", 217),
        ("selected_morphology.generator_217_historical_best_overall_preserved", False),
        ("selected_successor_scope.controller_change_selected", True),
        ("selected_successor_scope.force_aware_recovery_added", True),
        ("selected_successor_scope.push_magnitude_or_direction_change_selected", True),
        ("selected_successor_scope.challenge_timing_or_window_change_selected", True),
        ("prospective_population.development_route_ghost.campaign_seed", 40001),
        ("prospective_population.held_out_finite_decision.campaign_seeds", [40103, 40102, 40101]),
        ("prospective_population.held_out_finite_decision.r10_push_or_recovery_outcome_known", True),
        ("trace_capture_contract.live_solver_interval.per_step_rich_nested_row_dictionary_materialization_permitted", True),
        ("trace_capture_contract.live_solver_interval.per_step_deep_duplicate_of_trace_row_permitted", True),
        ("trace_capture_contract.live_solver_interval.raw_primitive_capture_only", False),
        ("trace_capture_contract.live_solver_interval.controller_input_or_output_may_change", True),
        ("trace_capture_contract.after_final_solver_step.allow_additional_solver_step_during_materialization", True),
        ("trace_capture_contract.after_final_solver_step.allow_downsampling", True),
        ("scalar_receipt_contract.validate_exported_scalars_without_vector3_rematerialization", False),
        ("scalar_receipt_contract.host_real_unit_axis_validation.unit_norm_allowance", 1e-3),
        ("scalar_receipt_contract.host_real_unit_axis_validation.observed_r10d_outcome_used_to_select_allowance", True),
        ("scalar_receipt_contract.world_impulse_magnitude_validation.expected_magnitude_n_s", 0.2),
        ("scalar_receipt_contract.world_impulse_magnitude_validation.absolute_allowance_n_s", 1e-3),
        ("scalar_receipt_contract.world_impulse_magnitude_validation.challenge_magnitude_changed", True),
        ("scalar_receipt_contract.native_effect_floor_m_s", 0.0),
        ("preserved_behavior_contract.impulse_task_n_s", [0.0, 0.0, 0.2]),
        ("preserved_behavior_contract.application_semantic_step_from_sdk_start", 901),
        ("preserved_behavior_contract.pre_push_window_half_open", [181, 900]),
        ("preserved_behavior_contract.window_duration_steps", 360),
        ("preserved_behavior_contract.minimum_task_frame_forward_advance_m", 0.0),
        ("preserved_behavior_contract.bounded_anchor_error_receipt_removed_or_relaxed", True),
        ("preserved_behavior_contract.forced_fall_required", True),
        ("decision_contract.development_behavioral_success_required", True),
        ("decision_contract.pooling_across_seeds_permitted", True),
        ("decision_contract.same_identity_rerun_permitted", True),
        ("decision_contract.post_result_threshold_or_interpretation_change_permitted", True),
        ("required_zero_world_controls.world_attempt_count", 1),
        ("required_zero_world_controls.solver_step_count", 1),
        ("required_zero_world_controls.physical_acceptance_authority", True),
        ("forward_authority_sequence.maximum_development_route_ghost_world_count", 3),
        ("forward_authority_sequence.held_out_cells_remain_sealed", False),
        ("forward_authority_sequence.physical_execution_blocked_until_sequence_complete", False),
        ("immutability_and_limits.r10d_rerun_count", 1),
        ("immutability_and_limits.r10e_push_or_recovery_outcome_exposed", True),
        ("immutability_and_limits.outcome_derived_threshold_correction", True),
        ("claim_boundary.r10d_held_out_invalid_or_incomplete_preserved", False),
        ("claim_boundary.r10d_walking_single_cause_claimed", True),
        ("claim_boundary.external_push_recovery", True),
        ("claim_boundary.force_aware_recovery", True),
        ("claim_boundary.sdk1_m07_advanced", True),
        ("claim_boundary.release_authorized", True),
        ("decision.q_sdk_r10e_physical_execution_authorized", True),
        ("decision.sdk1_m07_satisfied", True),
        ("decision.scores_unchanged", False),
    )
    refused = 0
    for path, value in mutations:
        candidate = copy.deepcopy(design)
        set_dotted(candidate, path, value)
        try:
            validate_design_contract(candidate)
        except AuditFailure:
            refused += 1
        else:
            raise AuditFailure(f"MUTATION_NOT_REFUSED:{path}")
    return refused


def main() -> int:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "REPOSITORY_ROOT")
    require(git(("rev-parse", "--show-toplevel")) == ROOT.as_posix(), "GIT_TOPLEVEL")
    require(git(("remote", "get-url", "origin")) == EXPECTED_REMOTE, "GIT_REMOTE")
    require(
        git(("cat-file", "-t", "55ef1e2c8e50cba0941714c55781d45fb4d04eda"))
        == "commit",
        "AUTHORED_PARENT_COMMIT",
    )

    design_raw = DESIGN_PATH.read_bytes()
    require(len(design_raw) == EXPECTED_DESIGN_BYTES, "DESIGN_BYTES")
    require(sha256_bytes(design_raw) == EXPECTED_DESIGN_SHA256, "DESIGN_SHA256")
    design = read_json(design_raw, "DESIGN")
    validate_design_contract(design)
    _, raw_by_role = load_bound_authorities(design)

    development_closure = read_json(
        raw_by_role["consumed_r10d_l1_development_closure"], "DEVELOPMENT_CLOSURE"
    )
    held_closure = read_json(
        raw_by_role["consumed_r10d_l1_held_out_closure"], "HELD_CLOSURE"
    )
    development_tree = validate_retained_tree(development_closure, "DEVELOPMENT")
    held_tree = validate_retained_tree(held_closure, "HELD")
    require(development_tree["file_count"] == 13, "DEVELOPMENT_TREE_COUNT")
    require(development_tree["total_byte_length"] == 42_396_356, "DEVELOPMENT_TREE_BYTES")
    require(held_tree["file_count"] == 22, "HELD_TREE_COUNT")
    require(held_tree["total_byte_length"] == 75_434_026, "HELD_TREE_BYTES")

    held_report = read_json(raw_by_role["r10d_held_out_retained_report"], "HELD_REPORT")
    require(held_report.get("world_attempt_count") == 4, "HELD_REPORT_ATTEMPTS")
    require(held_report.get("world_build_count") is None, "HELD_REPORT_WORLD_UNKNOWN")
    require(held_report.get("world_build_count_known") is False, "HELD_REPORT_WORLD_KNOWN")
    require(held_report.get("confirmed_valid_world_build_count") == 3, "HELD_REPORT_VALID_WORLDS")
    require(held_report.get("expected_world_count") == 6, "HELD_REPORT_EXPECTED_WORLDS")
    require(held_report.get("pair_count") == 1, "HELD_REPORT_PAIRS")
    require(held_report.get("complete") is False, "HELD_REPORT_COMPLETE")
    require(held_report.get("evidence_valid") is False, "HELD_REPORT_EVIDENCE")
    require(held_report.get("outcome_complete") is False, "HELD_REPORT_OUTCOME")
    require(held_report.get("behavioral_conclusion_available") is False, "HELD_REPORT_CONCLUSION")
    require(held_report.get("behavior_passed") is None, "HELD_REPORT_BEHAVIOR")
    require(held_report.get("same_identity_rerun_permitted") is False, "HELD_REPORT_RERUN")
    failure = held_report.get("failure_record")
    require(isinstance(failure, dict), "HELD_REPORT_FAILURE_TYPE")
    require(failure.get("failure_stage") == "physical_cell_runtime_revalidation", "HELD_FAILURE_STAGE")
    require(failure.get("cell_id") == "push_s40102", "HELD_FAILURE_CELL")
    require(
        failure.get("message")
        == "Physical cell push_s40102 failed or timed out; identity is consumed",
        "HELD_FAILURE_MESSAGE",
    )

    cells, predicate_count = validate_push_diagnostics(
        design, development_closure, held_closure
    )
    compared_prefix_rows = validate_pre_marker_identity(
        design,
        development_closure,
        held_closure,
        cells["push_s40102"],
    )
    r10d_walking_receipts = validate_r10d_walking_failures(
        design, development_closure, held_closure
    )
    r05e_report = read_json(
        raw_by_role["r05e_retained_population_report"], "R05E_REPORT"
    )
    r05e_worlds, r05e_receipts, ranking = validate_r05e_population(
        design, r05e_report
    )
    source_marker_count = validate_source_diagnosis(design, raw_by_role)
    mutation_refusal_count = validate_mutation_refusals(design)

    result = {
        "schema_version": "sporespore_qsdk_r10e_observer_minimized_successor_design_audit_v1",
        "gate_id": "QSDK-R10E",
        "ok": True,
        "design_path": DESIGN_PATH.relative_to(ROOT).as_posix(),
        "design_byte_length": len(design_raw),
        "design_raw_sha256": sha256_bytes(design_raw),
        "bound_authority_count": len(EXPECTED_ROLES),
        "retained_evidence_file_count": (
            development_tree["file_count"] + held_tree["file_count"]
        ),
        "retained_evidence_total_byte_length": (
            development_tree["total_byte_length"]
            + held_tree["total_byte_length"]
        ),
        "completed_rejected_cell_reconstructed": True,
        "completed_rejected_cell_id": "push_s40102",
        "completed_rejected_cell_world_build_count": cells["push_s40102"][
            "world_build_count"
        ],
        "application_predicate_replay_count": predicate_count,
        "single_rejecting_application_predicate": "world_impulse_link",
        "same_seed_pre_marker_pair_count": 3,
        "same_seed_pre_marker_compared_row_count": compared_prefix_rows,
        "same_seed_pre_marker_different_row_count": 0,
        "admitted_r10d_walking_receipt_count": r10d_walking_receipts,
        "admitted_r10d_only_false_walking_receipt": "bounded_anchor_error",
        "r05e_world_count": r05e_worlds,
        "r05e_walking_receipt_count": r05e_receipts,
        "r05e_historical_best_generator_index": ranking[0]["generator_index"],
        "r05e_selected_unopened_generator_index": 225,
        "source_diagnosis_marker_count": source_marker_count,
        "design_mutation_refusal_count": mutation_refusal_count,
        "r10d_development_result_reclassified": False,
        "r10d_held_out_result_reclassified": False,
        "q_sdk_r10_satisfied": False,
        "sdk1_m07_satisfied": False,
        "sdk1_score": "14/20",
        "full_program_score": "14/25",
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(PASS_MARKER + json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditFailure as exc:
        print(f"QSDK_R10E_OBSERVER_MINIMIZED_SUCCESSOR_DESIGN_FAIL {exc}")
        raise SystemExit(1) from exc
