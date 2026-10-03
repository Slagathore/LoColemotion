#!/usr/bin/env python3
"""Phase-aware R115 finite-behavior source audit and production preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    resolve_prospective_source_freeze,
    sha256,
    verify_current_git_identity,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)
from sdk.conformance.versioned_recovery_controller_target_gate import (  # noqa: E402
    validate_authored_delta,
    validate_source_inventory,
)

CONTRACT_RELATIVE_PATH = (
    "sdk/recovery/r24d115_godot_jolt_publication_stable_mirrored_front_knee_"
    "recovery_behavior_contract_v1.json"
)
CONTRACT = ROOT / CONTRACT_RELATIVE_PATH
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d115_godot_jolt_publication_stable_mirrored_front_"
    "knee_recovery_behavior_contract_v1"
)
CLOSURE_RELATIVE_PATH = (
    "sdk/recovery/r24d115_godot_jolt_publication_stable_mirrored_front_knee_"
    "recovery_behavior_zero_world_qualification_closure_v1.json"
)
CLOSURE = ROOT / CLOSURE_RELATIVE_PATH
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d115_godot_jolt_publication_stable_mirrored_front_"
    "knee_recovery_behavior_zero_world_qualification_closure_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_publication_stable_mirrored_front_knee_recovery_behavior_"
    "complete_zero_world_qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_publication_stable_mirrored_front_knee_"
    "recovery_behavior_qualified_one_finite_paired_development_attempt_"
    "authorized"
)
R114_STATUS = (
    "closed_complete_zero_world_mirrored_front_knee_recovery_behavior_"
    "qualified_publication_state_audit_not_reusable_no_physics_authorized_"
    "r115_required"
)
PASS_MARKER = (
    "QSDK_R24D115_GODOT_JOLT_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_"
    "BEHAVIOR_SOURCE_PASS"
)
FAIL_MARKER = (
    "QSDK_R24D115_GODOT_JOLT_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_"
    "BEHAVIOR_SOURCE_FAIL"
)


def _validate_predecessor(contract: dict[str, Any]) -> None:
    binding = contract["bound_predecessor"]
    path = ROOT / str(binding["path"])
    raw = path.read_bytes()
    exact(len(raw), binding["byte_length"], "R114_LENGTH")
    exact(sha256(raw), binding["raw_sha256"], "R114_HASH")
    closure = load(path)
    verify_exact_paths(
        closure,
        {
            "gate_id": "QSDK-R24D114",
            "closure_status": R114_STATUS,
            "qualification.official_zero_world_qualification_passed": True,
            "post_qualification_publication_stability_diagnosis.failure_phase": (
                "source_preflight"
            ),
            "post_qualification_publication_stability_diagnosis.operation_lock_acquired": False,
            "post_qualification_publication_stability_diagnosis.physical_process_started": False,
            "post_qualification_publication_stability_diagnosis.world_attempt_count": 0,
            "post_qualification_publication_stability_diagnosis.solver_step_count": 0,
            "decision.physical_execution_authorized": False,
            "decision.r115_publication_stable_successor_required": True,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R114_PREDECESSOR",
    )


def _validate_unchanged_physical_question(contract: dict[str, Any]) -> None:
    r114 = load(
        ROOT
        / "sdk/recovery/r24d114_godot_jolt_mirrored_front_knee_recovery_behavior_contract_v1.json"
    )
    for dotted_path in (
        "finite_development_population.cell_seed",
        "finite_development_population.held_out",
        "finite_development_population.cell_count",
        "finite_development_population.arm_count",
        "finite_development_population.world_count",
        "finite_development_population.ordered_arms",
        "finite_development_population.maximum_world_attempt_count",
        "finite_development_population.maximum_world_build_count",
        "finite_development_population.maximum_total_outer_steps",
        "finite_development_population.maximum_outer_steps_per_arm",
        "finite_development_population.physics_ticks_per_second",
        "finite_development_population.behavior_evaluator_invocation_count",
        "behavior_execution_contract.recovery_controller_id",
        "behavior_execution_contract.support_command_sha256",
        "behavior_execution_contract.actuator_profile_id",
        "behavior_execution_contract.actuator_mode",
        "behavior_execution_contract.actuator_mapping_id",
        "behavior_execution_contract.work_mapping_id",
        "behavior_execution_contract.numeric_predicate_id",
    ):
        old: Any = r114
        new: Any = contract
        for key in dotted_path.split("."):
            old = old[key]
            new = new[key]
        exact(new, old, f"UNCHANGED_PHYSICAL:{dotted_path}")


def _validate_live(
    contract: dict[str, Any], source_commit: str, published: bool
) -> None:
    expected: dict[str, Any] = {
        "r24d115_question_class_declared": True,
        "r24d115_question_class": "development",
        "r24d115_physical_question_declared": True,
        "r24d115_contract_path": CONTRACT_RELATIVE_PATH,
        "r24d115_recovery_controller_id": (
            "sporespore_exact_s169_prone_to_standing_controller_v2"
        ),
        "r24d115_support_command_sha256": (
            "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
        ),
        "r24d115_seed": 278151771,
        "r24d115_seed_sha256": (
            "sha256:de250d30e178cbc93b85432a3c0140f7faca6e245a963bc2d4f71fe527e5de30"
        ),
        "r24d115_declared_world_count": 2,
        "r24d115_maximum_outer_solver_steps": 2400,
        "r24d115_publication_stable_source_resolution": True,
        "r24d115_r114_qualification_and_refusal_bound": True,
        "r24d115_additional_physical_ghost_count": 0,
        "r24d115_bespoke_physical_canary_count": 0,
        "r24d115_prone_to_standing_claimed": False,
        "r24d115_sdk1_milestone_advanced": False,
        "physical_execution_blocked_pending_r24d115_declaration": False,
    }
    if not published:
        expected.update(
            {
                "r24d115_source_status": PROSPECTIVE_STATUS,
                "r24d115_physical_execution_authorized": False,
                "r24d115_zero_world_qualification_required": True,
                "r24d115_zero_world_qualification_complete": False,
                "physical_execution_blocked_until_r24d115_zero_world_qualification": True,
            }
        )
    else:
        closure = load(CLOSURE)
        raw = CLOSURE.read_bytes()
        exact(
            closure["source"]["source_freeze_commit"],
            source_commit,
            "PUBLISHED_SOURCE",
        )
        expected.update(
            {
                "r24d115_source_status": QUALIFIED_STATUS,
                "r24d115_source_commit": source_commit,
                "r24d115_physical_execution_authorized": True,
                "r24d115_zero_world_qualification_required": True,
                "r24d115_zero_world_qualified": True,
                "r24d115_zero_world_qualification_complete": True,
                "r24d115_zero_world_closure_path": CLOSURE_RELATIVE_PATH,
                "r24d115_zero_world_closure_raw_sha256": sha256(raw),
                "r24d115_zero_world_closure_byte_length": len(raw),
                "physical_execution_blocked_until_r24d115_zero_world_qualification": False,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        contract["audit_configuration"]["live_authority_paths"],
        record_key="r24d115_contract_path",
        expected=expected,
        prefix="LIVE_R115_PHASE_AWARE",
    )


def validate_contract(contract: dict[str, Any]) -> tuple[str, bool]:
    verify_exact_paths(
        contract,
        {
            "schema_version": CONTRACT_SCHEMA,
            "gate_id": "QSDK-R24D115",
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "prospective_publication_stable_finite_behavior_development"
            ),
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controlled_change.publication_stable_source_resolution_added": True,
            "controlled_change.publication_phase_live_projection_added": True,
            "controlled_change.physical_question_semantics_changed": False,
            "controlled_change.recovery_controller_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.seed_value_changed": False,
            "controlled_change.additional_physical_ghost_added": False,
            "controlled_change.bespoke_physical_canary_added": False,
            "finite_development_population.cell_seed": 278151771,
            "finite_development_population.seed_sha256": (
                "sha256:de250d30e178cbc93b85432a3c0140f7faca6e245a963bc2d4f71fe527e5de30"
            ),
            "finite_development_population.world_count": 2,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.same_identity_rerun_permitted": False,
            "behavior_execution_contract.recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "complete_zero_world_gate.phase_aware_source_resolution_count": 1,
            "complete_zero_world_gate.publication_phase_live_projection_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.additional_physical_ghost_count": 0,
            "complete_zero_world_gate.additional_physical_canary_count": 0,
            "physical_authorization_projection.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.full_program_completed_steps": 11,
        },
        "R115_CONTRACT",
    )
    validate_source_inventory(ROOT, contract)
    head = str(git(ROOT, "rev-parse", "HEAD"))
    if not CLOSURE.is_file() and head == contract["authored_parent_commit"]:
        validate_authored_delta(ROOT, contract)
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=CLOSURE_SCHEMA,
        gate_id="QSDK-R24D115",
    )
    verify_current_git_identity(
        ROOT, source_commit, contract["qualified_physical_paths"]
    )
    exact(
        len(contract["qualified_physical_paths"]),
        len(set(contract["qualified_physical_paths"])),
        "QUALIFIED_PATHS_UNIQUE",
    )
    exact(len(contract["qualified_physical_paths"]), 50, "QUALIFIED_PATHS_COUNT")
    exact(len(contract["source_inventory"]), 64, "SOURCE_INVENTORY_COUNT")
    require(
        set(contract["qualified_physical_paths"]).issubset(
            set(contract["source_inventory"])
        ),
        "QUALIFIED_SOURCE_SUBSET",
    )
    _validate_predecessor(contract)
    _validate_unchanged_physical_question(contract)
    _validate_live(contract, source_commit, published)
    return source_commit, published


def run() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    try:
        contract = load(CONTRACT)
        source_commit, published = validate_contract(contract)
        if args.core_library is None:
            runtime_version = "source_only"
        else:
            runtime = args.core_library.resolve()
            require(runtime.is_file(), "CORE_LIBRARY_MISSING")
            runtime_version = sha256(runtime.read_bytes())
        print(PASS_MARKER)
        print(
            json.dumps(
                {
                    "schema_version": (
                        "sporespore_qsdk_r24d115_publication_stable_mirrored_"
                        "front_knee_behavior_preflight_v1"
                    ),
                    "gate_id": "QSDK-R24D115",
                    "ok": True,
                    "source_freeze_commit": source_commit,
                    "publication_phase": published,
                    "publication_state_resolution_passed": True,
                    "source_inventory_count": 64,
                    "authored_source_path_count": 9,
                    "qualified_physical_path_count": 50,
                    "runtime_id": "sporespore_locomotion_core_debug_dll",
                    "runtime_version": runtime_version,
                    "prospective_physical_question_declared": True,
                    "physical_execution_authorized": False,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "physics_state_modified": False,
                    "physical_question_opened": False,
                    "prone_to_standing_claimed": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{FAIL_MARKER}:{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(run())
