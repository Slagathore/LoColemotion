"""Compact source audit for the R24D49 producer-owned runtime binding."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
)


CONTRACT = ROOT / "sdk/recovery/r24d49_rapier_runtime_binding_contract_v1.json"
PARENT = "ba6a2a394b1c6aecfc3d7b1682dfe71cf07d4ac4"
R48_ROUTE = "sdk/adapters/rapier/src/qsdk_r24d48_recovery_energy_v2_route.rs"
R49_ROUTE = "sdk/adapters/rapier/src/qsdk_r24d49_runtime_binding_route.rs"
CLAIM_TRUE = (
    "r48_invalid_ghost_preserved",
    "producer_owned_runtime_binding_implemented",
    "runtime_binding_projection_non_self_referential",
    "launcher_recomputation_removed_for_r49",
    "r48_behavior_semantics_preserved",
)
CLAIM_FALSE = (
    "runtime_binding_qualified",
    "live_v2_recovery_route_physically_exercised_by_r49",
    "integration_ghost_passed",
    "paired_development_attempt_consumed",
    "controller_behavior_evaluated",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def region(source: str, start: str, end: str | None) -> str:
    begin = source.index(start)
    finish = len(source) if end is None else source.index(end, begin)
    return source[begin:finish]


def body(function: str) -> str:
    return function[function.index("{") + 1:function.rfind("}")]


def audit() -> None:
    contract = load(CONTRACT)
    contract_relative = CONTRACT.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--",
        contract_relative,
    )
    assert isinstance(publication, str)
    require(bool(publication), "CONTRACT_PUBLICATION")
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d49_rapier_runtime_binding_contract_v1",
        "gate_id": "QSDK-R24D49",
        "status": (
            "prospective_runtime_binding_successor_implemented_"
            "zero_world_qualification_and_physics_blocked"
        ),
        "authored_parent_commit": PARENT,
        "question_class": "development",
        "physical_question_declared": True,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "predecessor.gate_id": "QSDK-R24D48",
        "predecessor.invalid_ghost_result": (
            "invalid_pre_world_runtime_qualification_digest_representation_mismatch"
        ),
        "predecessor.invalid_ghost_actual_outer_steps": 0,
        "predecessor.invalid_ghost_may_be_rerun": False,
        "scope.engine": "rapier_parry_native",
        "scope.behavior_lineage_gate_id": "QSDK-R24D48",
        "controlled_change.runtime_digest_transport_change_count": 1,
        "controlled_change.controller_change_count": 0,
        "controlled_change.threshold_change_count": 0,
        "controlled_change.selector_change_count": 0,
        "controlled_change.evaluator_change_count": 0,
        "runtime_binding.producer": "rust_zero_world_preflight",
        "runtime_binding.projection_field_count": 12,
        "runtime_binding.non_self_referential_required": True,
        "runtime_binding.launcher_recomputation_permitted": False,
        "runtime_binding.mutation_rejection_count": 4,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
        "staged_physical_execution.integration_ghost.maximum_total_outer_steps": 4,
        "staged_physical_execution.paired_development.maximum_total_outer_steps": 2400,
    }, "CONTRACT")
    invalid_path = ROOT / contract["predecessor"]["invalid_ghost_closure_path"]
    exact(sha256(invalid_path.read_bytes()),
          contract["predecessor"]["invalid_ghost_closure_raw_sha256"],
          "INVALID_PREDECESSOR_HASH")
    invalid = load(invalid_path)
    exact(invalid["decision"]["result"],
          contract["predecessor"]["invalid_ghost_result"],
          "INVALID_PREDECESSOR_RESULT")
    exact(invalid["physical_attempt"]["actual_total_outer_steps"], 0,
          "INVALID_PREDECESSOR_STEPS")

    historical = source_bytes(ROOT, PARENT, R48_ROUTE).decode("utf-8")
    current = source_bytes(ROOT, publication, R48_ROUTE).decode("utf-8")
    ghost_signature = "pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_ghost("
    development_signature = (
        "pub fn run_qsdk_r24d48_rapier_recovery_energy_v2_development_attempt("
    )
    exact(current[:current.index(ghost_signature)],
          historical[:historical.index(ghost_signature)], "R48_PREFIX_UNCHANGED")

    historical_ghost = body(region(
        historical, ghost_signature,
        "/// Execute the prospectively declared finite paired Rapier development attempt.",
    ))
    historical_ghost = historical_ghost.replace(
        "\n    validate_runtime_qualification_sha256(runtime_qualification_sha256)?;",
        "", 1,
    )
    current_ghost = body(region(
        current,
        "pub(crate) fn run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(",
        "/// Execute the prospectively declared finite paired Rapier development attempt.",
    ))
    exact(current_ghost, historical_ghost, "R48_GHOST_MECHANICS_UNCHANGED")

    historical_development = body(region(historical, development_signature, None))
    historical_development = historical_development.replace(
        "\n    validate_runtime_qualification_sha256(runtime_qualification_sha256)?;",
        "", 1,
    )
    current_development = body(region(
        current,
        "pub(crate) fn run_qsdk_r24d48_rapier_recovery_energy_v2_development_after_runtime_binding_v1(",
        None,
    ))
    exact(current_development, historical_development,
          "R48_DEVELOPMENT_MECHANICS_UNCHANGED")
    require_ordered_markers(region(current, ghost_signature,
                                   "/// Preserve the exact R24D48 physical mechanics"), (
        "validate_runtime_qualification_sha256(runtime_qualification_sha256)?;",
        "run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(",
    ), "R48_WRAPPER_ORDER")

    r49 = source_bytes(ROOT, publication, R49_ROUTE).decode("utf-8")
    require_ordered_markers(r49, (
        "fn runtime_binding_projection_v1()",
        '"schema_version": PROJECTION_SCHEMA',
        '"contract_raw_sha256": raw_sha256(CONTRACT_RAW.as_bytes())',
        '"behavior_lineage_gate_id": R24D48_GATE_ID',
        "fn expected_runtime_binding_sha256()",
        "digest_json(&runtime_binding_projection_v1()?)",
        "fn validate_runtime_binding_sha256(observed: &str)",
        "pub fn run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification()",
        'projection.get("runtime_binding_sha256").is_some()',
        '"runtime_binding_sha256": runtime_binding_sha256',
        "pub fn run_qsdk_r24d49_rapier_recovery_energy_v2_ghost(",
        "validate_runtime_binding_sha256(runtime_binding_sha256)?;",
        "run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(",
    ), "R49_BINDING_ORDER")
    for forbidden in (
        "fn run_arm(", "fn evaluate_paired_traces(",
        "compile_r24d45_recovery_boundary_v1", "build_r24d45_recovery_world_v1",
    ):
        require(forbidden not in r49, f"R49_BEHAVIOR_DUPLICATION:{forbidden}")
    exact(r49.count("mutated_projection_digest_differs("), 2,
          "RUNTIME_BINDING_MUTATION_LOOP")
    for mutation_id in contract["runtime_binding"]["mutation_ids"]:
        require(f'"{mutation_id}"' in r49,
                f"RUNTIME_BINDING_MUTATION_SOURCE:{mutation_id}")

    shared = source_bytes(
        ROOT, publication, contract["physical_runner"]["shared_script_path"]
    ).decode("utf-8")
    require_ordered_markers(shared, (
        "$ContractRelativePath",
        "$runtimeBindingField",
        "runtime_binding_closure_json_pointer",
        "$ghostEntrypoint",
        "sporespore_rapier_adapter::$ghostEntrypoint(",
        "[string]$result[$runtimeBindingField]",
    ), "SHARED_PHYSICAL_RUNNER")
    wrapper = source_bytes(
        ROOT, publication, contract["physical_runner"]["script_path"]
    ).decode("utf-8")
    require_ordered_markers(wrapper, (
        'run_qsdk_r24d48_rapier_recovery_energy_v2.ps1',
        "ContractRelativePath =",
        'r24d49_rapier_runtime_binding_contract_v1.json',
        "& $shared @forward",
    ), "R49_PHYSICAL_WRAPPER")

    exact(len(contract["runtime_binding"]["mutation_ids"]), 4, "MUTATION_COUNT")
    exact(len(set(contract["runtime_binding"]["mutation_ids"])), 4,
          "MUTATION_IDENTITY")
    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    verify_boolean_partition(contract["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    verify_legacy_live_gate_paths(
        ROOT, contract["live_authority_paths"], contract["live_gate_carrier_id"],
        contract["live_gate_expectations"],
        revision=publication,
    )
    print(
        "QSDK_R24D49_RAPIER_RUNTIME_BINDING_SOURCE_PASS "
        "projection=12 mutations=4 behavior_delta=0 worlds=0 solver_steps=0 "
        "physical=false next=QSDK-R24D49:qualification"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D49_RAPIER_RUNTIME_BINDING_SOURCE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
