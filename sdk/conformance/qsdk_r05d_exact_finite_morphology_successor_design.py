#!/usr/bin/env python3
"""Audit the zero-world R05D morphology diagnosis and R05E successor design."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = ROOT / "sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json"
EXPECTED_DESIGN_BYTES = 29365
EXPECTED_DESIGN_SHA256 = "3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
EXPECTED_SCHEMA = "sporespore_qsdk_r05d_exact_finite_morphology_successor_design_v1"
EXPECTED_STATUS = (
    "closed_zero_world_exact_finite_axis_star_successor_selected_"
    "implementation_required_physics_blocked"
)
PARENT_COMMIT = "e345c875c922d1461f4cb10101b589a9410c571f"
AXES = (
    "torso_length_scale",
    "torso_width_scale",
    "upper_length_fraction",
    "hip_span_scale",
    "foot_radius_scale",
    "front_limb_mass_scale",
)
EXPECTED_IDS = (
    "qsdk_r05e_axis_star_torso_length_low_s217",
    "qsdk_r05e_axis_star_torso_length_high_s218",
    "qsdk_r05e_axis_star_torso_width_low_s219",
    "qsdk_r05e_axis_star_torso_width_high_s220",
    "qsdk_r05e_axis_star_upper_fraction_low_s221",
    "qsdk_r05e_axis_star_upper_fraction_high_s222",
    "qsdk_r05e_axis_star_hip_span_low_s223",
    "qsdk_r05e_axis_star_hip_span_high_s224",
    "qsdk_r05e_axis_star_foot_radius_low_s225",
    "qsdk_r05e_axis_star_foot_radius_high_s226",
    "qsdk_r05e_axis_star_front_limb_mass_low_s227",
    "qsdk_r05e_axis_star_front_limb_mass_high_s228",
)


class AuditFailure(RuntimeError):
    """Raised when a bound authority or design invariant is not exact."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditFailure(message)


def sha256_hex(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}: invalid UTF-8 JSON: {exc}") from exc
    require(isinstance(value, dict), f"{label}: root must be an object")
    return value


def run_git(*args: str, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ("git", *args),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=not binary,
    )
    if completed.returncode != 0:
        stderr = (
            completed.stderr.decode("utf-8", errors="replace")
            if binary
            else completed.stderr
        )
        raise AuditFailure(f"git {' '.join(args)} failed: {stderr.strip()}")
    return completed.stdout


def git_blob(commit: str, path: str) -> bytes:
    result = run_git("show", f"{commit}:{path}", binary=True)
    require(isinstance(result, bytes), "git show did not return bytes")
    return result


def git_blob_oid(commit: str, path: str) -> str:
    result = run_git("rev-parse", f"{commit}:{path}")
    require(isinstance(result, str), "git rev-parse did not return text")
    return result.strip()


def get_path(document: Any, dotted_path: str) -> Any:
    current = document
    for key in dotted_path.split("."):
        require(isinstance(current, dict), f"{dotted_path}: parent is not an object")
        require(key in current, f"{dotted_path}: missing key {key}")
        current = current[key]
    return current


def exact_float(actual: Any, expected: float, label: str) -> None:
    require(isinstance(actual, (int, float)) and not isinstance(actual, bool), f"{label}: not numeric")
    require(
        math.isclose(float(actual), expected, rel_tol=0.0, abs_tol=2.0e-15),
        f"{label}: expected {expected!r}, observed {actual!r}",
    )


