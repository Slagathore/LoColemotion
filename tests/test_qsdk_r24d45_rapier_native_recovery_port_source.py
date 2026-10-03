from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "sdk/recovery/r24d45_rapier_native_recovery_port_contract_v1.json"
CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/r24d45_rapier_native_recovery_port_negative_closure_v1.json"
)
RELEASE_PATH = ROOT / "sdk/release/quadruped_release_contract.json"
SUPPORT_PATH = ROOT / "sdk/release/quadruped_support_matrix.json"
ABI_PATH = ROOT / "sdk/versioning/c_abi_manifest_v1.json"
SCHEMA_PATH = ROOT / "sdk/versioning/schema_registry_v1.json"
EXPECTED_STATUS = "closed_valid_complete_negative_raise_body_timeout_energy_residual_boundary"
EXPECTED_CLOSURE_SHA256 = (
    "sha256:156f358481160e8937f2c48d2c0dbd206fbe4ec6974a693c6ff5569a55372fcd"
)
EXPECTED_QUALIFICATION_SHA256 = (
    "sha256:68235c51c019ee7bfeb7fd2a43ee86cdd2a8b3aeee9342c2b6022625a4ca7f90"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AssertionError(code)


def require_items(actual: dict, expected: dict, code: str) -> None:
    require(
        all(actual.get(key) == value for key, value in expected.items()),
        code,
    )


def git_paths(*args: str) -> set[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return {line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()}


def find_gate(value: object, gate_id: str) -> dict | None:
    if isinstance(value, dict):
        if value.get("gate_id") == gate_id:
            return value
        for child in value.values():
            found = find_gate(child, gate_id)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_gate(child, gate_id)
            if found is not None:
                return found
    return None


def main() -> int:
    contract = load(CONTRACT_PATH)
    closure = load(CLOSURE_PATH)
    require(contract["gate_id"] == "QSDK-R24D45", "GATE_ID")
    require(contract["status"] == EXPECTED_STATUS, "STATUS")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    classification = contract["physical_question_classification"]
    require(
        classification["work_type"] == "development"
        and classification["physical_question_declared"] is True
        and classification["physical_execution_currently_authorized"] is False
        and classification["superiority_question_declared"] is False
        and classification["equivalence_or_non_inferiority_question_declared"] is False,
        "PHYSICAL_QUESTION_CLASSIFICATION",
    )

    inventory = set(contract["source_inventory"])
    closure_relative = CLOSURE_PATH.relative_to(ROOT).as_posix()
    frozen_source_inventory = inventory - {closure_relative}
    source_commit = closure["source_commit"]
    changed = git_paths(
        "diff", "--name-only", contract["declaration_parent_commit"], source_commit
    )
    retained_paths = git_paths("ls-tree", "-r", "--name-only", source_commit)
    require(
        changed == frozen_source_inventory
        and len(inventory) == contract["source_inventory_count"] == 25
        and frozen_source_inventory.issubset(retained_paths)
        and CLOSURE_PATH.is_file(),
        "SOURCE_INVENTORY",
    )

    cell = contract["development_cohort"]["cells"][0]
    digest = hashlib.sha256(cell["seed_label"].encode("utf-8")).digest()
    seed = int.from_bytes(digest[:4], "big") & 0x7FFFFFFF
    require(
        cell["seed_sha256"] == f"sha256:{digest.hex()}"
        and cell["seed"] == seed == 260226999
        and cell["engine"] == "rapier_parry_native",
        "DEVELOPMENT_SEED_PROVENANCE",
    )
    seal = contract["held_out_seal"]
    require(
        seal["r17_held_out_access_count"] == 0
        and seal["r17_held_out_selector_invocation_count"] == 0
        and seal["r17_held_out_cells_remain_sealed"] is True
        and seal["development_access_permitted"] is False,
        "HELD_OUT_SEAL",
    )

    abi = load(ABI_PATH)["symbols"]
    abi_names = {entry["name"] for entry in abi}
    schemas = {entry["schema_id"] for entry in load(SCHEMA_PATH)["schemas"]}
    kernel = contract["shared_stance_kernel"]
    require(
        len(abi_names) == kernel["public_c_abi_symbol_count_total"] == 51
        and set(kernel["public_c_abi_symbols"]).issubset(abi_names)
        and len(schemas) == kernel["schema_registry_entry_count_total"] == 79
        and set(kernel["request_schemas"]).issubset(schemas),
        "PUBLIC_VERSIONED_SURFACE",
    )

    core = (ROOT / "sdk/core/src/recovery_runtime.rs").read_text(encoding="utf-8")
    ffi = (ROOT / "sdk/core/src/ffi.rs").read_text(encoding="utf-8")
    rapier = (ROOT / "sdk/adapters/rapier/src/recovery_runtime.rs").read_text(
        encoding="utf-8"
    )
    route = (
        ROOT / "sdk/adapters/rapier/src/qsdk_r24d45_recovery_route.rs"
    ).read_text(encoding="utf-8")
    binary = (
        ROOT / "sdk/adapters/rapier/src/bin/qsdk_r24d45_recovery_route.rs"
    ).read_text(encoding="utf-8")
    locomotion = (ROOT / "sdk/adapters/rapier/src/locomotion.rs").read_text(
        encoding="utf-8"
    )
    for version in ("v1", "v2", "v3"):
        require(
            f"pub fn plan_recovery_stance_control_{version}" in core
            and f"ss_recovery_plan_stance_control_{version}_json" in ffi,
            f"SHARED_STANCE_SURFACE:{version}",
        )
    require(
        "pub fn plan_rapier_recovery_stance_control_v1" in rapier
        and "plan_recovery_stance_control_v1" in rapier
        and "stance_control_surface_implemented" in rapier,
        "RAPIER_STANCE_SURFACE",
    )
    foundation = contract["native_route_foundation"]
    require(
        foundation["canonical_prone_pose_plan_implemented"] is True
        and foundation["recovery_control_to_public_profile_mapping_implemented"]
        is True
        and foundation["mapping_forced_failure_count"] == 6
        and foundation["in_run_invariant_forced_failure_count"] == 6
        and foundation["total_route_forced_failure_count"] == 12
        and foundation["native_world_construction_implemented"] is True
        and foundation["native_observation_collection_implemented"] is True
        and foundation["native_actuation_application_and_readback_implemented"]
        is True
        and foundation["streaming_in_run_invariant_validator_implemented"] is True
        and foundation["paired_development_entrypoint_implemented"] is True
        and foundation["official_model_construction_count"] == 2
        and foundation["official_world_attempt_count"] == 2
        and foundation["official_world_build_count"] == 2
        and foundation["official_solver_step_count"] == 1023
        and foundation["official_physics_state_modified"] is True
        and "plan_r24d45_canonical_prone_pose_v1" in route
        and "map_r24d45_recovery_control_to_public_profile_v1" in route
        and "mapping_mutation_controls" in route,
        "NATIVE_ROUTE_FOUNDATION",
    )
    require(
        "build_r24d45_recovery_world_v1" in route
        and "collect_r24d45_native_step_v1" in route
        and "apply_and_step_r24d45_recovery_v1" in route
        and "validate_r24d45_in_run_step_v1" in route
        and "invariant_mutation_controls" in route
        and "run_qsdk_r24d45_rapier_recovery_development_attempt" in route
        and '"development" =>' in binary
        and "pub(crate) solver_step_count" in locomotion,
        "NATIVE_EXECUTION_ROUTE",
    )

    for path in (RELEASE_PATH, SUPPORT_PATH):
        live = find_gate(load(path), "QSDK-R24D45")
        require(live is not None, f"LIVE_GATE_MISSING:{path.name}")
        require(
            live["status"] == EXPECTED_STATUS
            and live["contract_path"]
            == "sdk/recovery/r24d45_rapier_native_recovery_port_contract_v1.json"
            and live["selected_native_engine"] == "rapier_parry_native"
            and live["r24d45_shared_stance_kernel_implemented"] is True
            and live["r24d45_rapier_native_route_implemented"] is True
            and live["r24d45_total_route_forced_failure_count"] == 12
            and live["r24d45_ghost_attempt_count"] == 2
            and live["r24d45_ghost_route_passed"] is True
            and live["r24d45_zero_world_qualification_pending"] is False
            and live["r24d45_official_zero_world_qualification_passed"] is True
            and live["r24d45_official_zero_world_qualification_process_count"] == 1
            and live["r24d45_zero_world_qualification_rerun_count"] == 0
            and live["r24d45_qualification_receipt_canonical_sha256"]
            == EXPECTED_QUALIFICATION_SHA256
            and live["r24d45_qualification_postprocess_wrapper_invalid_count"] == 1
            and live["r24d45_qualification_postprocess_wrapper_correction_count"]
            == 1
            and live["r24d45_physical_attempt_consumed"] is True
            and live["r24d45_physical_attempt_valid"] is True
            and live["r24d45_decision_positive"] is False
            and live["r24d45_result_classification"]
            == "valid_complete_negative_exact_nominal_rapier_development"
            and live["r24d45_candidate_outer_step_count"] == 771
            and live["r24d45_matched_zero_outer_step_count"] == 252
            and live["r24d45_total_outer_step_count"] == 1023
            and live["r24d45_total_native_solver_step_count"] == 1023
            and live["r24d45_model_construction_count"] == 2
            and live["r24d45_world_attempt_count"] == 2
            and live["r24d45_safety_gate_observation_count"] == 0
            and live["r24d45_limiting_observed_gate_component"]
            == "energy_balance_residual"
            and live["r24d45_may_be_rerun_or_requalified"] is False
            and live["r24d45_closure_raw_sha256"] == EXPECTED_CLOSURE_SHA256
            and live["physical_execution_authorized"] is False
            and live["maximum_physical_steps_authorized"] == 0
            and live["held_out_cells_remain_sealed"] is True,
            f"LIVE_GATE:{path.name}",
        )

    ghost = contract["ghost_contract"]
    gate = contract["zero_world_gate"]
    claim = contract["claim_boundary"]
    require(
        ghost["maximum_total_outer_steps"] == 4
        and ghost["full_seeded_horizon_required"] is False
        and ghost["result_may_satisfy_r24d45"] is False
        and gate["qualification_may_construct_or_step_a_world"] is False
        and gate["qualification_result_pending"] is False
        and gate["official_qualification_passed"] is True
        and gate["official_qualification_process_count"] == 1
        and gate["qualification_rerun_count"] == 0
        and gate["qualification_receipt_canonical_sha256"]
        == EXPECTED_QUALIFICATION_SHA256
        and gate["postprocess_wrapper_invalid_count"] == 1
        and gate["postprocess_wrapper_correction_count"] == 1
        and gate["postprocess_wrapper_error_preserved"] is True
        and gate["native_prone_initializer_source_implemented"] is True
        and gate["native_public_profile_mapping_source_implemented"] is True
        and gate["native_observation_source_implemented"] is True
        and gate["native_actuation_readback_source_implemented"] is True
        and gate["in_run_invariant_validator_source_implemented"] is True
        and gate["total_mutation_rejection_count"] == 12
        and claim["rapier_prone_initializer_source_implemented"] is True
        and claim["rapier_public_profile_mapping_source_implemented"] is True
        and claim["rapier_prone_world_route_implemented"] is True
        and claim["rapier_route_ghost_integration_passed"] is True
        and claim["official_zero_world_qualification_passed"] is True
        and claim["official_physical_attempt_opened"] is True
        and claim["official_physical_attempt_consumed"] is True
        and claim["official_physical_attempt_valid"] is True
        and claim["official_physical_result_positive"] is False
        and claim["rapier_recovery_control_physically_executed"] is True
        and claim["rapier_raised_body_gate_observed"] is True
        and claim["rapier_safety_gate_observed"] is False
        and claim["rapier_prone_to_standing_observed"] is False
        and claim["sdk1_completed_steps"] == 11
        and claim["sdk1_total_steps"] == 20
        and claim["physical_acceptance_authority"] is False
        and claim["release_authority"] is False,
        "CLAIM_BOUNDARY",
    )

    closure_sha256 = f"sha256:{hashlib.sha256(CLOSURE_PATH.read_bytes()).hexdigest()}"
    require(closure_sha256 == EXPECTED_CLOSURE_SHA256, "CLOSURE_DIGEST")
    require_items(
        closure,
        {
            "gate_id": "QSDK-R24D45",
            "question_class": "development",
            "status": EXPECTED_STATUS,
            "source_commit": "3b72261066042b61b8f77f4ed2aaaef64aa0c4e5",
            "source_was_clean_pushed_and_live_remote_equal": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "CLOSURE_IDENTITY",
    )
    require_items(
        closure["qualification"],
        {
            "official_qualification_process_count": 1,
            "qualification_rerun_count": 0,
            "process_exit_code": 0,
            "result": "valid_complete_zero_world_positive",
            "receipt_canonical_sha256": EXPECTED_QUALIFICATION_SHA256,
            "total_mutation_rejection_count": 12,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "solver_step_count": 0,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "postprocess_wrapper_invalid_count": 1,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "QUALIFICATION_CLOSURE",
    )
    require_items(
        closure["physical_attempt"],
        {
            "official_attempt_count": 1,
            "physical_attempt_rerun_count": 0,
            "additional_attempt_authorized": False,
            "process_exit_code": 0,
            "result_classification": "valid_complete_negative_exact_nominal_rapier_development",
            "evaluator_verdict": "physical_development_failed",
            "physical_development_trace_valid": True,
            "initial_state_identity_matched": True,
            "actual_total_outer_steps": 1023,
            "actual_total_native_solver_steps": 1023,
            "model_construction_count": 2,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "held_out_cell_access_count": 0,
            "held_out_selector_invocation_count": 0,
            "threshold_change_count": 0,
            "prone_to_standing_claimed": False,
        },
        "PHYSICAL_CLOSURE",
    )
    require_items(
        closure["observed_trajectory"],
        {
            "first_geometric_stance_excluding_owner_and_energy_step": 528,
            "geometric_stance_excluding_owner_and_energy_observation_count": 244,
            "first_raised_body_gate_step": 726,
            "raised_body_gate_observation_count": 46,
            "safety_gate_observation_count": 0,
            "first_energy_residual_failure_step": 28,
            "final_energy_balance_residual_j": 11.181510863482373,
            "maximum_energy_balance_residual_j": 0.25,
            "limiting_observed_gate_component": "energy_balance_residual",
            "actuator_work_observer_defect_proven": False,
            "controller_failure_proven": False,
        },
        "OBSERVED_TRAJECTORY",
    )
    require_items(
        contract["observed_result"],
        {
            "closure_raw_sha256": EXPECTED_CLOSURE_SHA256,
            "result_classification": "valid_complete_negative_exact_nominal_rapier_development",
            "candidate_outer_step_count": 771,
            "matched_zero_outer_step_count": 252,
            "actual_total_native_solver_steps": 1023,
            "limiting_observed_gate_component": "energy_balance_residual",
            "r24d45_may_be_requalified": False,
            "r24d45_may_be_rerun": False,
            "successor_must_be_scientifically_distinct": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "CONTRACT_OBSERVED_RESULT",
    )
    print(
        "QSDK_R24D45_RAPIER_NATIVE_RECOVERY_PORT_CLOSURE_PASS "
        "selection=rapier qualification=pass decision=negative "
        "candidate=771 zero=252 worlds=2 steps=1023 "
        "limiting=energy_residual heldout=sealed sdk1=11/20 full=11/25"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
