#!/usr/bin/env python3
"""Audit the prospective QSDK-R10B-L2 representation-only successor design."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json"
)
R10A_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json"
)
L1_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json"
)
L1_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10b_l1_development_route_ghost_physical_invalid.py"
)
R66_CONTRACT_PATH = (
    ROOT / "sdk/recovery/r24d66_godot_exact_quaternion_projection_contract_v1.json"
)
R66_CLOSURE_PATH = (
    ROOT / "sdk/recovery/"
    "r24d66_godot_exact_quaternion_projection_zero_world_qualification_closure_v1.json"
)
R66_WORLD_PATH = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
METHOD_ID = "godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
L1_PARENT_COMMIT = "c22072f8d86e30a047e1116be196befbf969b866"
R66_SOURCE_COMMIT = "a3ad18d817efee465fae837e3d9ad144fa1bd258"
R66_CLOSURE_COMMIT = "e8d82516844b9f18ff74bd51d3e8770b40c95ac2"
PASS_MARKER = "QSDK_R10B_L2_SUCCESSOR_DESIGN_PASS "
L1_PASS_MARKER = "QSDK_R10B_L1_PHYSICAL_INVALID_CLOSURE_PASS "

EXPECTED_IDENTITIES: dict[str, tuple[Path | str, int, str, str, str]] = {
    "r10a_bounded_upright_push_recovery_design": (
        R10A_DESIGN_PATH,
        25_836,
        "f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66",
        "",
        "",
    ),
    "consumed_l1_physical_invalid_closure": (
        L1_CLOSURE_PATH,
        16_922,
        "b9f8304e229d1a897137bafcce51ee6089b11b15742f624ccf38d202b8fe35a1",
        L1_PARENT_COMMIT,
        "42074ba893edf90cb3af060534a2510ab0fdfba8",
    ),
    "r24d66_qualified_projection_contract": (
        R66_CONTRACT_PATH,
        21_092,
        "2860d75b05bf5ae1662ef73bf9585915b997e760ee392b8ba98c4b7f45665ece",
        R66_SOURCE_COMMIT,
        "8058ed0987909505c672ccda1a2c5012c15b4dec",
    ),
    "r24d66_zero_world_qualification_closure": (
        R66_CLOSURE_PATH,
        22_541,
        "09287ca8ac4075bacc85b8abae963e61695544e331395dd1604f6511d5a329af",
        R66_CLOSURE_COMMIT,
        "b8e44579a16451034737c5684ca88004b9547acc",
    ),
    "r24d66_historical_projection_implementation": (
        R66_WORLD_PATH,
        92_595,
        "6667e71553a5d43dcc18b35a64a7e272a597a8d14e7b22d4b15f0e5f77d64a5d",
        R66_SOURCE_COMMIT,
        "f588c44e0fe3cbc7073654fd49a29746b380f96b",
    ),
}


class AuditFailure(RuntimeError):
    """The prospective L2 design or one of its frozen bindings drifted."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}_INVALID_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_ROOT_NOT_OBJECT")
    return value


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        return read_json_bytes(path.read_bytes(), label)
    except OSError as exc:
        raise AuditFailure(f"{label}_UNREADABLE:{exc}") from exc


def git(arguments: Iterable[str], *, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ("git", "-C", ROOT, *arguments),
        check=False,
        capture_output=True,
        text=not binary,
        encoding=None if binary else "utf-8",
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(arguments)}")
    return completed.stdout if binary else completed.stdout.strip()


def validate_repository_identity() -> None:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "WRONG_ROOT_CONSTANT")
    require(
        Path(str(git(("rev-parse", "--show-toplevel")))).resolve()
        == EXPECTED_ROOT.resolve(),
        "WRONG_REPOSITORY_ROOT",
    )
    require(
        str(git(("remote", "get-url", "origin"))) == EXPECTED_REMOTE,
        "WRONG_REPOSITORY_REMOTE",
    )