def bind_authorities(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    authorities = design.get("bound_authorities")
    require(isinstance(authorities, list), "bound_authorities must be a list")
    require(len(authorities) == 10, "exactly ten bound authorities are required")
    loaded: dict[str, dict[str, Any]] = {}
    for authority in authorities:
        require(isinstance(authority, dict), "bound authority must be an object")
        role = authority.get("role")
        require(isinstance(role, str) and role, "bound authority role is required")
        require(role not in loaded, f"duplicate bound authority role: {role}")
        path_text = authority.get("path")
        require(isinstance(path_text, str) and path_text, f"{role}: path is required")
        if authority.get("path_kind") == "absolute_durable_evidence":
            path = Path(path_text)
            require(path.is_absolute(), f"{role}: durable path must be absolute")
            require(path.is_file(), f"{role}: durable file is missing: {path}")
            raw = path.read_bytes()
        else:
            require(
                authority.get("source_commit") == PARENT_COMMIT,
                f"{role}: source commit must be the authored parent",
            )
            raw = git_blob(PARENT_COMMIT, path_text)
            require(
                authority.get("git_blob_oid") == git_blob_oid(PARENT_COMMIT, path_text),
                f"{role}: Git blob OID mismatch",
            )
        require(len(raw) == authority.get("byte_length"), f"{role}: byte length mismatch")
        require(
            f"sha256:{sha256_hex(raw)}" == authority.get("raw_sha256"),
            f"{role}: SHA-256 mismatch",
        )
        expected_paths = authority.get("expected_paths", {})
        if path_text.lower().endswith(".json"):
            document = read_json(raw, role)
        else:
            require(not expected_paths, f"{role}: text authority cannot declare JSON paths")
            try:
                raw.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise AuditFailure(f"{role}: text authority is not UTF-8") from exc
            document = {}
        for dotted_path, expected in expected_paths.items():
            require(
                get_path(document, dotted_path) == expected,
                f"{role}: expected path mismatch at {dotted_path}",
            )
        loaded[role] = document
    return loaded


def false_walking_gates(result: dict[str, Any]) -> tuple[str, ...]:
    gates = result["receipt"]["walking_gate_receipts"]
    require(isinstance(gates, dict), "walking gate receipt must be an object")
    return tuple(key for key, value in gates.items() if value is False)


def shell_fraction(generator_index: int) -> float:
    return 0.25 * (1 + ((generator_index - 1) % 4))


def shell_summary(report: dict[str, Any]) -> list[dict[str, Any]]:
    summary: list[dict[str, Any]] = []
    for shell in (0.25, 0.5, 0.75, 1.0):
        cells = [
            result
            for result in report["results"]
            if shell_fraction(int(result["generator_index"])) == shell
        ]
        summary.append(
            {
                "historical_shell_fraction": shell,
                "world_count": len(cells),
                "walking_pass_count": sum(bool(cell["walking_observed"]) for cell in cells),
            }
        )
    return summary


def validate_historical_population(
    design: dict[str, Any],
    loaded: dict[str, dict[str, Any]],
) -> None:
    analysis = design["historical_population_analysis"]
    r05b_design = analysis["r05b"]
    r05b = loaded["r05b_retained_report"]
    require(len(r05b["results"]) == 36, "R05B result population must contain 36 cells")
    require(r05b_design["world_count"] == 36, "R05B design world count changed")
    require(r05b_design["walking_pass_count"] == 33, "R05B design pass count changed")
    require(r05b_design["walking_failure_count"] == 3, "R05B design failure count changed")
    require(r05b_design["shell_results"] == shell_summary(r05b), "R05B shell summary mismatch")

    actual_r05b_failures: list[dict[str, Any]] = []
    for result in r05b["results"]:
        if result["walking_observed"]:
            continue
        record: dict[str, Any] = {
            "generator_index": result["generator_index"],
            "campaign_seed": result["campaign_seed"],
            "false_walking_gates": list(false_walking_gates(result)),
        }
        if result["generator_index"] == 190 and result["campaign_seed"] == 21601:
            record["final_task_frame_lateral_displacement_m"] = result["receipt"][
                "final_task_frame_lateral_displacement_m"
            ]
            closure_cell = next(
                cell
                for cell in loaded["r05b_immutable_closure"]["failed_cells"]
                if cell["generator_index"] == 190 and cell["campaign_seed"] == 21601
            )
            record["preregistered_lateral_bound_m"] = closure_cell[
                "maximum_lateral_drift_m"
            ]
        actual_r05b_failures.append(record)
    require(
        actual_r05b_failures == r05b_design["failed_cells"],
        "R05B exact failure structure mismatch",
    )

    r05c_design = analysis["r05c"]
    r05c = loaded["r05c_retained_report"]
    require(len(r05c["results"]) == 36, "R05C result population must contain 36 cells")
    require(r05c_design["world_count"] == 36, "R05C design world count changed")
    require(r05c_design["walking_pass_count"] == 29, "R05C design pass count changed")
    require(r05c_design["walking_failure_count"] == 7, "R05C design failure count changed")
    require(r05c_design["shell_results"] == shell_summary(r05c), "R05C shell summary mismatch")
    actual_r05c_pairs = [
        f"{result['generator_index']}:{result['campaign_seed']}"
        for result in r05c["results"]
        if not result["walking_observed"]
    ]
    require(
        actual_r05c_pairs == r05c_design["failed_cell_seed_pairs"],
        "R05C failed cell/seed population mismatch",
    )
    require(
        r05b["selected_policy_id"] != r05c["selected_policy_id"],
        "R05C must remain a different-policy diagnostic",
    )

    conclusions = analysis["diagnostic_conclusions"]
    expected_false = (
        "walking_success_monotonic_in_historical_shell_radius",
        "continuous_inner_box_supported_by_these_results",
        "arbitrary_combination_support_established",
        "historical_passing_cell_subselection_permitted_as_fresh_evidence",
        "historical_failed_cell_deletion_or_replacement_permitted",
        "r05c_used_as_same_policy_acceptance_evidence",
        "r05b_or_r05c_threshold_change_warranted",
        "selected_policy_change_warranted_by_this_diagnosis",
    )
    for key in expected_false:
        require(conclusions.get(key) is False, f"historical conclusion must remain false: {key}")
    require(
        conclusions.get("exact_finite_new_descriptor_set_is_answerable") is True,
        "exact finite successor answerability must remain selected",
    )


def expected_endpoint(reference: float, historical_endpoint: float) -> float:
    return reference + 0.25 * (historical_endpoint - reference)


def validate_axis_star(design: dict[str, Any]) -> None:
    selected = design["selected_successor_design"]
    require(selected["successor_gate_id"] == "QSDK-R05E", "successor gate changed")
    require(
        selected["selected_policy_id"] == "sporespore_balanced_wave_bw5r_b_v1",
        "selected policy changed",
    )
    require(
        selected["selected_policy_digest"]
        == "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
        "selected policy digest changed",
    )
    require(selected["policy_branch_surface_count"] == 0, "policy branch surface added")
    for key in (
        "controller_change_selected",
        "threshold_change_selected",
        "margin_change_selected",
        "walking_evaluator_change_selected",
        "material_change_selected",
        "engine_change_selected",
    ):
        require(selected.get(key) is False, f"unexpected successor change selected: {key}")
    require(
        selected["support_topology"]
        == "exact_finite_six_axis_local_star_not_a_box_or_interpolation_domain",
        "support topology changed",
    )

    star = design["axis_star"]
    require(star["cell_count"] == 12, "axis-star cell count changed")
    require(len(star["cells"]) == 12, "axis-star must contain twelve cells")
    exact_float(star["historical_interval_scale_factor"], 0.25, "design radius")
    reference = star["reference"]
    historical = star["historical_axis_intervals"]
    endpoints = star["exact_axis_endpoints"]
    require(tuple(reference) == AXES, "reference axis order or identity changed")
    require(tuple(historical) == AXES, "historical interval axes changed")
    require(tuple(endpoints) == AXES, "endpoint axes changed")

    r05b_intervals = {
        key: value
        for key, value in design["_loaded_r05b_preregistration"][
            "morphology_generator"
        ]["axis_intervals"].items()
    }
    require(historical == r05b_intervals, "historical intervals differ from R05B freeze")
    for axis in AXES:
        interval = historical[axis]
        require(len(interval) == 3, f"{axis}: historical interval shape changed")
        exact_float(interval[0], float(reference[axis]), f"{axis}: interval reference")
        expected = (
            expected_endpoint(float(reference[axis]), float(interval[1])),
            expected_endpoint(float(reference[axis]), float(interval[2])),
        )
        exact_float(endpoints[axis][0], expected[0], f"{axis}: low endpoint")
        exact_float(endpoints[axis][1], expected[1], f"{axis}: high endpoint")

    seen_indices: set[int] = set()
    seen_ids: set[str] = set()
    seen_axis_directions: set[tuple[str, str]] = set()
    expected_spec_keys = ("schema_version", "morphology_id", *AXES)
    for offset, cell in enumerate(star["cells"]):
        expected_index = 217 + offset
        require(cell["generator_index"] == expected_index, "axis-star index order changed")
        require(cell["morphology_id"] == EXPECTED_IDS[offset], "axis-star identity changed")
        require(cell["generator_index"] not in seen_indices, "duplicate generator index")
        require(cell["morphology_id"] not in seen_ids, "duplicate morphology identity")
        seen_indices.add(cell["generator_index"])
        seen_ids.add(cell["morphology_id"])
        axis = cell["changed_axis"]
        direction = cell["direction"]
        require(axis in AXES, f"unknown changed axis: {axis}")
        require(direction in ("low", "high"), f"unknown direction: {direction}")
        require((axis, direction) not in seen_axis_directions, "duplicate axis direction")
        seen_axis_directions.add((axis, direction))
        spec = cell["proportion_spec"]
        require(tuple(spec) == expected_spec_keys, "proportion-spec key order or set changed")
        require(
            spec["schema_version"] == "sporespore_physical_quadruped_proportion_spec_v1",
            "proportion schema changed",
        )
        require(spec["morphology_id"] == cell["morphology_id"], "morphology ID split")
        changed_count = 0
        for candidate_axis in AXES:
            if candidate_axis == axis:
                expected_value = endpoints[axis][0 if direction == "low" else 1]
                exact_float(spec[candidate_axis], expected_value, f"{cell['morphology_id']}:{axis}")
                changed_count += 1
            else:
                exact_float(
                    spec[candidate_axis],
                    float(reference[candidate_axis]),
                    f"{cell['morphology_id']}:{candidate_axis}",
                )
        require(changed_count == 1, "each star cell must change exactly one axis")
    require(
        seen_axis_directions
        == {(axis, direction) for axis in AXES for direction in ("low", "high")},
        "axis star does not cover both directions of every axis",
    )

    support = star["support_semantics"]
    require(support["each_cell_is_an_exact_descriptor_identity"] is True, "exact support lost")
    for key in (
        "all_points_inside_axis_minima_and_maxima_supported",
        "multi_axis_combinations_supported",
        "interpolation_supported",
        "extrapolation_supported",
        "continuous_volume_supported",
        "arbitrary_quadruped_supported",
    ):
        require(support.get(key) is False, f"unsupported morphology claim enabled: {key}")


def validate_sequence_and_claims(design: dict[str, Any]) -> None:
    sequence = design["prospective_sequence"]
    qualification = sequence["implementation_and_zero_world_qualification"]
    require(qualification["required"] is True, "zero-world qualification no longer required")
    require(len(qualification["required_controls"]) == 7, "zero-world control plan changed")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(qualification[key] == 0, f"qualification {key} must remain zero")

    ghost = sequence["development_route_ghost"]
    require(ghost["authority_mode"] == "development_ghost_only", "ghost authority changed")
    require(ghost["generator_index"] == 229, "ghost generator index changed")
    require(ghost["campaign_seed"] == 40001, "ghost seed changed")
    require(ghost["maximum_world_count"] == 1, "ghost world budget changed")
    require(ghost["held_out_access_permitted"] is False, "ghost may not access held-out cells")
    require(ghost["behavior_success_required"] is False, "ghost may not become behavior evidence")
    require(ghost["route_completion_required"] is True, "ghost must cover the complete route")
    require(
        ghost["morphology_id"] not in set(EXPECTED_IDS),
        "development ghost identity overlaps held-out population",
    )

    finite = sequence["held_out_finite_decision"]
    require(finite["permitted_now"] is False, "held-out physics prematurely authorized")
    require(finite["generator_indices"] == list(range(217, 229)), "held-out indices changed")
    require(finite["campaign_seeds"] == [40101, 40102, 40103], "held-out seeds changed")
    require(finite["morphology_count"] == 12, "held-out morphology count changed")
    require(finite["seed_count"] == 3, "held-out seed count changed")
    require(finite["world_count"] == 36, "held-out world count changed")
    require(finite["complete_cartesian_product_required"] is True, "Cartesian product weakened")
    for key in (
        "all_cells_must_complete",
        "all_cells_must_pass_common_execution_integrity",
        "all_cells_must_pass_every_unchanged_production_walking_gate",
        "early_stop_for_outcome_forbidden",
        "failed_cell_deletion_replacement_averaging_or_threshold_change_forbidden",
        "first_complete_result_is_final_for_the_frozen_source_identity",
    ):
        require(finite.get(key) is True, f"finite-decision invariant weakened: {key}")

    freshness = design["freshness_snapshot"]
    require(freshness["snapshot_parent_commit"] == PARENT_COMMIT, "freshness parent changed")
    for key in (
        "official_generator_indices_217_through_228_preexisting_match_count",
        "development_generator_index_229_preexisting_match_count",
        "official_seed_values_40101_through_40103_preexisting_match_count",
        "development_seed_40001_preexisting_match_count",
        "r05d_or_r05e_morphology_identity_preexisting_match_count",
    ):
        require(freshness.get(key) == 0, f"freshness snapshot changed: {key}")

    limits = design["immutability_and_limits"]
    for key in (
        "r05b_reexecuted",
        "r05c_reexecuted",
        "physics_state_modified",
    ):
        require(limits.get(key) is False, f"historical/physics boundary changed: {key}")
    for key in (
        "historical_closure_audit_execution_count",
        "historical_report_rewrite_count",
        "historical_result_reclassification_count",
        "historical_threshold_change_count",
        "historical_selector_change_count",
        "historical_failed_cell_deletion_count",
        "new_empirical_threshold_count",
        "new_behavior_threshold_count",
        "new_superiority_margin_count",
        "new_equivalence_margin_count",
        "new_non_inferiority_margin_count",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(limits.get(key) == 0, f"zero-world count changed: {key}")

    decision = design["decision"]
    require(decision["exact_finite_axis_star_selected"] is True, "axis-star decision lost")
    require(decision["single_route_ghost_selected"] is True, "route ghost decision lost")
    require(decision["held_out_cells_remain_sealed"] is True, "held-out cells unsealed")
    for key in (
        "r05b_same_identity_rerun_permitted",
        "r05c_same_identity_rerun_permitted",
        "continuous_inner_envelope_selected",
        "posthoc_passing_subset_selected",
        "q_sdk_r05e_physical_execution_authorized",
        "full_seeded_development_campaign_selected",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(decision.get(key) is False, f"decision boundary changed: {key}")

    next_boundary = design["next_boundary"]
    require(next_boundary["gate_id"] == "QSDK-R05E", "next gate changed")
    require(next_boundary["physical_execution_authorized"] is False, "physics authorized")
    for key in (
        "maximum_world_attempt_count_now",
        "maximum_world_build_count_now",
        "maximum_solver_step_count_now",
    ):
        require(next_boundary[key] == 0, f"next boundary permits physical work: {key}")

    claims = design["claim_boundary"]
    require(claims["r05b_valid_complete_rejection_preserved"] is True, "R05B not preserved")
    require(claims["r05c_valid_complete_rejection_preserved"] is True, "R05C not preserved")
    for key in (
        "same_selected_policy_independent_morphology_evidence",
        "finite_supported_morphology_set_established",
        "continuous_morphology_envelope_established",
        "arbitrary_quadruped_coverage_established",
        "walking_acceptance_established",
        "m05_advanced",
        "q_sdk_r05_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(key) is False, f"claim advanced prematurely: {key}")

    context = design["release_milestone_context"]
    require(context["current_disposition"] == "contradicted", "M05 disposition changed")
    require(context["current_sdk1_completed_steps"] == 12, "SDK1 score changed")
    require(context["current_full_program_completed_steps"] == 12, "program score changed")
    require(context["milestone_advanced_by_this_design"] is False, "M05 advanced")


def validate_live_release_projection(design: dict[str, Any]) -> None:
    support_path = ROOT / "sdk/release/quadruped_support_matrix.json"
    support_raw = support_path.read_bytes()
    support = read_json(support_raw, "live support matrix")
    require(len(support_raw) == 1599706, "live support-matrix byte length drifted")
    require(
        sha256_hex(support_raw)
        == "f2d3cc1d0b304757bf23ea5dd9b65bbbdfe918f5bbf49d8e4774377de1a5f653",
        "live support-matrix identity drifted",
    )
    require(
        "prospective_exact_finite_successor" not in support["morphology"],
        "R05D must remain an additive ledger until M05 is earned",
    )
    require(
        support["morphology"]["same_selected_policy_independent_morphology_evidence"]
        is False,
        "live morphology support claim advanced",
    )
    require(support["scope"]["selected_policy_id"] == selected_policy_id(design), "live policy changed")
    require(support["release_authorized"] is False, "live release authorized")
    require(support["completed_engine_neutral_sdk"] is False, "live SDK completed")

    mapping = read_json(
        (ROOT / "sdk/release/quadruped_sdk1_milestone_mapping_v1.json").read_bytes(),
        "SDK1 milestone mapping",
    )
    require(
        mapping["full_program_authority"]["support_matrix_raw_sha256"]
        == f"sha256:{sha256_hex(support_raw)}",
        "SDK1 mapping support-matrix identity drifted",
    )
    m05 = next(
        item
        for item in mapping["sdk1_contract"]["milestones"]
        if item["milestone_id"] == "SDK1-M05"
    )
    require(m05["source"]["gate_id"] == "QSDK-R05", "SDK1-M05 source gate changed")

    contract = read_json(
        (ROOT / "sdk/release/quadruped_release_contract.json").read_bytes(),
        "live release contract",
    )
    r05 = next(gate for gate in contract["gates"] if gate["gate_id"] == "QSDK-R05")
    require(r05["proof"]["kind"] == "contradicted_json_report", "QSDK-R05 kind changed")
    require(r05["proof"]["path"] == "qsdk-r05b-51d1b70/report.json", "QSDK-R05 proof changed")
    require(
        r05["proof"]["sha256"]
        == "sha256:d5880f2ff78396d8d1ee4ab8851b454dd908ba85a3d9dfae3ac8ca6893054b3a",
        "QSDK-R05 report binding changed",
    )


def selected_policy_id(design: dict[str, Any]) -> str:
    return str(design["selected_successor_design"]["selected_policy_id"])


def validate_design(
    design: dict[str, Any],
    *,
    verify_bindings: bool,
    preloaded: dict[str, dict[str, Any]] | None = None,
) -> dict[str, dict[str, Any]]:
    require(design.get("schema_version") == EXPECTED_SCHEMA, "schema version mismatch")
    require(design.get("gate_id") == "QSDK-R05D", "gate ID mismatch")
    require(design.get("status") == EXPECTED_STATUS, "status mismatch")
    require(design.get("authored_parent_commit") == PARENT_COMMIT, "parent commit mismatch")
    require(design.get("question_class") == "development", "question class changed")
    require(design.get("physical_question_declared") is False, "physical question declared")
    require(design.get("finite_decision_declared") is False, "finite decision declared early")
    scope = design["ledger_scope"]
    require(scope["subsystem"] == "walking", "ledger subsystem changed")
    require(scope["engine_scope"] == "godot_jolt", "ledger engine scope changed")
    require(scope["question_class"] == "development", "ledger question class changed")

    loaded = bind_authorities(design) if verify_bindings else preloaded
    require(loaded is not None, "bound authority data is required")
    design["_loaded_r05b_preregistration"] = loaded["r05b_preregistration"]
    try:
        validate_historical_population(design, loaded)
        validate_axis_star(design)
        validate_sequence_and_claims(design)
        if verify_bindings:
            validate_live_release_projection(design)
    finally:
        design.pop("_loaded_r05b_preregistration", None)
    return loaded


def mutation_controls(
    design: dict[str, Any],
    loaded: dict[str, dict[str, Any]],
) -> int:
    mutations: tuple[tuple[str, Any], ...] = (
        ("schema", lambda d: d.__setitem__("schema_version", "mutated")),
        (
            "historical pass count",
            lambda d: d["historical_population_analysis"]["r05b"].__setitem__(
                "walking_pass_count", 34
            ),
        ),
        (
            "historical shell inference",
            lambda d: d["historical_population_analysis"]["diagnostic_conclusions"].__setitem__(
                "continuous_inner_box_supported_by_these_results", True
            ),
        ),
        (
            "selected policy",
            lambda d: d["selected_successor_design"].__setitem__(
                "selected_policy_id", "mutated"
            ),
        ),
        (
            "duplicate held-out identity",
            lambda d: d["axis_star"]["cells"][1].__setitem__(
                "morphology_id", d["axis_star"]["cells"][0]["morphology_id"]
            ),
        ),
        (
            "second changed axis",
            lambda d: d["axis_star"]["cells"][0]["proportion_spec"].__setitem__(
                "torso_width_scale", 1.001
            ),
        ),
        (
            "missing axis direction",
            lambda d: d["axis_star"]["cells"].pop(),
        ),
        (
            "continuous support",
            lambda d: d["axis_star"]["support_semantics"].__setitem__(
                "continuous_volume_supported", True
            ),
        ),
        (
            "held-out seed",
            lambda d: d["prospective_sequence"]["held_out_finite_decision"].__setitem__(
                "campaign_seeds", [40101, 40102, 40104]
            ),
        ),
        (
            "premature physical authorization",
            lambda d: d["decision"].__setitem__(
                "q_sdk_r05e_physical_execution_authorized", True
            ),
        ),
        (
            "premature milestone",
            lambda d: d["claim_boundary"].__setitem__("m05_advanced", True),
        ),
        (
            "nonzero solver count",
            lambda d: d["immutability_and_limits"].__setitem__("solver_step_count", 1),
        ),
    )
    passed = 0
    for label, mutate in mutations:
        candidate = copy.deepcopy(design)
        mutate(candidate)
        try:
            validate_design(candidate, verify_bindings=False, preloaded=loaded)
        except AuditFailure:
            passed += 1
        else:
            raise AuditFailure(f"mutation control was accepted: {label}")
    return passed


def main() -> int:
    try:
        raw = DESIGN_PATH.read_bytes()
        require(len(raw) == EXPECTED_DESIGN_BYTES, "design byte length mismatch")
        require(sha256_hex(raw) == EXPECTED_DESIGN_SHA256, "design SHA-256 mismatch")
        design = read_json(raw, "R05D design")
        loaded = validate_design(design, verify_bindings=True)
        control_count = mutation_controls(design, loaded)
        print(
            "QSDK_R05D_EXACT_FINITE_MORPHOLOGY_SUCCESSOR_DESIGN_PASS "
            f"bound_authorities={len(loaded)} "
            f"axis_star_cells={len(design['axis_star']['cells'])} "
            f"held_out_worlds={design['prospective_sequence']['held_out_finite_decision']['world_count']} "
            f"mutation_controls={control_count} "
            "model_construction_count=0 world_attempt_count=0 "
            "world_build_count=0 native_readback_count=0 solver_step_count=0"
        )
        return 0
    except (AuditFailure, KeyError, IndexError, TypeError, OSError) as exc:
        print(
            f"QSDK_R05D_EXACT_FINITE_MORPHOLOGY_SUCCESSOR_DESIGN_FAIL {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
