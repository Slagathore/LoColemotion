"""Compact declarative source audit for prospective QSDK-R24D42."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
)

GATE = "QSDK-R24D42"
CAMPAIGN = "QSDK-R24D42-MUJOCO-OBSERVATION-V2-NATURAL-RECOVERY-PROGRESSION"
CONTRACT_RELATIVE = (
    "sdk/recovery/r24d42_mujoco_observation_v2_natural_progression_contract_v1.json"
)
CONTRACT_PATH = ROOT / CONTRACT_RELATIVE
R32_CONTRACT = ROOT / "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json"
R32_CLOSURE = (
    ROOT / "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json"
)
R32_AUDIT = ROOT / "tests/test_qsdk_r24d32_corrected_energy_progression_physical_closure.py"
R41_CLOSURE = (
    ROOT
    / "sdk/recovery/"
    "r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1.json"
)
R41_AUDIT = (
    ROOT / "tests/test_qsdk_r24d41_observation_v2_morphology_smoke_positive_closure.py"
)
RELEASE_RELATIVE = "sdk/release/quadruped_release_contract.json"
SUPPORT_RELATIVE = "sdk/release/quadruped_support_matrix.json"
MAPPING_RELATIVE = "sdk/release/quadruped_sdk1_milestone_mapping_v1.json"

EXPECTED_INVENTORY = (
    "docs/README.md",
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
    "docs/LOCOMOTION_ARCHITECTURE.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    "sdk/adapters/mujoco/README.md",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/bounded_recovery_route_smoke.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d18_recovery_development_worker.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d27_natural_recovery_progression_worker.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d40_observation_v2_native_smoke_worker.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d41_observation_v2_morphology_smoke_worker.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_morphology_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_streaming_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_morphology_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_observation_v2_route_fixture.py",
    "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json",
    "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json",
    "tests/test_qsdk_r24d32_corrected_energy_progression_physical_closure.py",
    "sdk/recovery/r24d40_mujoco_observation_v2_native_smoke_invalid_closure_v1.json",
    "tests/test_qsdk_r24d40_observation_v2_native_smoke_invalid_closure.py",
    "sdk/recovery/r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1.json",
    "sdk/recovery/r24d41_mujoco_recovery_morphology_observation_v2_smoke_positive_closure_v1.json",
    "tests/test_qsdk_r24d41_observation_v2_morphology_smoke_positive_closure.py",
    "sdk/conformance/content_addressed_zero_world_closure.py",
    "sdk/core/src/recovery_runtime.rs",
    RELEASE_RELATIVE,
    MAPPING_RELATIVE,
    SUPPORT_RELATIVE,
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d42_observation_v2_natural_progression_worker.py",
    CONTRACT_RELATIVE,
    "sdk/run_qsdk_r24d42_observation_v2_natural_progression.ps1",
    "sdk/run_qsdk_r24d42_observation_v2_natural_progression_zero_world.ps1",
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
    "sdk/run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
    "tests/test_qsdk_r24d42_observation_v2_natural_progression_source.py",
)


def _text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def _json(relative: str) -> dict[str, Any]:
    value = json.loads((ROOT / relative).read_bytes())
    require(isinstance(value, dict), f"JSON_ROOT:{relative}")
    return value


def _contains_all(source: str, markers: tuple[str, ...], code: str) -> None:
    missing = [marker for marker in markers if marker not in source]
    require(not missing, f"{code}:missing={missing}")


def _find_gate(value: object) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("gate_id") == GATE:
            found.append(value)
        for child in value.values():
            found.extend(_find_gate(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(_find_gate(child))
    return found


def audit() -> None:
    contract = load(CONTRACT_PATH)
    exact(
        (
            contract["gate_id"],
            contract["campaign_id"],
            contract["question_class"],
            contract["physical_question_declared"],
            contract["behavior_question_declared"],
        ),
        (GATE, CAMPAIGN, "development", True, True),
        "CONTRACT_IDENTITY",
    )

    lineage = contract["lineage"]
    exact(
        lineage["behavior_predecessor_contract_raw_sha256"],
        sha256(R32_CONTRACT.read_bytes()),
        "R32_CONTRACT",
    )
    exact(
        lineage["behavior_predecessor_closure_raw_sha256"],
        sha256(R32_CLOSURE.read_bytes()),
        "R32_CLOSURE",
    )
    exact(
        lineage["behavior_predecessor_closure_audit_raw_sha256"],
        sha256(R32_AUDIT.read_bytes()),
        "R32_AUDIT",
    )
    exact(
        lineage["route_predecessor_closure_raw_sha256"],
        sha256(R41_CLOSURE.read_bytes()),
        "R41_CLOSURE",
    )
    exact(
        lineage["route_predecessor_closure_audit_raw_sha256"],
        sha256(R41_AUDIT.read_bytes()),
        "R41_AUDIT",
    )
    require(lineage["behavior_predecessor_may_rerun"] is False, "R32_REOPEN")
    require(lineage["route_predecessor_may_rerun"] is False, "R41_REOPEN")
    require(
        not any(
            lineage[field]
            for field in (
                "historical_result_rewritten",
                "historical_threshold_rewritten",
                "historical_selector_rewritten",
                "historical_evaluator_rewritten",
                "historical_interpretation_rewritten",
            )
        ),
        "HISTORICAL_REWRITE",
    )

    inventory = tuple(contract["source_inventory"])
    exact(inventory, EXPECTED_INVENTORY, "SOURCE_INVENTORY")
    exact(
        contract["prospective_freeze"]["source_inventory_count"],
        37,
        "INVENTORY_COUNT",
    )
    require(len(inventory) == len(set(inventory)), "INVENTORY_DUPLICATE")
    require(all((ROOT / item).is_file() for item in inventory), "INVENTORY_MISSING")

    route = contract["route_identity"]
    exact(
        (
            route["world_type"],
            route["native_source_route_id"],
            route["publication_route_id"],
            route["mapping_profile_id"],
            route["portable_observation_schema"],
            route["core_build_profile"],
        ),
        (
            "MujocoRecoveryMorphologyStreamingObservationV2World",
            "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3",
            "sporespore_mujoco_exact_s169_recovery_observation_v2_streaming_consumer_v1",
            "mujoco_r24d36_native_components_to_recovery_energy_v2_streaming_v1",
            "sporespore_recovery_observation_v2",
            "release",
        ),
        "ROUTE_IDENTITY",
    )
    change = contract["controlled_change"]
    require(
        all(
            change[field]
            for field in (
                "route_changed_since_r24d41",
                "observation_v2_publication_semantics_changed_since_r24d41",
                "in_run_invariant_semantics_changed_since_r24d41",
                "mapping_profile_and_source_digest_chain_changed_since_r24d41",
                "core_build_profile_changed_from_shared_runner_default",
            )
        ),
        "CHANGED_SURFACE_UNDECLARED",
    )
    require(
        not any(
            change[field]
            for field in (
                "portable_observation_schema_changed_since_r24d41",
                "controller_changed",
                "native_physics_changed",
                "morphology_changed",
                "initializer_changed",
                "selected_cell_changed",
                "seed_changed",
                "behavior_thresholds_changed",
                "margins_changed",
                "historical_result_changed",
                "historical_interpretation_changed",
            )
        ),
        "UNCHANGED_SURFACE_CHANGED",
    )

    stream = contract["linear_content_addressed_streaming_publication"]
    exact(
        (
            stream["current_native_component_receipt_count"],
            stream["prior_native_history_copied_or_replayed_in_current_step"],
            stream["post_run_legacy_full_aggregate_execution_count_per_arm"],
            stream["post_run_legacy_full_aggregate_numeric_parity_required"],
            stream["physical_value_dropped"],
        ),
        (5, False, 1, True, False),
        "STREAMING_AUTHORITY",
    )
    gate = contract["complete_zero_world_gate"]
    exact(
        (
            gate["required_control_count"],
            gate["forced_failure_count"],
            gate["world_attempt_count"],
            gate["solver_step_count"],
            gate["historical_closure_audits_reexecuted"],
        ),
        (9, 21, 0, 0, False),
        "ZERO_WORLD_GATE",
    )
    exact(
        (
            contract["ghost_horizon"]["outer_steps_per_arm"],
            contract["ghost_horizon"]["maximum_total_outer_steps"],
            contract["ghost_horizon"]["maximum_total_native_solver_steps"],
            contract["threshold_margin_and_population_provenance"][
                "maximum_energy_balance_residual_j"
            ],
        ),
        (1200, 2400, 12000, 0.25),
        "FINITE_PHYSICAL_BOUNDS",
    )

    worker_relative = (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
        "qsdk_r24d42_observation_v2_natural_progression_worker.py"
    )
    stream_relative = (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
        "recovery_observation_v2_streaming_route.py"
    )
    publication_relative = (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
        "recovery_observation_v2_route.py"
    )
    for relative in (worker_relative, stream_relative, publication_relative):
        source = _text(relative)
        compile(source, str(ROOT / relative), "exec")

    worker = _text(worker_relative)
    _contains_all(
        worker,
        (
            "_streaming_mapping_controls",
            "numeric_parity_prefixes",
            "validate_streaming_publication_in_run_v1",
            "final_legacy_full_aggregate_numeric_parity",
            "MujocoRecoveryMorphologyStreamingObservationV2World",
            "behavior_claim_authority=False",
        ),
        "WORKER_TOPOLOGY",
    )
    require("native_receipt_projector" not in worker, "WORKER_PROJECTOR_RETAINED")
    require("publication_retention" not in worker, "WORKER_OLD_RETENTION_RETAINED")

    streaming_source = _text(stream_relative)
    _contains_all(
        streaming_source,
        (
            "content_addressed_prior_state_plus_current_native_batch",
            '"prior_history_replayed_in_current_step": False',
            "validate_streaming_state_v1",
            "current_batch_component_mappings",
            "prior_source_chain_sha256",
            "validate_streaming_morphology_route_v1",
        ),
        "STREAMING_ROUTE",
    )
    require(
        "ordered_native_component_batches" not in streaming_source,
        "STREAMING_HISTORY_ARRAY",
    )

    runtime_source = _text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/native_recovery_development.py"
    )
    require("native_receipt_projector" not in runtime_source, "SHARED_RUNTIME_PROJECTOR")
    core_source = _text("sdk/core/src/recovery_runtime.rs")
    _contains_all(
        core_source,
        (
            "MUJOCO_R24D42_STREAMING_ENERGY_V2_MAPPING_PROFILE_ID",
            "mapping_profile_supported",
            "!= source.mapping_profile_id",
            "crossed_profiles",
        ),
        "CORE_PROFILE_BINDING",
    )
    publication_source = _text(publication_relative)
    _contains_all(
        publication_source,
        (
            "publish_recovery_observation_v2_mapping_v1",
            'ledger.get("source_profile_id") == mapping_profile_id',
            'mapping.get("mapping_profile_id") == mapping_profile_id',
        ),
        "PUBLICATION_PROFILE_BINDING",
    )

    wrappers = {
        "sdk/run_qsdk_r24d42_observation_v2_natural_progression_zero_world.ps1": (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1",
        ),
        "sdk/run_qsdk_r24d42_observation_v2_natural_progression.ps1": (
            'CoreBuildProfile "release"',
            "run_qsdk_r24d18_mujoco_native_recovery_development.ps1",
        ),
        "sdk/run_qsdk_r24d18_mujoco_native_recovery_zero_world.ps1": (
            'ValidateSet("debug", "release")',
            "core_build_profile = $CoreBuildProfile",
        ),
        "sdk/run_qsdk_r24d18_mujoco_native_recovery_development.ps1": (
            'ValidateSet("debug", "release")',
            "core_library_raw_sha256",
        ),
    }
    for relative, markers in wrappers.items():
        _contains_all(_text(relative), markers, f"WRAPPER:{relative}")

    release = _json(RELEASE_RELATIVE)
    support = _json(SUPPORT_RELATIVE)
    release_nodes = _find_gate(release)
    support_nodes = _find_gate(support)
    require(len(release_nodes) == len(support_nodes) == 1, "R24D42_NODE_COUNT")
    for node in (release_nodes[0], support_nodes[0]):
        exact(
            (
                node["contract_path"],
                node["r24d42_source_inventory_count"],
                node["r24d42_required_control_count"],
                node["r24d42_forced_failure_count"],
                node["r24d42_world_type"],
                node["r24d42_mapping_profile_id"],
                node["r24d42_core_build_profile"],
                node["r24d42_prior_history_replayed_in_current_step"],
                node["r24d42_physical_observation_or_value_dropped"],
            ),
            (
                CONTRACT_RELATIVE,
                37,
                9,
                21,
                route["world_type"],
                route["mapping_profile_id"],
                "release",
                False,
                False,
            ),
            "RELEASE_SUPPORT_NODE",
        )
        exact(
            node["r24d42_development_zero_world_gate_passed"],
            contract["claim_boundary"]["development_zero_world_gate_passed"],
            "DEVELOPMENT_GATE_STATE",
        )
        require(
            node["physical_execution_blocked_until_r24d42_qualification_passes"],
            "PHYSICS_UNBLOCKED",
        )
        require(node["release_authority"] is False, "RELEASE_AUTHORITY")

    mapping = _json(MAPPING_RELATIVE)
    authority = mapping["full_program_authority"]
    exact(
        authority["release_contract_raw_sha256"],
        sha256((ROOT / RELEASE_RELATIVE).read_bytes()),
        "MAPPING_RELEASE_HASH",
    )
    exact(
        authority["support_matrix_raw_sha256"],
        sha256((ROOT / SUPPORT_RELATIVE).read_bytes()),
        "MAPPING_SUPPORT_HASH",
    )
    exact(mapping["sdk1_contract"]["milestone_count"], 20, "SDK1_DENOMINATOR")

    for relative in EXPECTED_INVENTORY[:6]:
        source = _text(relative)
        require("R24D42" in source, f"DOC_R24D42:{relative}")
        require(
            "11/20" in source and "11/25" in source,
            f"DOC_COUNTS:{relative}",
        )

    claims = contract["claim_boundary"]
    require(
        not any(
            claims[field]
            for field in (
                "new_physical_observation_made",
                "recovery_progression_proven",
                "recovery_to_stance_handoff_observed",
                "controller_physical_viability_proven",
                "prone_to_standing_claimed",
                "repeatability_rate_claimed",
                "population_claimed",
                "cross_engine_equivalence_claimed",
                "sdk1_milestone_advanced",
                "physical_acceptance_authority",
                "release_authority",
            )
        ),
        "CLAIM_OVERREACH",
    )
    exact(
        (claims["sdk1_release_readiness"], claims["full_program_readiness"]),
        ("11/20", "11/25"),
        "READINESS",
    )


def main() -> int:
    audit()
    print(
        "QSDK_R24D42_OBSERVATION_V2_NATURAL_PROGRESSION_SOURCE_PASS "
        "inventory=37 controls=9 forced_failures=21 horizon=1200 "
        "streaming_prefixes=7 models=0 worlds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