def binding_map(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    bindings = design.get("bound_authorities")
    require(isinstance(bindings, list) and len(bindings) == 5, "BINDING_COUNT")
    result: dict[str, dict[str, Any]] = {}
    for value in bindings:
        require(isinstance(value, dict), "BINDING_NOT_OBJECT")
        role = value.get("role")
        require(isinstance(role, str) and role and role not in result, "BINDING_ROLE")
        result[role] = value
    require(set(result) == set(EXPECTED_IDENTITIES), "BINDING_ROLE_SET")
    return result


def validate_bindings(design: dict[str, Any]) -> dict[str, dict[str, Any]]:
    bindings = binding_map(design)
    loaded: dict[str, dict[str, Any]] = {}
    for role, (
        path_or_relative,
        expected_bytes,
        expected_sha,
        commit,
        blob,
    ) in EXPECTED_IDENTITIES.items():
        declaration = bindings[role]
        relative = (
            path_or_relative.relative_to(ROOT).as_posix()
            if isinstance(path_or_relative, Path)
            else path_or_relative
        )
        require(declaration.get("path") == relative, f"{role}:PATH")
        require(declaration.get("byte_length") == expected_bytes, f"{role}:BYTES")
        require(
            declaration.get("raw_sha256") == f"sha256:{expected_sha}",
            f"{role}:SHA",
        )
        if commit:
            require(declaration.get("source_commit") == commit, f"{role}:COMMIT")
            require(declaration.get("git_blob_oid") == blob, f"{role}:BLOB")
            raw = bytes(git(("show", f"{commit}:{relative}"), binary=True))
            require(
                str(git(("rev-parse", f"{commit}:{relative}"))) == blob,
                f"{role}:GIT_BLOB",
            )
        else:
            raw = (ROOT / relative).read_bytes()
        require(len(raw) == expected_bytes, f"{role}:OBSERVED_BYTES")
        require(sha256(raw) == expected_sha, f"{role}:OBSERVED_SHA")
        current_path = ROOT / relative
        if (
            current_path.is_file()
            and role != "r24d66_historical_projection_implementation"
        ):
            require(current_path.read_bytes() == raw, f"{role}:CURRENT_BYTES_DRIFT")
        if relative.endswith(".json"):
            loaded[role] = read_json_bytes(raw, role)
    return loaded


def validate_loaded_authorities(loaded: dict[str, dict[str, Any]]) -> None:
    l1 = loaded["consumed_l1_physical_invalid_closure"]
    require(
        l1.get("status")
        == "closed_consumed_infrastructure_invalid_baseline_trace_quaternion_projection",
        "L1_STATUS",
    )
    require(l1.get("repair_id") == "QSDK-R10B-L1", "L1_REPAIR")
    require(l1.get("closure_id") == "QSDK-R10B-L1-P1", "L1_CLOSURE")
    require(
        l1.get("physical_attempt", {}).get("physical_identity_consumed") is True,
        "L1_NOT_CONSUMED",
    )
    require(
        l1.get("physical_attempt", {}).get("same_identity_rerun_permitted") is False,
        "L1_RERUN_PERMITTED",
    )
    require(
        l1.get("decision", {}).get("selected_successor_id") == "QSDK-R10B-L2",
        "L1_SUCCESSOR",
    )
    require(
        l1.get("physical_attempt", {})
        .get("execution_counts", {})
        .get("push_world_attempt_count")
        == 0,
        "L1_PUSH_WORLD_COUNT",
    )

    contract = loaded["r24d66_qualified_projection_contract"]
    require(contract.get("gate_id") == "QSDK-R24D66", "R66_CONTRACT_GATE")
    require(
        contract.get("threshold_and_margin_provenance", {}).get(
            "quaternion_norm_squared_tolerance"
        )
        == 1.0e-9,
        "R66_CONTRACT_TOLERANCE",
    )
    require(
        contract.get("threshold_and_margin_provenance", {}).get(
            "threshold_change_count"
        )
        == 0,
        "R66_CONTRACT_THRESHOLD_CHANGE",
    )
    projection = contract.get("quaternion_projection_contract", {})
    require(projection.get("method_id") == METHOD_ID, "R66_CONTRACT_METHOD")
    require(
        projection.get("representative_projection_case_count") == 4,
        "R66_CONTRACT_CASE_COUNT",
    )

    closure = loaded["r24d66_zero_world_qualification_closure"]
    require(closure.get("gate_id") == "QSDK-R24D66", "R66_CLOSURE_GATE")
    require(
        closure.get("closure_status")
        == "closed_complete_zero_world_exact_quaternion_projection_qualified_published_closure_control_required_physics_blocked",
        "R66_CLOSURE_STATUS",
    )
    source = closure.get("source", {})
    require(
        source.get("source_freeze_commit") == R66_SOURCE_COMMIT,
        "R66_CLOSURE_SOURCE",
    )
    result = closure.get("qualification", {})
    require(result.get("projected_core_acceptance_count") == 4, "R66_PROJECTED_COUNT")
    require(result.get("raw_core_refusal_count") == 3, "R66_RAW_REFUSAL_COUNT")


def validate_design(design: dict[str, Any], *, verify_bindings: bool) -> None:
    require(
        set(design)
        == {
            "schema_version",
            "status",
            "gate_id",
            "repair_id",
            "authored_parent_commit",
            "authored_local_date",
            "ledger_scope",
            "question_declaration",
            "causal_basis",
            "bound_authorities",
            "selected_projection_contract",
            "controlled_change_boundary",
            "required_zero_world_controls",
            "forward_authority_sequence",
            "claim_boundary",
        },
        "DESIGN_KEYS",
    )
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1",
        "DESIGN_SCHEMA",
    )
    require(
        design.get("status")
        == "prospective_representation_only_successor_implementation_in_progress_physics_blocked",
        "DESIGN_STATUS",
    )
    require(design.get("gate_id") == "QSDK-R10B", "DESIGN_GATE")
    require(design.get("repair_id") == "QSDK-R10B-L2", "DESIGN_REPAIR")
    require(design.get("authored_parent_commit") == L1_PARENT_COMMIT, "DESIGN_PARENT")
    require(
        design.get("ledger_scope")
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "prospective_zero_world_representation_repair_design",
            "question_class": "development",
        },
        "DESIGN_LEDGER_SCOPE",
    )
    question = design.get("question_declaration", {})
    require(
        question
        == {
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "physical_work_authorized": False,
            "maximum_world_attempt_count_before_complete_new_authority_graph": 0,
            "maximum_world_build_count_before_complete_new_authority_graph": 0,
        },
        "DESIGN_QUESTION_BOUNDARY",
    )
    basis = design.get("causal_basis", {})
    require(
        basis.get("consumed_predecessor_repair_id") == "QSDK-R10B-L1", "BASIS_REPAIR"
    )
    require(
        basis.get("consumed_predecessor_closure_id") == "QSDK-R10B-L1-P1",
        "BASIS_CLOSURE",
    )
    require(basis.get("validator_tolerance") == 1.0e-9, "BASIS_TOLERANCE")
    require(basis.get("validator_tolerance_changed") is False, "BASIS_TOLERANCE_CHANGE")
    require(basis.get("retained_trace_row_count") == 2640, "BASIS_ROW_COUNT")
    require(
        basis.get("quaternion_tolerance_violating_row_count") == 2566,
        "BASIS_REFUSAL_COUNT",
    )
    require(
        basis.get("first_invalid_orientation_xyzw")
        == [
            3.013798050233163e-6,
            0.00013243728608358651,
            -5.525192136701662e-6,
            1.0,
        ],
        "BASIS_ROW_ZERO",
    )
    require(
        basis.get("maximum_delta_orientation_xyzw")
        == [
            0.011945354752242565,
            -0.0590871162712574,
            -0.00016306180623359978,
            0.9981814622879028,
        ],
        "BASIS_ROW_1889",
    )
    require(basis.get("behavior_result_established") is False, "BASIS_BEHAVIOR")
    require(
        basis.get("outcome_derived_correction_selected") is False,
        "BASIS_OUTCOME_CORRECTION",
    )

    projection = design.get("selected_projection_contract", {})
    require(projection.get("method_id") == METHOD_ID, "PROJECTION_METHOD")
    for field in (
        "source_components_promoted_before_norm",
        "normalization_performed_in_exported_scalar_space",
        "largest_absolute_component_reconstructed",
        "source_component_sign_preserved",
        "nonfinite_source_refused",
        "nonpositive_source_norm_refused",
        "source_orientation_retained",
        "source_norm_and_delta_retained",
        "projected_orientation_retained",
        "projected_norm_and_delta_retained",
        "reconstructed_component_index_retained",
        "r10b_validator_reads_exported_scalars_without_float32_rematerialization",
    ):
        require(projection.get(field) is True, f"PROJECTION_REQUIRED:{field}")
    for field in (
        "r24d66_core_tolerance_changed",
        "r10b_validator_quantity_changed",
        "r10b_validator_tolerance_changed",
    ):
        require(projection.get(field) is False, f"PROJECTION_FORBIDDEN:{field}")
    require(
        projection.get("r24d66_core_norm_squared_tolerance") == 1.0e-9
        and projection.get("r10b_exported_length_tolerance") == 1.0e-9,
        "PROJECTION_TOLERANCES",
    )

    changes = design.get("controlled_change_boundary", {})
    for field in (
        "new_lightweight_projection_module",
        "r10b_trace_policy_forward_versioned",
        "r10b_trace_row_schema_forward_versioned",
        "source_and_projected_quaternion_diagnostics_added",
        "exported_scalar_validator_round_trip_removed",
        "dependency_manifest_forward_versioned",
        "qualification_and_authority_schemas_forward_versioned",
        "consumed_l1_closure_bound_into_new_authority_graph",
    ):
        require(changes.get(field) is True, f"CONTROLLED_CHANGE_REQUIRED:{field}")
    for field in (
        "historical_r24d66_source_modified",
        "historical_r10b_l1_source_or_evidence_modified",
        "controller_changed",
        "fixture_changed",
        "challenge_changed",
        "impulse_changed",
        "behavior_threshold_changed",
        "quaternion_validator_quantity_changed",
        "quaternion_validator_tolerance_changed",
        "seed_changed",
        "population_changed",
        "evaluator_behavior_semantics_changed",
        "selector_changed",
        "outcome_derived_correction_added",
        "force_aware_recovery_added",
        "fall_recovery_added",
        "prone_to_standing_added",
    ):
        require(changes.get(field) is False, f"CONTROLLED_CHANGE_FORBIDDEN:{field}")

    controls = design.get("required_zero_world_controls", {})
    require(controls.get("exact_retained_raw_case_count") == 2, "CONTROL_RAW_CASES")
    require(
        controls.get("exact_retained_raw_refusal_count") == 2, "CONTROL_RAW_REFUSALS"
    )
    require(
        controls.get("exact_retained_projected_acceptance_count") == 2,
        "CONTROL_RETAINED_ACCEPTANCE",
    )
    require(
        controls.get("additional_nonidentity_projection_case_count") == 2,
        "CONTROL_ADDITIONAL_CASES",
    )
    require(
        controls.get("additional_nonidentity_projected_acceptance_count") == 2,
        "CONTROL_ADDITIONAL_ACCEPTANCE",
    )
    require(
        controls.get("zero_quaternion_structured_refusal_count") == 1,
        "CONTROL_ZERO_REFUSAL",
    )
    require(
        controls.get("projection_receipt_mutation_rejection_minimum") == 3,
        "CONTROL_MUTATIONS",
    )
    for counter in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(controls.get(counter) == 0, f"CONTROL_NONZERO:{counter}")
    require(
        controls.get("physical_acceptance_authority") is False,
        "CONTROL_PHYSICAL_AUTHORITY",
    )
    require(controls.get("release_authority") is False, "CONTROL_RELEASE_AUTHORITY")

    sequence = design.get("forward_authority_sequence", {})
    for field in (
        "new_clean_pushed_source_required",
        "new_official_zero_world_qualification_required",
        "stage_freeze_only_commit_required",
        "execution_authority_only_child_commit_required",
        "committed_graph_authority_check_required",
        "distinct_physical_output_identity_required",
        "physical_execution_blocked_until_sequence_complete",
    ):
        require(sequence.get(field) is True, f"SEQUENCE_REQUIRED:{field}")
    require(
        sequence.get("old_physical_identity_may_be_reused") is False,
        "SEQUENCE_OLD_IDENTITY",
    )
    require(sequence.get("held_out_cells_remain_sealed") is True, "SEQUENCE_HELDOUT")
    require(
        sequence.get("maximum_development_route_ghost_campaign_attempt_count") == 1,
        "SEQUENCE_ATTEMPTS",
    )
    require(
        sequence.get("maximum_development_route_ghost_world_count") == 2,
        "SEQUENCE_WORLDS",
    )
    require(
        sequence.get("ordered_development_route_ghost_cell_ids")
        == ["baseline_s50300", "push_s50300"],
        "SEQUENCE_CELLS",
    )

    claims = design.get("claim_boundary", {})
    require(claims.get("representation_repair_design_claimed") is True, "CLAIM_DESIGN")
    require(claims.get("r24d66_method_reuse_claimed") is True, "CLAIM_REUSE")
    for field in (
        "zero_world_control_result_claimed",
        "new_physical_result_claimed",
        "bounded_upright_push_recovery_claimed",
        "ordinary_walking_claimed",
        "external_push_effect_claimed",
        "fall_recovery_claimed",
        "prone_to_standing_claimed",
        "force_aware_recovery_claimed",
        "other_engine_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(field) is False, f"CLAIM_FORBIDDEN:{field}")

    binding_map(design)
    if verify_bindings:
        loaded = validate_bindings(design)
        validate_loaded_authorities(loaded)


def mutation_controls(design: dict[str, Any]) -> int:
    mutations: list[dict[str, Any]] = []
    for mutate in (
        lambda value: value["causal_basis"][
            "first_invalid_orientation_xyzw"
        ].__setitem__(0, 0.0),
        lambda value: value["causal_basis"][
            "maximum_delta_orientation_xyzw"
        ].__setitem__(3, 1.0),
        lambda value: value["selected_projection_contract"].__setitem__(
            "method_id", "wrong"
        ),
        lambda value: value["selected_projection_contract"].__setitem__(
            "r10b_validator_tolerance_changed", True
        ),
        lambda value: value["controlled_change_boundary"].__setitem__(
            "controller_changed", True
        ),
        lambda value: value["required_zero_world_controls"].__setitem__(
            "world_build_count", 1
        ),
        lambda value: value["forward_authority_sequence"].__setitem__(
            "old_physical_identity_may_be_reused", True
        ),
        lambda value: value["claim_boundary"].__setitem__(
            "bounded_upright_push_recovery_claimed", True
        ),
    ):
        candidate = copy.deepcopy(design)
        mutate(candidate)
        mutations.append(candidate)
    rejected = 0
    for candidate in mutations:
        try:
            validate_design(candidate, verify_bindings=False)
        except AuditFailure:
            rejected += 1
    require(rejected == len(mutations), "DESIGN_MUTATION_ACCEPTED")
    return rejected


def run_l1_closure_audit() -> dict[str, Any]:
    completed = subprocess.run(
        (sys.executable, "-B", L1_AUDIT_PATH),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=120,
    )
    require(completed.returncode == 0, "L1_CLOSURE_AUDIT_FAILED")
    lines = [
        line[len(L1_PASS_MARKER) :]
        for line in completed.stdout.splitlines()
        if line.startswith(L1_PASS_MARKER)
    ]
    require(len(lines) == 1, "L1_CLOSURE_AUDIT_MARKER_COUNT")
    receipt = json.loads(lines[0])
    require(
        isinstance(receipt, dict)
        and receipt.get("ok") is True
        and receipt.get("physical_identity_consumed") is True
        and receipt.get("same_identity_rerun_permitted") is False
        and receipt.get("selected_successor_id") == "QSDK-R10B-L2"
        and receipt.get("retained_world_build_count") == 1
        and receipt.get("push_world_attempt_count") == 0
        and receipt.get("valid_behavior_result_count") == 0,
        "L1_CLOSURE_AUDIT_RECEIPT",
    )
    return receipt


def main() -> int:
    try:
        validate_repository_identity()
        design = read_json(DESIGN_PATH, "L2_DESIGN")
        validate_design(design, verify_bindings=True)
        rejected = mutation_controls(design)
        l1_receipt = run_l1_closure_audit()
        receipt = {
            "schema_version": "sporespore_qsdk_r10b_l2_successor_design_audit_v1",
            "gate_id": "QSDK-R10B",
            "repair_id": "QSDK-R10B-L2",
            "ok": True,
            "failure_code": "",
            "bound_authority_count": 5,
            "design_mutation_rejection_count": rejected,
            "retained_raw_control_count": 2,
            "additional_nonidentity_control_count": 2,
            "zero_quaternion_refusal_control_count": 1,
            "qualified_projection_method_id": METHOD_ID,
            "l1_closure_audit_passed": True,
            "l1_retained_trace_row_count": l1_receipt["retained_trace_row_count"],
            "l1_quaternion_refusal_count": l1_receipt[
                "quaternion_tolerance_violating_row_count"
            ],
            "l1_physical_identity_consumed": True,
            "l1_same_identity_rerun_permitted": False,
            "controller_changed": False,
            "fixture_changed": False,
            "challenge_changed": False,
            "impulse_changed": False,
            "behavior_threshold_changed": False,
            "quaternion_validator_tolerance_changed": False,
            "seed_changed": False,
            "population_changed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "scene_tree_insertion_count": 0,
            "native_readback_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        print(PASS_MARKER + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
        return 0
    except (
        AuditFailure,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        subprocess.TimeoutExpired,
    ) as exc:
        print(f"QSDK_R10B_L2_SUCCESSOR_DESIGN_FAIL {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
